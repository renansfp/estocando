import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';

class TelaEstacaoExpedicao extends StatefulWidget {
  final String osId;

  const TelaEstacaoExpedicao({super.key, required this.osId});

  @override
  State<TelaEstacaoExpedicao> createState() => _TelaEstacaoExpedicaoState();
}

class _TelaEstacaoExpedicaoState extends State<TelaEstacaoExpedicao> {
  final TextEditingController _scannerController = TextEditingController();
  bool _carregando = false;

  String _limparCodigo(String valor) {
    String limpo = valor.trim().toUpperCase();
    if (limpo.contains('HTTP')) limpo = limpo.split('/').last;
    return limpo.replaceAll('R-', '');
  }

  Future<void> _processarBipe(String codigo) async {
    if (codigo.isEmpty || _carregando) return;
    setState(() => _carregando = true);

    String idCracha = _limparCodigo(codigo);

    try {
      final firestore = FirebaseFirestore.instance;

      // 1. Busca o item que está aguardando expedição
      final query = await firestore
          .collection('itens_os')
          .where('osId', isEqualTo: widget.osId)
          .where('idCrachaTemporario', isEqualTo: idCracha)
          .where('status', isEqualTo: 'aguardando_expedicao')
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final docItem = query.docs.first;
        final dadosItem = docItem.data() as Map<String, dynamic>;
        final String? equipId = dadosItem['equipamentoId'];
        final batch = firestore.batch();

        // A. ATUALIZA O ITEM DA OS (Filho)
        batch.update(docItem.reference, {
          'status': 'entregue',
          'statusAtual': 'finalizado', // Sai da query do dashboard
          'dataExpedicao': FieldValue.serverTimestamp(),
        });

        // B. ATUALIZA O EQUIPAMENTO (Pai) - O SEU "FIX" ESTÁ AQUI
        if (equipId != null && equipId.isNotEmpty) {
          final equipRef = firestore.collection('equipamentos').doc(equipId);

          batch.update(equipRef, {
            'status': 'ativo',            // Deixa livre para nova OS
            'osIdAtual': FieldValue.delete(), // Remove o vínculo da OS antiga
            'itemIdAtual': FieldValue.delete(), // Remove o vínculo do Item antigo

            // GATILHO DE DATAS: Aproveitamos para atualizar a última recarga no cadastro mestre
            'ultimaRecarga': "${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}",
          });
        }

        // 3. Verifica se era o último item do lote
        final queryPendentes = await firestore
            .collection('itens_os')
            .where('osId', isEqualTo: widget.osId)
            .where('status', isEqualTo: 'aguardando_expedicao')
            .get();

        // Se restava apenas 1 (este que estamos processando), fecha a OS
        if (queryPendentes.docs.length <= 1) {
          final osRef = firestore.collection('ordens_servico').doc(widget.osId);
          batch.update(osRef, {
            'etapaAtual': 'finalizado',
            'statusLote': 'entregue_ao_cliente',
            'dataEncerramento': FieldValue.serverTimestamp(),
          });
        }

        final queryCracha = await firestore.collection('crachas')
            .where('idCracha', isEqualTo: idCracha) // idCracha é o nome dele, ex: R-101
            .limit(1)
            .get();

        if (queryCracha.docs.isNotEmpty) {
          final crachaRef = queryCracha.docs.first.reference;
          batch.update(crachaRef, {
            'status': 'disponivel', // Libera para a próxima OS
            'itemOsIdAtual': FieldValue.delete(),
            'osIdAtual': FieldValue.delete(),
          });
        }

        await batch.commit();
        _notificar('Item $idCracha carregado!', Colors.green);
      } else {
        _notificar('Crachá inválido ou já expedido.', Colors.orange);
      }
    } catch (e) {
      _notificar('Erro: $e', Colors.red);
    } finally {
      _scannerController.clear();
      setState(() => _carregando = false);
    }
  }

  void _notificar(String msg, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: cor, duration: const Duration(milliseconds: 700))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Expedição: OS ${widget.osId}'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            color: Colors.grey.shade200,
            child: CampoComScanner(
              controller: _scannerController,
              label: 'Bipar para Carregamento no Veículo',
              onSubmitted: _processarBipe,
            ),
          ),
          if (_carregando) const LinearProgressIndicator(),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('itens_os')
                  .where('osId', isEqualTo: widget.osId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final totalItens = snapshot.data!.docs;
                final expedidos = totalItens.where((d) => d['status'] == 'entregue').toList();
                final pendentes = totalItens.where((d) => d['status'] == 'aguardando_expedicao').toList();

                if (totalItens.isNotEmpty && pendentes.isEmpty) return _buildSucessoTotal();

                return Column(
                  children: [
                    // Contador de Progresso
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Carregados: ${expedidos.length} de ${totalItens.length}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),

                    Expanded(
                      child: ListView.builder(
                        itemCount: pendentes.length,
                        itemBuilder: (context, index) {
                          final dados = pendentes[index].data() as Map<String, dynamic>;
                          return ListTile(
                            leading: const Icon(Icons.inventory_2_outlined),
                            title: Text('Crachá: ${dados['idCrachaTemporario']}'),
                            subtitle: Text('${dados['tipoAgente']} ${dados['capacidade']}'),
                            trailing: const Text('PENDENTE', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSucessoTotal() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_shipping, size: 100, color: Colors.green),
          const SizedBox(height: 20),
          const Text('VEÍCULO CARREGADO!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text('Todos os itens foram expedidos com sucesso.'),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('FINALIZAR E VOLTAR'),
          ),
        ],
      ),
    );
  }
}