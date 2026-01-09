import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_premontagem.dart';

class TelaListaLotesPremontagem extends StatelessWidget {
  const TelaListaLotesPremontagem({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lotes: Pré-Montagem'),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('status', isEqualTo: 'aguardando_premontagem')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nenhum lote na Pré-Montagem.'));
          }

          // Agrupa por OS
          Map<String, int> lotesQtdAtual = {};
          for (var doc in snapshot.data!.docs) {
            final osId = doc['osId'] ?? '???';
            lotesQtdAtual[osId] = (lotesQtdAtual[osId] ?? 0) + 1;
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: lotesQtdAtual.length,
            itemBuilder: (context, index) {
              final osId = lotesQtdAtual.keys.elementAt(index);
              final qtdAtual = lotesQtdAtual[osId]!;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo[100],
                    child: Text('$qtdAtual', style: TextStyle(color: Colors.indigo[900])),
                  ),
                  title: Text('Lote: $osId'),
                  // SUBTITULO INTELIGENTE: Busca o total da OS para comparar
                  subtitle: FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('ordens_servico').doc(osId).get(),
                    builder: (context, osSnapshot) {
                      if (!osSnapshot.hasData) return const Text('Verificando total...');

                      final osData = osSnapshot.data!.data() as Map<String, dynamic>?;
                      final totalOS = osData?['quantidadeTotal'] ?? 0;

                      if (qtdAtual >= totalOS) {
                        return Text(
                          'Lote Completo ($qtdAtual/$totalOS) - Pronto para liberar!',
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        );
                      } else {
                        return Text(
                          'Reunindo itens... ($qtdAtual/$totalOS)',
                          style: const TextStyle(color: Colors.orange),
                        );
                      }
                    },
                  ),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TelaEstacaoPremontagem(osId: osId)),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}