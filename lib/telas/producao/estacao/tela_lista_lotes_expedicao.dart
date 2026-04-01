import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_expedicao.dart';

class TelaListaLotesExpedicao extends StatelessWidget {
  const TelaListaLotesExpedicao({super.key});

  @override
  Widget build(BuildContext context) {
    final Color corSetor = Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fila: Expedição e Carregamento'),
        backgroundColor: corSetor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Busca todos os itens que ainda estão no processo produtivo
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
            String osId = dados['osId']?.toString() ?? 'S/OS';
            if (!agrupados.containsKey(osId)) agrupados[osId] = [];
            agrupados[osId]!.add(doc);
          }

          // Filtro: Só mostra OSs que tenham itens aguardando expedição (após a montagem)
          List<String> osAtivas = agrupados.keys.where((osId) {
            return agrupados[osId]!.any((doc) => doc['status'] == 'aguardando_expedicao');
          }).toList();

          if (osAtivas.isEmpty) {
            return const Center(child: Text('Nenhum lote pronto para carregar.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: osAtivas.length,
            itemBuilder: (context, index) {
              String osId = osAtivas[index];
              List<DocumentSnapshot> itensDaOS = agrupados[osId]!;

              int totalItensOS = itensDaOS.length;

              // Itens que já foram bipados na expedição ou finalizados
              int processados = itensDaOS.where((doc) {
                String st = doc['status']?.toString() ?? '';
                return st == 'finalizado' || st == 'entregue';
              }).length;

              double progresso = processados / totalItensOS;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => TelaEstacaoExpedicao(osId: osId)
                  )),
                  leading: CircleAvatar(
                    backgroundColor: corSetor,
                    child: Icon(Icons.local_shipping, color: Colors.white, size: 20),
                  ),
                  title: Text('Lote OS: $osId', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progresso,
                        backgroundColor: Colors.grey[200],
                        color: processados == totalItensOS ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(height: 4),
                      Text('$processados de $totalItensOS cilindros carregados'),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
              );
            },
          );
        },
      ),
    );
  }
}