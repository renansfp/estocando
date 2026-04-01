// lib/telas/producao/lista/tela_lista_lotes_estanqueidade.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// IMPORTANTE: Importe a tela de execução aqui
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_estanqueidade.dart';

class TelaListaLotesEstanqueidade extends StatelessWidget {
  final String titulo;
  final List<String> filtrosAgente;

  const TelaListaLotesEstanqueidade({
    super.key,
    required this.titulo,
    required this.filtrosAgente
  });

  @override
  Widget build(BuildContext context) {
    final Color corSetor = Colors.lightBlue.shade800;

    return Scaffold(
      appBar: AppBar(
        title: Text('Fila: $titulo'),
        backgroundColor: corSetor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // MELHORIA: Busca qualquer item que tenha "estanqueidade" no roteiro
        // O filtro fino faremos no agrupamento abaixo.
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('statusAtual', isEqualTo: 'emProducao')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          Map<String, List<DocumentSnapshot>> agrupadosPorOS = {};

          for (var doc in docs) {
            final dados = doc.data() as Map<String, dynamic>;
            final agenteItem = dados['tipoAgente']?.toString().toUpperCase() ?? '';
            final List roteiro = dados['roteiro'] ?? [];

            // FILTRO: Se o agente bate com o setor E o item tem estanqueidade no roteiro
            bool temEstanqueidade = roteiro.any((e) => e.toString().contains('estanqueidade'));
            bool agenteBate = filtrosAgente.any((f) => agenteItem.contains(f.toUpperCase()));

            if (temEstanqueidade && agenteBate) {
              String osId = dados['osId'].toString();
              if (!agrupadosPorOS.containsKey(osId)) agrupadosPorOS[osId] = [];
              agrupadosPorOS[osId]!.add(doc);
            }
          }

          // Filtra para mostrar apenas OSs que tenham itens aguardando estanqueidade AGORA
          List<String> osAtivas = agrupadosPorOS.keys.where((osId) {
            return agrupadosPorOS[osId]!.any((doc) =>
            doc['status'].toString() == 'aguardando_estanqueidade');
          }).toList();

          if (osAtivas.isEmpty) {
            return const Center(child: Text('Nenhum lote pendente neste setor.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: osAtivas.length,
            itemBuilder: (context, index) {
              String osId = osAtivas[index];
              List<DocumentSnapshot> itensDaOS = agrupadosPorOS[osId]!;

              int totalParaTestar = itensDaOS.length;
              int concluidos = itensDaOS.where((doc) {
                // Se o status já avançou para a próxima etapa do roteiro
                return doc['status'].toString() != 'aguardando_estanqueidade' &&
                    !doc['status'].toString().contains('recarga');
              }).length;

              double progresso = totalParaTestar > 0 ? concluidos / totalParaTestar : 0;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  // AGORA O CLIQUE FUNCIONA
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => TelaEstacaoEstanqueidade(osId: osId, filtrosAgente: filtrosAgente))
                  ),
                  leading: CircleAvatar(
                    backgroundColor: corSetor,
                    child: Text('$concluidos/$totalParaTestar',
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
                      Text(progresso == 1.0 ? 'Teste Concluído' : 'Aguardando submersão...'),
                    ],
                  ),
                  // ÍCONE DINÂMICO AQUI
                  trailing: Icon(
                      titulo.contains('PQS') || titulo.contains('PÓ')
                          ? Icons.bubble_chart // Bolhas para o pó no tanque
                          : Icons.water_drop,   // Gota para Água/Espuma
                      color: Colors.blue.shade300
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