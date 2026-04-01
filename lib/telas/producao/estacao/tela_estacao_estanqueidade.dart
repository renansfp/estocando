// lib/telas/producao/estacao/tela_estacao_estanqueidade.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';
import 'package:protecin_producao/widgets/botao_condenar.dart';

class TelaEstacaoEstanqueidade extends StatefulWidget {
  final String osId;
  final List<String> filtrosAgente;
  const TelaEstacaoEstanqueidade({super.key, required this.osId, required this.filtrosAgente});

  @override
  State<TelaEstacaoEstanqueidade> createState() => _TelaEstacaoEstanqueidadeState();
}

class _TelaEstacaoEstanqueidadeState extends State<TelaEstacaoEstanqueidade> {
  final TextEditingController _scannerController = TextEditingController();
  bool _processando = false;

  String _limparCodigo(String valor) {
    String limpo = valor.trim().toUpperCase();
    if (limpo.contains('HTTP')) limpo = limpo.split('/').last;
    return limpo.replaceAll('R-', '');
  }

  // --- AÇÃO: APROVAR ---
  Future<void> _aprovarItem(String docId, Map<String, dynamic> dados) async {
    setState(() => _processando = true);
    try {
      final List<dynamic> roteiroDinamico = dados['roteiro'] ?? [];
      final List<String> roteiro = roteiroDinamico.map((e) => e.toString()).toList();

      int indexAtual = roteiro.indexWhere((etapa) => etapa.contains('estanqueidade'));
      String proximaEtapa = (indexAtual != -1 && indexAtual + 1 < roteiro.length)
          ? roteiro[indexAtual + 1]
          : 'pre_montagem';

      await FirebaseFirestore.instance.collection('itens_os').doc(docId).update({
        'status': 'aguardando_$proximaEtapa',
        'estanqueidade': {
          'data': FieldValue.serverTimestamp(),
          'resultado': 'APROVADO',
          'operador': 'bancada_estanqueidade',
        }
      });

      _notificar('Aprovado! Segue para: ${proximaEtapa.toUpperCase()}', Colors.green);
    } catch (e) {
      _notificar('Erro no DNA do Roteiro: $e', Colors.red);
    } finally {
      setState(() => _processando = false);
    }
  }

  // --- AÇÃO: REPROVAR COM MOTIVO ---
  // Reprovar com volta para recarga (falhas reparáveis: bico, manômetro, rosca)
  void _escolherMotivoReprovacao(String docId, String cracha) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Reprovar: $cracha — Voltar para Recarga',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              const Text('Selecione o componente com falha:',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              _itemMotivoRecarga(docId, 'BICO', Icons.ev_station),
              _itemMotivoRecarga(docId, 'MANOMETRO', Icons.speed),
              _itemMotivoRecarga(docId, 'ROSCA', Icons.sync),
            ],
          ),
        );
      },
    );
  }

  Widget _itemMotivoRecarga(String docId, String motivo, IconData icone) {
    return ListTile(
      leading: Icon(icone, color: Colors.orange),
      title: Text(motivo),
      onTap: () async {
        Navigator.pop(context);
        setState(() => _processando = true);
        await FirebaseFirestore.instance
            .collection('itens_os')
            .doc(docId)
            .update({'status': 'aguardando_recarga', 'estanqueidade_falha.motivo': motivo});
        _notificar('Voltou para Recarga! ($motivo)', Colors.orange);
        setState(() => _processando = false);
      },
    );
  }

  Future<void> _processarBipe(String codigo) async {
    if (codigo.isEmpty) return;
    String idCracha = _limparCodigo(codigo);

    final query = await FirebaseFirestore.instance
        .collection('itens_os')
        .where('osId', isEqualTo: widget.osId)
        .where('idCrachaTemporario', isEqualTo: idCracha)
        .where('status', isEqualTo: 'aguardando_estanqueidade')
        .limit(1).get();

    if (query.docs.isNotEmpty) {
      // Como não há mais seletor de modo, o bipe SEMPRE aprova.
      await _aprovarItem(query.docs.first.id, query.docs.first.data() as Map<String, dynamic>);
    } else {
      _notificar('Item não pendente neste setor.', Colors.red);
    }
    _scannerController.clear();
  }

  void _notificar(String msg, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: cor, duration: const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Estanqueidade: OS ${widget.osId}'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // SCANNER LIMPO NO TOPO
          Container(
            padding: const EdgeInsets.all(16),
            child: CampoComScanner(
                controller: _scannerController,
                label: 'Bipar Crachá para Aprovar',
                onSubmitted: _processarBipe
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('itens_os')
                  .where('osId', isEqualTo: widget.osId)
                  .where('status', isEqualTo: 'aguardando_estanqueidade')
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                final itensDaBancada = snap.data!.docs.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final agente = (d['tipoAgente'] ?? '').toString().toUpperCase();

                  return widget.filtrosAgente.any((f) {
                    String filtro = f.toUpperCase();
                    if (filtro == 'BC') {
                      return agente == 'BC' || (agente.contains('BC') && !agente.contains('ABC'));
                    }
                    return agente.contains(filtro);
                  });
                }).toList();

                if (itensDaBancada.isEmpty) return const Center(child: Text('Lote concluído!'));

                return ListView.builder(
                  itemCount: itensDaBancada.length,
                  itemBuilder: (context, index) {
                    final item = itensDaBancada[index];
                    final d = item.data() as Map<String, dynamic>;
                    final String idDoc = item.id;
                    final String cracha = d['idCrachaTemporario'] ?? '---';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.water_drop, color: Colors.teal),
                        title: Text('Crachá: $cracha'),
                        subtitle: Text('${d['tipoAgente']} - ${d['capacidade'] ?? ""}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Condenar (furo, dano irreparável)
                            BotaoCondenar(itemDoc: item, etapa: 'estanqueidade'),
                            // Reprovar e voltar para recarga (bico, manômetro, rosca)
                            IconButton(
                              icon: const Icon(Icons.thumb_down, color: Colors.orange),
                              tooltip: 'Reprovar → volta para recarga',
                              onPressed: () => _escolherMotivoReprovacao(idDoc, cracha),
                            ),
                            // Aprovar
                            IconButton(
                              icon: const Icon(Icons.thumb_up, color: Colors.green),
                              onPressed: () => _aprovarItem(idDoc, d),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}