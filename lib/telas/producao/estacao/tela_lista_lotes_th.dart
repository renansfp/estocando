import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_th.dart';

class TelaListaLotesTH extends StatelessWidget {
  const TelaListaLotesTH({super.key});

  @override
  Widget build(BuildContext context) {
    final Color corSetor = Colors.purple.shade700;
    final usuario = Provider.of<UsuarioProvider>(context).usuario;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fila: Teste Hidrostático'),
        backgroundColor: corSetor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('roteiro', arrayContains: 'th')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          Map<String, List<DocumentSnapshot>> agrupadosPorOS = {};
          for (var doc in docs) {
            final dados = doc.data() as Map<String, dynamic>?;
            if (dados == null || !dados.containsKey('osId')) continue;

            String osId = dados['osId'].toString();
            if (!agrupadosPorOS.containsKey(osId)) agrupadosPorOS[osId] = [];
            agrupadosPorOS[osId]!.add(doc);
          }

          List<String> osAtivas = agrupadosPorOS.keys.where((osId) {
            return agrupadosPorOS[osId]!.any((doc) => doc['status'] == 'aguardando_th');
          }).toList();

          if (osAtivas.isEmpty) {
            return const Center(child: Text('Nenhum extintor pendente de TH.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: osAtivas.length,
            itemBuilder: (context, index) {
              String osId = osAtivas[index];
              List<DocumentSnapshot> itensDaEtapa = agrupadosPorOS[osId]!;

              int totalVaoPassar = itensDaEtapa.length;
              int jaPassaramOuEstao = itensDaEtapa.where((doc) {
                String st = doc['status']?.toString() ?? '';
                return st != 'aguardando_limpeza' && st != 'em_limpeza' && st != 'aguardando_lixa';
              }).length;

              double progresso = jaPassaramOuEstao / totalVaoPassar;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => TelaEstacaoTH(
                        // ALTERADO DE 'numeroLote' PARA 'osId' PARA TESTAR O PADRÃO
                        osIdAtual: osId,
                      )
                  )),
                  leading: CircleAvatar(
                    backgroundColor: corSetor,
                    child: Text('$jaPassaramOuEstao/$totalVaoPassar',
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
                        color: jaPassaramOuEstao == totalVaoPassar ? Colors.green : corSetor,
                        minHeight: 6,
                      ),
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