import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_saque.dart';

class TelaListaLotesSaque extends StatefulWidget {
  const TelaListaLotesSaque({super.key});

  @override
  State<TelaListaLotesSaque> createState() => _TelaListaLotesSaqueState();
}

class _TelaListaLotesSaqueState extends State<TelaListaLotesSaque> {
  final Color _corSetor = Colors.red.shade700;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fila: Saque de Válvula'),
        backgroundColor: _corSetor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 1. Busca os itens que possuem 'saque_valvula' no DNA do roteiro
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('roteiro', arrayContains: 'saque_valvula')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          // Agrupamento Blindado (Proteção contra o erro de tela cinza do Web Release)
          Map<String, List<DocumentSnapshot>> agrupadosPorOS = {};
          for (var doc in docs) {
            final dados = doc.data() as Map<String, dynamic>?;
            if (dados == null || !dados.containsKey('osId')) continue;

            String osId = dados['osId'].toString();
            if (!agrupadosPorOS.containsKey(osId)) agrupadosPorOS[osId] = [];
            agrupadosPorOS[osId]!.add(doc);
          }

          // 2. Filtro: Só mostra a OS se houver pelo menos um item aguardando saque_valvula
          List<String> osAtivas = agrupadosPorOS.keys.where((osId) {
            return agrupadosPorOS[osId]!.any((doc) => doc['status'] == 'aguardando_saque_valvula');
          }).toList();

          if (osAtivas.isEmpty) {
            return const Center(child: Text('Nenhum item pendente de saque de válvula.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: osAtivas.length,
            itemBuilder: (context, index) {
              String osId = osAtivas[index];
              List<DocumentSnapshot> itensDaEtapa = agrupadosPorOS[osId]!;

              // LÓGICA DO CONTADOR COM MEMÓRIA
              int totalVaoPassar = itensDaEtapa.length;

              // Considera processado se o status já passou de todas as etapas iniciais
              int jaPassaramOuEstao = itensDaEtapa.where((doc) {
                String st = doc['status']?.toString() ?? '';
                return st != 'aguardando_limpeza' &&
                    st != 'em_limpeza' &&
                    st != 'aguardando_lixa' &&
                    st != 'aguardando_manutencao_valvula';
              }).length;

              double progresso = jaPassaramOuEstao / totalVaoPassar;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (ctx) => TelaEstacaoSaque(numeroLote: osId)
                  )),
                  leading: CircleAvatar(
                    backgroundColor: _corSetor,
                    child: Text('$jaPassaramOuEstao/$totalVaoPassar',
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
                        color: jaPassaramOuEstao == totalVaoPassar ? Colors.green : Colors.red,
                        minHeight: 6,
                      ),
                      const SizedBox(height: 4),
                      Text(jaPassaramOuEstao == totalVaoPassar
                          ? 'Lote completo para saque'
                          : 'Aguardando itens do lote...'),
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