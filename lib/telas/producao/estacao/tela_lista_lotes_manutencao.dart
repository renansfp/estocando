import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_manutencao_valvula.dart';

class TelaListaLotesManutencao extends StatefulWidget {
  const TelaListaLotesManutencao({super.key});

  @override
  State<TelaListaLotesManutencao> createState() => _TelaListaLotesManutencaoState();
}

class _TelaListaLotesManutencaoState extends State<TelaListaLotesManutencao> {
  final Color _corSetor = Colors.teal.shade700;

  @override
  Widget build(BuildContext context) {
    final usuario = Provider.of<UsuarioProvider>(context).usuario;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fila: Manutenção de Componentes'),
        backgroundColor: _corSetor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Buscamos itens que têm 'manutencao_valvula' no roteiro
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('roteiro', arrayContains: 'manutencao_valvula')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          // Agrupamento Blindado por OS
          Map<String, List<DocumentSnapshot>> agrupadosPorOS = {};
          for (var doc in docs) {
            final dados = doc.data() as Map<String, dynamic>?;
            // Proteção contra dados incompletos (lixo)
            if (dados == null || !dados.containsKey('osId')) continue;

            String osId = dados['osId'].toString();
            if (!agrupadosPorOS.containsKey(osId)) agrupadosPorOS[osId] = [];
            agrupadosPorOS[osId]!.add(doc);
          }

          // Filtro: Só mostra a OS se houver pelo menos um item aguardando a válvula
          List<String> osAtivas = agrupadosPorOS.keys.where((osId) {
            return agrupadosPorOS[osId]!.any((doc) => doc['status'] == 'aguardando_manutencao_valvula');
          }).toList();

          if (osAtivas.isEmpty) {
            return const Center(child: Text('Nenhum componente pendente de revisão.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: osAtivas.length,
            itemBuilder: (context, index) {
              String osId = osAtivas[index];
              List<DocumentSnapshot> itensDaEtapa = agrupadosPorOS[osId]!;

              // CONTADOR INTELIGENTE (MEMÓRIA)
              int totalVaoPassar = itensDaEtapa.length;

              // Itens que já chegaram na válvula ou já passaram dela
              int jaPassaramOuEstao = itensDaEtapa.where((doc) {
                String st = doc['status']?.toString() ?? '';
                // Não conta se ainda estiver na limpeza ou lixa
                return st != 'aguardando_limpeza' && st != 'em_limpeza' && st != 'aguardando_lixa';
              }).length;

              double progresso = jaPassaramOuEstao / totalVaoPassar;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => TelaEstacaoManutencaoValvula(
                    usuarioNome: usuario?.nome ?? 'Técnico',
                    estacaoNome: 'Manutenção de Componentes',
                    osId: osId,
                  ))),
                  leading: CircleAvatar(
                    backgroundColor: _corSetor,
                    child: Text('$jaPassaramOuEstao/$totalVaoPassar',
                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text('Lote OS: $osId', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progresso,
                        backgroundColor: Colors.grey[200],
                        color: jaPassaramOuEstao == totalVaoPassar ? Colors.green : Colors.teal,
                        minHeight: 6,
                      ),
                      const SizedBox(height: 4),
                      Text(jaPassaramOuEstao == totalVaoPassar
                          ? 'Todos os componentes revisados'
                          : 'Revisando componentes do lote...'),
                    ],
                  ),
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