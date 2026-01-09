import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_estanqueidade.dart';

class TelaListaLotesEstanqueidade extends StatelessWidget {
  final List<String> filtrosAgente;
  final String titulo;

  const TelaListaLotesEstanqueidade({
    super.key,
    required this.filtrosAgente,
    required this.titulo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        backgroundColor: Colors.lightBlue[800],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('status', isEqualTo: 'aguardando_estanqueidade')
        // O CAÇA-FANTASMAS SETORIZADO
            .where('tipoAgente', whereIn: filtrosAgente)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.water, size: 80, color: Colors.blue[100]),
                  const SizedBox(height: 10),
                  Text('Tanque vazio em $titulo.', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

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
                  leading: const Icon(Icons.water, color: Colors.blue),
                  title: Text('Lote: $osId'),
                  subtitle: Text('$qtd itens no tanque'),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TelaEstacaoEstanqueidade(
                          osId: osId,
                          filtrosAgente: filtrosAgente, // Repassa o filtro
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