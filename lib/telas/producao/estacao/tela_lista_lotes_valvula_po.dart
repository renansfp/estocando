// lib/telas/producao/estacao/tela_lista_lotes_valvula_po.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_valvula_po.dart';

class TelaListaLotesValvulaPo extends StatelessWidget {
  const TelaListaLotesValvulaPo({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = Provider.of<UsuarioProvider>(context).usuario;
    final Color corSetor = Colors.deepOrange.shade700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fila: Válvula Pó Químico'),
        backgroundColor: corSetor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('empresaId', isEqualTo: usuario?.empresaId)
            .where('roteiro', arrayContains: 'manutencao_valvula_po')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          // Agrupa por OS
          final Map<String, List<DocumentSnapshot>> porOS = {};
          for (final doc in docs) {
            final d = doc.data() as Map<String, dynamic>?;
            if (d == null || !d.containsKey('osId')) continue;
            final osId = d['osId'].toString();
            porOS.putIfAbsent(osId, () => []).add(doc);
          }

          // Só mostra OS que tem pelo menos 1 item aguardando esta etapa
          final osAtivas = porOS.keys.where((osId) {
            return porOS[osId]!.any((doc) =>
            doc['status'] == 'aguardando_manutencao_valvula_po');
          }).toList();

          if (osAtivas.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 80, color: Colors.green),
                  SizedBox(height: 16),
                  Text('Nenhum extintor de pó aguardando válvula.',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: osAtivas.length,
            itemBuilder: (context, index) {
              final osId = osAtivas[index];
              final itens = porOS[osId]!;

              final pendentes = itens
                  .where((d) => d['status'] == 'aguardando_manutencao_valvula_po')
                  .length;
              final total = itens.length;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TelaEstacaoValvulaPo(osId: osId),
                    ),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: corSetor,
                    child: Text(
                      '$pendentes',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                  title: Text('OS: $osId',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$pendentes de $total itens aguardando válvula'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            },
          );
        },
      ),
    );
  }
}