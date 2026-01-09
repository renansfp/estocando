// Salve como: lib/telas/producao/estacao/tela_estacao_lixa.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelaEstacaoLixa extends StatefulWidget {
  final String osId;
  const TelaEstacaoLixa({Key? key, required this.osId}) : super(key: key);

  @override
  _TelaEstacaoLixaState createState() => _TelaEstacaoLixaState();
}

class _TelaEstacaoLixaState extends State<TelaEstacaoLixa> {
  final Color _corSetor = Colors.blueGrey[700]!;

  Future<void> _confirmarLixamento(DocumentSnapshot itemDoc) async {
    try {
      final dados = itemDoc.data() as Map<String, dynamic>;
      final codigo = dados['idCrachaTemporario'] ?? '???';
      final tipoAgente = dados['tipoAgente']?.toString().toUpperCase() ?? '';

      // Verifica dados da triagem para saber do TH
      final triagem = dados['triagem'] as Map<String, dynamic>? ?? {};
      final bool testeVencido = triagem['testeVencido'] == true;

      // --- A LÓGICA DE SEPARAÇÃO (O GUARDA DE TRÂNSITO) ---

      String proximoStatus;
      String nomeProximaEtapa;

      // Verifica se é CO2 (ou Dióxido)
      bool isCO2 = tipoAgente.contains('CO') || tipoAgente.contains('DIOXIDO');

      if (isCO2) {
        // CAMINHO DO CO2: Sempre vai para a bancada de válvula primeiro
        proximoStatus = 'aguardando_manutencao_valvula';
        nomeProximaEtapa = 'MANUTENÇÃO DE VÁLVULA';
      } else {
        // CAMINHO DO PQS/ÁGUA: Pula válvula dedicada.
        // Decide entre TH ou Pintura.
        if (testeVencido) {
          proximoStatus = 'aguardando_teste_hidro';
          nomeProximaEtapa = 'TESTE HIDROSTÁTICO';
        } else {
          proximoStatus = 'aguardando_pintura';
          nomeProximaEtapa = 'PINTURA';
        }
      }

      await FirebaseFirestore.instance.collection('itens_os').doc(itemDoc.id).update({
        'status': proximoStatus,
        'statusAtual': 'emProducao',
        'etapa': 'producao',
        'lixa': {
          'data': FieldValue.serverTimestamp(),
          'operador': 'operador_lixa',
        }
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Flexible(child: Text('Item $codigo ($tipoAgente) -> Vai para $nomeProximaEtapa')),
              ],
            ),
            duration: const Duration(milliseconds: 2000),
            backgroundColor: Colors.green,
          )
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Execução: Lixa/Jato'),
        backgroundColor: _corSetor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('osId', isEqualTo: widget.osId)
            .where('status', isEqualTo: 'aguardando_lixa')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final itens = snapshot.data!.docs;

          // Lixeiro Automático
          if (itens.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pop();
              }
            });
            return Container(color: Colors.white);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: itens.length,
            itemBuilder: (context, index) {
              final item = itens[index];
              final dados = item.data() as Map<String, dynamic>;
              final codigo = dados['idCrachaTemporario'] ?? '???';
              final tipo = dados['tipoAgente']?.toString().toUpperCase() ?? '---';

              final triagem = dados['triagem'] as Map<String, dynamic>? ?? {};
              final bool teste = triagem['testeVencido'] == true;

              // --- VISUALIZAÇÃO DO DESTINO NO CARD ---
              bool isCO2 = tipo.contains('CO') || tipo.contains('DIOXIDO');

              String textoDestino;
              Color corDestino;

              if (isCO2) {
                textoDestino = "Vai para Manut. Válvula";
                corDestino = Colors.teal;
              } else if (teste) {
                textoDestino = "Vai para Teste Hidro";
                corDestino = Colors.purple;
              } else {
                textoDestino = "Vai para Pintura";
                corDestino = Colors.brown;
              }

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: _corSetor.withOpacity(0.3))
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey[50],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.build, color: _corSetor, size: 30),
                      ),
                      const SizedBox(width: 15),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Extintor: $codigo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            Row(
                              children: [
                                Text('Tipo: $tipo', style: TextStyle(color: Colors.grey[700])),
                                if (isCO2)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 5),
                                    child: Icon(Icons.warning, size: 14, color: Colors.orange),
                                  )
                              ],
                            ),
                            const SizedBox(height: 5),

                            // Tag informativa do Destino
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: corDestino.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4)
                              ),
                              child: Text(
                                textoDestino,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: corDestino
                                ),
                              ),
                            )
                          ],
                        ),
                      ),

                      IconButton(
                        onPressed: () => _confirmarLixamento(item),
                        icon: const Icon(Icons.check_circle, size: 40),
                        color: Colors.green,
                        tooltip: "Pronto / Lixado",
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}