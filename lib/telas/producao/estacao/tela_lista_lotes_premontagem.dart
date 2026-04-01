// lib/telas/producao/lista/tela_lista_lotes_premontagem.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_premontagem.dart';

class TelaListaLotesPremontagem extends StatelessWidget {
  const TelaListaLotesPremontagem({super.key});

  @override
  Widget build(BuildContext context) {
    final Color corPadrao = Colors.indigo.shade700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fila: Pré-Montagem'),
        backgroundColor: corPadrao,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('statusAtual', isEqualTo: 'emProducao')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          Map<String, List<DocumentSnapshot>> agrupados = {};

          for (var doc in docs) {
            final dados = doc.data() as Map<String, dynamic>;
            final roteiro = List.from(dados['roteiro'] ?? []);

            // Filtra itens que passam pela pré-montagem no roteiro
            if (roteiro.contains('premontagem') || roteiro.contains('pre_montagem')) {
              String osId = dados['osId']?.toString() ?? 'S/OS';
              if (!agrupados.containsKey(osId)) agrupados[osId] = [];
              agrupados[osId]!.add(doc);
            }
          }

          // Filtra OSs que possuem ao menos um item aguardando ou já na pré-montagem
          List<String> osAtivas = agrupados.keys.where((osId) {
            return agrupados[osId]!.any((doc) {
              // Pegamos o status e removemos os underlines para comparar
              String st = doc['status']?.toString().toLowerCase().replaceAll('_', '') ?? '';

              // Agora ele aceita 'premontagem', 'pre_montagem', 'aguardando_pre_montagem', etc.
              return st.contains('premontagem');
            });
          }).toList();

          if (osAtivas.isEmpty) return const Center(child: Text('Nenhum lote pendente para montagem.'));

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: osAtivas.length,
            itemBuilder: (context, index) {
              String osId = osAtivas[index];
              List<DocumentSnapshot> itensDaOS = agrupados[osId]!;

              int totalItens = itensDaOS.length;
              // Conta apenas itens que REALMENTE já chegaram fisicamente no setor
              int prontosNoSetor = itensDaOS.where((doc) {
                String st = doc['status']?.toString().toLowerCase().replaceAll('_', '') ?? '';
                return st.contains('premontagem');
              }).length;

              double progresso = prontosNoSetor / totalItens;
              bool loteCompleto = prontosNoSetor == totalItens;

              return Card(
                elevation: loteCompleto ? 8 : 4,
                margin: const EdgeInsets.only(bottom: 12),
                // MUDANÇA DE COR: Verde se estiver 100% pronto para montar
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: loteCompleto ? Colors.green.shade700 : Colors.transparent,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => TelaEstacaoPremontagem(osId: osId)
                  )),
                  leading: CircleAvatar(
                    backgroundColor: loteCompleto ? Colors.green : corPadrao,
                    child: Icon(
                      loteCompleto ? Icons.check_circle : Icons.pending_actions,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    'Lote OS: $osId',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progresso,
                        backgroundColor: Colors.grey[200],
                        color: loteCompleto ? Colors.green : Colors.orange,
                        minHeight: 8,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        loteCompleto
                            ? 'LOTE COMPLETO - PRONTO PARA MONTAR'
                            : 'Aguardando itens da estanqueidade ($prontosNoSetor/$totalItens)',
                        style: TextStyle(
                          color: loteCompleto ? Colors.green.shade900 : Colors.black54,
                          fontWeight: loteCompleto ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                ),
              );
            },
          );
        },
      ),
    );
  }
}