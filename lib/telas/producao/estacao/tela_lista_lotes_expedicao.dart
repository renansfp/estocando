import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_expedicao.dart';

class TelaListaLotesExpedicao extends StatelessWidget {
  const TelaListaLotesExpedicao({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lotes: Expedição'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('status', isEqualTo: 'aguardando_expedicao')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nenhum lote pronto para entrega.'));
          }

          // Agrupa por OS
          Map<String, int> lotes = {};
          for (var doc in snapshot.data!.docs) {
            final osId = doc['osId'] ?? '???';
            lotes[osId] = (lotes[osId] ?? 0) + 1;
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: lotes.length,
            itemBuilder: (context, index) {
              final osId = lotes.keys.elementAt(index);
              final qtd = lotes[osId];

              return Card(
                elevation: 4,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.black12,
                    child: Text('$qtd', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                  title: Text('OS: $osId'),
                  subtitle: const Text('Pronto para Entrega'),
                  trailing: const Icon(Icons.local_shipping), // Ícone de caminhão
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TelaEstacaoExpedicao(osId: osId)),
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