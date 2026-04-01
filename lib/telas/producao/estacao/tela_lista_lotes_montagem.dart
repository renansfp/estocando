import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_montagem.dart';

class TelaListaLotesMontagem extends StatelessWidget {
  const TelaListaLotesMontagem({super.key});

  @override
  Widget build(BuildContext context) {
    final Color corSetor = Colors.deepPurple.shade700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fila: Montagem Final e Lacração'),
        backgroundColor: corSetor,
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
            // Na Protecin, TODO extintor passa pela montagem final
            String osId = dados['osId']?.toString() ?? 'S/OS';
            if (!agrupados.containsKey(osId)) agrupados[osId] = [];
            agrupados[osId]!.add(doc);
          }

          // Só mostra OSs que tenham itens aguardando o SELO e LACRE
          List<String> osAtivas = agrupados.keys.where((osId) {
            return agrupados[osId]!.any((doc) =>
            doc['status']?.toString().toLowerCase().replaceAll('_', '') == 'aguardandomontagem');
          }).toList();

          if (osAtivas.isEmpty) {
            return const Center(
                child: Text('Nenhum extintor pendente de lacração.',
                    style: TextStyle(color: Colors.grey, fontSize: 16))
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: osAtivas.length,
            itemBuilder: (context, index) {
              String osId = osAtivas[index];
              List<DocumentSnapshot> itensDaOS = agrupados[osId]!;

              int totalParaMontar = itensDaOS.length;
              int concluidos = itensDaOS.where((doc) {
                String st = doc['status']?.toString().toLowerCase().replaceAll('_', '') ?? '';
                // Considera concluído nesta etapa se já foi para expedição ou finalizado
                return st == 'aguardandoexpedicao' || st == 'finalizado';
              }).length;

              double progresso = concluidos / totalParaMontar;


              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => TelaEstacaoMontagem(osId: osId)
                  )),
                  leading: CircleAvatar(
                    backgroundColor: progresso == 1.0 ? Colors.green : corSetor,
                    child: Text('$concluidos/$totalParaMontar',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  title: Text('Lote OS: $osId', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progresso,
                        backgroundColor: Colors.grey[200],
                        color: progresso == 1.0 ? Colors.green : corSetor,
                        minHeight: 6,
                      ),
                      const SizedBox(height: 4),
                      Text(progresso == 1.0 ? 'Pronto para Expedição' : 'Processando lacração...'),
                    ],
                  ),
                  trailing: Icon(Icons.verified, color: corSetor),
                ),
              );
            },
          );
        },
      ),
    );
  }
}