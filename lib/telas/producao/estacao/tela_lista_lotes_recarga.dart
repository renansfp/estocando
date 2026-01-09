import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_recarga.dart';

class TelaListaLotesRecarga extends StatelessWidget {
  final List<String> filtrosAgente;
  final String titulo;

  const TelaListaLotesRecarga({
    super.key,
    required this.filtrosAgente,
    required this.titulo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('status', isEqualTo: 'aguardando_recarga')
        // O CAÇA-FANTASMAS: Só busca itens do tipo selecionado
            .where('tipoAgente', whereIn: filtrosAgente)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // Se der erro de índice, avisa (acontece quando usa whereIn pela primeira vez)
            return Center(child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text('Se aparecer erro de índice no console, crie o índice no Firebase.\nErro: ${snapshot.error}'),
            ));
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.compress, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text('Nenhum item para $titulo.', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            );
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
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green[100],
                    child: Text('$qtd', style: TextStyle(color: Colors.green[800])),
                  ),
                  title: Text('Lote: $osId'),
                  subtitle: Text('Itens de ${titulo.replaceAll('Recarga ', '')}'),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TelaEstacaoRecarga(
                          osId: osId,
                          filtrosAgente: filtrosAgente, // Passa o filtro adiante
                          titulo: titulo,
                        ),
                      ),
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