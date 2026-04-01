import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_recarga.dart';

class TelaListaLotesRecarga extends StatelessWidget {
  final String titulo;
  final List<String> filtrosAgente;

  const TelaListaLotesRecarga({
    super.key,
    required this.titulo,
    required this.filtrosAgente,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        backgroundColor: Colors.green.shade700,
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
            final agente = dados['tipoAgente']?.toString().toUpperCase() ?? '';

            // Agrupa se o agente bater com o filtro deste setor
            bool agenteBate = filtrosAgente.any((f) => agente.contains(f.toUpperCase()));

            if (agenteBate) {
              String id = dados['osId']?.toString() ?? 'S/OS';
              if (!agrupados.containsKey(id)) agrupados[id] = [];
              agrupados[id]!.add(doc);
            }
          }

          if (agrupados.isEmpty) return const Center(child: Text('Nenhum lote para este setor.'));

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: agrupados.length,
            itemBuilder: (context, index) {
              String osId = agrupados.keys.elementAt(index);
              List<DocumentSnapshot> itensDaOS = agrupados[osId]!;

              int prontos = itensDaOS.where((d) {
                String st = d['status']?.toString().toLowerCase() ?? '';
                return st.contains('recarga');
              }).length;

              if (prontos == 0) {
                return const SizedBox.shrink();
              }

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: prontos > 0 ? Colors.green.shade100 : Colors.grey.shade200,
                    child: Icon(Icons.gas_meter, color: prontos > 0 ? Colors.green : Colors.grey),
                  ),
                  title: Text('Lote OS: $osId', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total do Agente na OS: ${itensDaOS.length}'),
                      Text(
                        'Prontos para Recarga: $prontos',
                        style: TextStyle(
                          color: prontos > 0 ? Colors.green.shade700 : Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TelaEstacaoRecarga(
                        osId: osId,
                        filtrosAgente: filtrosAgente, // ENVIANDO O FILTRO
                      ),
                    ),
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