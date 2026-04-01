// lib/telas/producao/estacao/tela_balanco_lote.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';

class TelaBalancoLote extends StatefulWidget {
  final String osId;
  final List<String> filtrosAgente;

  const TelaBalancoLote({
    super.key,
    required this.osId,
    required this.filtrosAgente
  });

  @override
  State<TelaBalancoLote> createState() => _TelaBalancoLoteState();
}

class _TelaBalancoLoteState extends State<TelaBalancoLote> {
  final TextEditingController _scannerController = TextEditingController();
  bool _processandoBipe = false;
  bool _prioridadeDescarte = true; // TRUE = Lixo / FALSE = Reuso

  String _limparCodigo(String valor) {
    String limpo = valor.trim().toUpperCase();
    if (limpo.contains('HTTP')) {
      limpo = limpo.split('/').last;
    }
    return limpo.replaceAll('R-', '');
  }

  Future<void> _processarBipeAutomatico(String codigo) async {
    if (codigo.isEmpty || _processandoBipe) return;
    setState(() => _processandoBipe = true);

    String idCracha = _limparCodigo(codigo);

    try {
      final firestore = FirebaseFirestore.instance;

      final query = await firestore
          .collection('itens_os')
          .where('osId', isEqualTo: widget.osId)
          .where('idCrachaTemporario', isEqualTo: idCracha)
          .where('status', isEqualTo: 'aguardando_descarga')
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final docItem = query.docs.first;
        final batch = firestore.batch();

        batch.update(docItem.reference, {
          'status': 'aguardando_limpeza',
          'dataDescarga': FieldValue.serverTimestamp(),
          'realizadoPor': 'operador_descarga_auto',
        });

        final queryPendentes = await firestore
            .collection('itens_os')
            .where('osId', isEqualTo: widget.osId)
            .where('status', isEqualTo: 'aguardando_descarga')
            .get();

        if (queryPendentes.docs.length <= 1) {
          final osRef = firestore.collection('ordens_servico').doc(widget.osId);
          batch.update(osRef, {
            'etapaAtual': 'limpeza',
            'statusLote': 'na_limpeza',
            'dataFimDescarga': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cilindro $idCracha processado!'),
              backgroundColor: Colors.green,
              duration: const Duration(milliseconds: 700),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Crachá não encontrado nesta OS ou já baixado.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Erro no bipe: $e");
    } finally {
      _scannerController.clear();
      setState(() => _processandoBipe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Execução de Descarga'),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            color: Colors.blueGrey.shade50,
            child: CampoComScanner(
              controller: _scannerController,
              label: 'Bipar Crachá do Cilindro',
              onSubmitted: _processarBipeAutomatico,
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Modo de Trabalho:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ActionChip(
                  avatar: Icon(_prioridadeDescarte ? Icons.delete_outline : Icons.recycling, size: 16),
                  label: Text(_prioridadeDescarte ? "FOCO: LIXO" : "FOCO: REUSO"),
                  onPressed: () => setState(() => _prioridadeDescarte = !_prioridadeDescarte),
                  backgroundColor: _prioridadeDescarte ? Colors.red[50] : Colors.green[50],
                ),
              ],
            ),
          ),

          if (_processandoBipe) const LinearProgressIndicator(),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('itens_os')
                  .where('osId', isEqualTo: widget.osId)
                  .where('tipoAgente', whereIn: widget.filtrosAgente)
                  .where('status', isEqualTo: 'aguardando_descarga')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return _buildTelaConclusao();

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final itemData = docs[index].data() as Map<String, dynamic>;
                    final equipId = itemData['equipamentoId'] ?? '';

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('equipamentos').doc(equipId).get(),
                      builder: (context, snapEquip) {
                        if (!snapEquip.hasData || !snapEquip.data!.exists) return const SizedBox.shrink();

                        final e = snapEquip.data!.data() as Map<String, dynamic>;
                        final String tipoAgente = (itemData['tipoAgente'] ?? '').toString().toUpperCase();

                        // LÓGICA DE FILTRAGEM ATIVA
                        bool deveDescartar = e['substituirPo'] ?? false;

                        // Se o agente for CO2 ou Água, eles aparecem apenas no modo "Lixo" por padrão
                        // Se for Pó, respeita o filtro do botão
                        if (tipoAgente != 'CO2' && tipoAgente != 'AGUA' && tipoAgente != 'ESPUMA') {
                          if (_prioridadeDescarte != deveDescartar) {
                            return const SizedBox.shrink();
                          }
                        } else {
                          if (!_prioridadeDescarte) return const SizedBox.shrink();
                        }

                        String labelStatus = "";
                        Color corAviso = Colors.grey;
                        IconData icone = Icons.help_outline;

                        if (tipoAgente == 'CO2') {
                          labelStatus = "DESCARGA DE GÁS (PESAGEM)";
                          corAviso = Colors.blue.shade700;
                          icone = Icons.air;
                        } else if (tipoAgente == 'AGUA' || tipoAgente == 'ESPUMA') {
                          labelStatus = "DESCARTAR LÍQUIDO (ESGOTO)";
                          corAviso = Colors.orange.shade800;
                          icone = Icons.waves;
                        } else {
                          labelStatus = deveDescartar ? "DESCARTAR PÓ (LIXO)" : "REUTILIZAR PÓ (PENEIRA)";
                          corAviso = deveDescartar ? Colors.red : Colors.green.shade700;
                          icone = deveDescartar ? Icons.delete_forever : Icons.recycling;
                        }

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: corAviso,
                              child: Icon(icone, color: Colors.white),
                            ),
                            title: Text(
                                'Crachá: ${itemData['idCrachaTemporario'] ?? "N/D"}',
                                style: const TextStyle(fontWeight: FontWeight.bold)
                            ),
                            subtitle: Text(
                                labelStatus,
                                style: TextStyle(color: corAviso, fontWeight: FontWeight.bold, fontSize: 12)
                            ),
                          ),
                        );
                      },
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

  Widget _buildTelaConclusao() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text('OS Finalizada neste Setor!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('O lote foi movido automaticamente para a Limpeza.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('VOLTAR PARA A FILA'),
              ),
            )
          ],
        ),
      ),
    );
  }
}