import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';
import 'package:protecin_producao/widgets/botao_condenar.dart';
import 'package:protecin_producao/telas/estoque/tela_criar_requisicao.dart';
import 'package:protecin_producao/utils/mapeador_custos.dart';

class TelaEstacaoSaque extends StatefulWidget {
  final String numeroLote;
  const TelaEstacaoSaque({super.key, required this.numeroLote});

  @override
  State<TelaEstacaoSaque> createState() => _TelaEstacaoSaqueState();
}

class _TelaEstacaoSaqueState extends State<TelaEstacaoSaque> {
  final Color _corSetor = Colors.red.shade700;
  final TextEditingController _scannerController = TextEditingController();

  String _limparCodigo(String valor) {
    String limpo = valor.trim().toUpperCase();
    if (limpo.contains('HTTP')) limpo = limpo.split('/').last;
    return limpo.replaceAll('R-', '');
  }

  // Busca o item e abre o diálogo de inspeção automaticamente após o bipe
  Future<void> _processarBipe(String codigo) async {
    String idLimpo = _limparCodigo(codigo);
    _scannerController.clear();

    final query = await FirebaseFirestore.instance
        .collection('itens_os')
        .where('osId', isEqualTo: widget.numeroLote)
        .where('idCrachaTemporario', isEqualTo: idLimpo)
        .where('status', isEqualTo: 'aguardando_saque_valvula')
        .limit(1).get();

    if (query.docs.isNotEmpty) {
      _mostrarDialogoExecucao(query.docs.first);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Crachá não encontrado nesta OS ou já processado.')));
    }
  }

  // Condenação via BotaoCondenar widget (ver lista abaixo)

  Future<void> _confirmarSaque(DocumentSnapshot itemDoc) async {
    try {
      final dados = itemDoc.data() as Map<String, dynamic>;
      final List<String> roteiro = List<String>.from(dados['roteiro'] ?? []);

      int indexAtual = roteiro.indexOf('saque_valvula');
      String proximaEstacao = roteiro[indexAtual + 1];

      final batch = FirebaseFirestore.instance.batch();

      batch.update(itemDoc.reference, {
        'status': 'aguardando_$proximaEstacao',
        'saque': {
          'data': FieldValue.serverTimestamp(),
          'operador': 'operador_saque',
          'inspecoes': {'interna': true, 'rosca': true}
        }
      });

      final queryPendentes = await FirebaseFirestore.instance
          .collection('itens_os')
          .where('osId', isEqualTo: widget.numeroLote)
          .where('status', isEqualTo: 'aguardando_saque_valvula')
          .get();

      if (queryPendentes.docs.length <= 1) {
        batch.update(FirebaseFirestore.instance.collection('ordens_servico').doc(widget.numeroLote), {
          'etapaAtual': proximaEstacao,
        });
      }

      await batch.commit();
      Navigator.pop(context);
    } catch (e) { print(e); }
  }

  void _mostrarDialogoExecucao(DocumentSnapshot itemDoc) {
    final d = itemDoc.data() as Map<String, dynamic>;
    bool inspInterna = false;
    bool inspRosca = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Inspeção: ${d['idCrachaTemporario']}', style: TextStyle(color: _corSetor)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(title: const Text("Inspeção Interna OK?"), value: inspInterna, onChanged: (v) => setStateDialog(() => inspInterna = v!)),
                CheckboxListTile(title: const Text("Rosca em bom estado?"), value: inspRosca, onChanged: (v) => setStateDialog(() => inspRosca = v!)),
                const Divider(),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: (inspInterna && inspRosca) ? () => _confirmarSaque(itemDoc) : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("APROVAR", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Execução: Saque'),
        backgroundColor: _corSetor,
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.home), onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_checkout),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => TelaCriarRequisicao(
              osPrePreenchida: widget.numeroLote,
              ccPrePreenchido: MapeadorCustos.obterCC('MANUTENÇÃO DE COMPONENTES'),
              subTipoPrePreenchido: 'OS',
            ))),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.red.shade50,
            child: CampoComScanner(controller: _scannerController, label: 'Bipar Crachá para Saque', onSubmitted: _processarBipe),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('itens_os')
                  .where('osId', isEqualTo: widget.numeroLote)
                  .where('status', isEqualTo: 'aguardando_saque_valvula')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final itens = snapshot.data!.docs;
                if (itens.isEmpty) return const Center(child: Text('Lote concluído!'));

                return ListView.builder(
                  itemCount: itens.length,
                  padding: const EdgeInsets.all(10),
                  itemBuilder: (ctx, i) {
                    final d = itens[i].data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.qr_code_scanner, color: Colors.red),
                        title: Text('Crachá: ${d['idCrachaTemporario']}'),
                        subtitle: Text('Agente: ${d['tipoAgente']}'),
                        trailing: BotaoCondenar(itemDoc: itens[i], etapa: 'saque_valvula'),
                        onTap: () => _mostrarDialogoExecucao(itens[i]),
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