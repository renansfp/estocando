import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_lixa.dart';

class TelaListaLotesLixa extends StatefulWidget {
  const TelaListaLotesLixa({super.key});

  @override
  State<TelaListaLotesLixa> createState() => _TelaListaLotesLixaState();
}

class _TelaListaLotesLixaState extends State<TelaListaLotesLixa> {
  final Color _corSetor = const Color(0xFF455A64);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fila de Lixa / Jato'),
        backgroundColor: _corSetor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Buscamos TODOS os itens que possuem 'lixa' no roteiro, idependente do status
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('roteiro', arrayContains: 'lixa')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          // Agrupamos por OS para montar os Cards
          Map<String, List<DocumentSnapshot>> agrupadosPorOS = {};
          for (var doc in docs) {
            final dados = doc.data() as Map<String, dynamic>;
            String osId = dados['osId']?.toString() ?? 'S/OS';
            if (!agrupadosPorOS.containsKey(osId)) agrupadosPorOS[osId] = [];
            agrupadosPorOS[osId]!.add(doc);
          }

          // Filtramos para mostrar apenas OSs que ainda tenham alguém REALMENTE na fila de lixa
          // mas mantendo os dados de quem já passou para o contador
          List<String> osParaMostrar = agrupadosPorOS.keys.where((osId) {
            return agrupadosPorOS[osId]!.any((doc) => doc['status'] == 'aguardando_lixa');
          }).toList();

          if (osParaMostrar.isEmpty) return const Center(child: Text('Nenhum item pendente de lixa.'));

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: osParaMostrar.length,
            itemBuilder: (context, index) {
              String osId = osParaMostrar[index];
              List<DocumentSnapshot> itensDaOSNesseSetor = agrupadosPorOS[osId]!;

              // LÓGICA DO CONTADOR INTELIGENTE
              // 1. Total: apenas os itens dessa OS que o roteiro diz que VÃO PASSAR por aqui
              int totalVaoPassar = itensDaOSNesseSetor.length;

              // 2. Passaram/Estão: itens que o status NÃO é mais 'limpeza' (já chegaram ou passaram da lixa)
              int jaPassaramOuEstao = itensDaOSNesseSetor.where((doc) {
                String status = doc['status']?.toString() ?? '';
                return status != 'aguardando_limpeza' && status != 'em_limpeza';
              }).length;

              double progresso = jaPassaramOuEstao / totalVaoPassar;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => TelaEstacaoLixa(osId: osId)
                  )),
                  leading: CircleAvatar(
                    backgroundColor: _corSetor,
                    child: Text('$jaPassaramOuEstao/$totalVaoPassar',
                        style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                  title: Text('Lote OS: $osId'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progresso,
                        backgroundColor: Colors.grey[300],
                        color: jaPassaramOuEstao == totalVaoPassar ? Colors.green : Colors.blue,
                        minHeight: 6,
                      ),
                      const SizedBox(height: 4),
                      Text(jaPassaramOuEstao == totalVaoPassar
                          ? 'Todos os itens processados no setor'
                          : 'Processando itens do roteiro...'),
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