import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_pintura.dart';

class TelaListaLotesPintura extends StatelessWidget {
  const TelaListaLotesPintura({super.key});

  @override
  Widget build(BuildContext context) {
    final Color corSetor = Colors.brown.shade700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fila: Pintura'),
        backgroundColor: corSetor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 1. Busca itens que têm 'pintura' no roteiro planejado
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('roteiro', arrayContains: 'pintura')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          // Agrupamento por OS
          Map<String, List<DocumentSnapshot>> agrupadosPorOS = {};
          for (var doc in docs) {
            final dados = doc.data() as Map<String, dynamic>?;
            if (dados == null || !dados.containsKey('os_id') && !dados.containsKey('osId')) continue;

            String osId = (dados['osId'] ?? dados['os_id']).toString();
            if (!agrupadosPorOS.containsKey(osId)) agrupadosPorOS[osId] = [];
            agrupadosPorOS[osId]!.add(doc);
          }

          // 2. Filtro: Só mostra se houver pelo menos um item REALMENTE aguardando pintura
          List<String> osAtivas = agrupadosPorOS.keys.where((osId) {
            return agrupadosPorOS[osId]!.any((doc) => doc['status'] == 'aguardando_pintura');
          }).toList();

          if (osAtivas.isEmpty) {
            return const Center(child: Text('Nenhum extintor pendente de pintura.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: osAtivas.length,
            itemBuilder: (context, index) {
              String osId = osAtivas[index];
              List<DocumentSnapshot> itensDaOS = agrupadosPorOS[osId]!;

              // Contador com Memória
              int totalVaoPintar = itensDaOS.length;

              // Considera processado se o status já passou da pintura (ex: recarga, estanqueidade)
              int jaPassaramOuEstao = itensDaOS.where((doc) {
                String st = doc['status']?.toString() ?? '';
                return st != 'aguardando_limpeza' &&
                    st != 'aguardando_lixa' &&
                    st != 'aguardando_th' &&
                    st != 'aguardando_manutencao_valvula';
              }).length;

              double progresso = jaPassaramOuEstao / totalVaoPintar;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => TelaEstacaoPintura(osId: osId)
                  )),
                  leading: CircleAvatar(
                    backgroundColor: corSetor,
                    child: Text('$jaPassaramOuEstao/$totalVaoPintar',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  title: Text('Lote OS: $osId'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progresso,
                        backgroundColor: Colors.grey[200],
                        color: jaPassaramOuEstao == totalVaoPintar ? Colors.green : corSetor,
                        minHeight: 6,
                      ),
                      const SizedBox(height: 4),
                      Text(jaPassaramOuEstao == totalVaoPintar ? 'Lote pintado!' : 'Aguardando pintura...'),
                    ],
                  ),
                  trailing: const Icon(Icons.format_paint, color: Colors.brown),
                ),
              );
            },
          );
        },
      ),
    );
  }
}