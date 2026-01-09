import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_lixa.dart';

class TelaListaLotesLixa extends StatefulWidget {
  const TelaListaLotesLixa({super.key});

  @override
  State<TelaListaLotesLixa> createState() => _TelaListaLotesLixaState();
}

class _TelaListaLotesLixaState extends State<TelaListaLotesLixa> {
  // Cor do setor Lixa (BlueGrey para diferenciar)
  final Color _corSetor = Colors.blueGrey[700]!;

  // Função para padronizar o ID (5 dígitos)
  String _obterIdCurto(String idCompleto, Map<String, dynamic> dados) {
    if (dados['numeroOS'] != null && dados['numeroOS'].toString().isNotEmpty) {
      return dados['numeroOS'];
    }
    if (idCompleto.length >= 5) {
      return idCompleto.substring(idCompleto.length - 5).toUpperCase();
    }
    return idCompleto;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lotes na Lixa (Fila)'),
        backgroundColor: _corSetor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Buscamos todas as OSs ativas. O filtro real é nos itens.
        stream: FirebaseFirestore.instance
            .collection('ordens_servico')
            .where('statusLote', isNotEqualTo: 'finalizada') // Pega tudo que não acabou
            .orderBy('statusLote')
            .orderBy('dataEntrada', descending: false)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final lotes = snapshot.data!.docs;

          if (lotes.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: lotes.length,
            itemBuilder: (context, index) {
              final doc = lotes[index];
              final dados = doc.data() as Map<String, dynamic>;
              final osId = doc.id;
              final cliente = dados['clienteNome'] ?? 'Cliente Desconhecido';

              String dataFormatada = "Data N/D";
              if (dados['dataEntrada'] != null) {
                final timestamp = dados['dataEntrada'] as Timestamp;
                dataFormatada = DateFormat('dd/MM HH:mm').format(timestamp.toDate());
              }

              // ID Visual (5 dígitos)
              String idVisual = _obterIdCurto(osId, dados);

              // --- O CAÇA-FANTASMAS DA LIXA 👻 ---
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('itens_os')
                    .where('osId', isEqualTo: osId)
                    .where('status', isEqualTo: 'aguardando_lixa') // <--- O FILTRO MÁGICO
                    .snapshots(),
                builder: (context, itemSnapshot) {
                  if (!itemSnapshot.hasData) return const SizedBox.shrink();

                  final itensPendentes = itemSnapshot.data!.docs.length;

                  // Se não tem nada pra lixar nesta OS, esconde o card!
                  if (itensPendentes == 0) {
                    return const SizedBox.shrink();
                  }

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      leading: CircleAvatar(
                        backgroundColor: _corSetor,
                        radius: 24,
                        child: Text(
                          idVisual,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        cliente,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Entrada: $dataFormatada', style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.build_circle, size: 14, color: _corSetor),
                              const SizedBox(width: 4),
                              Text(
                                '$itensPendentes para lixar',
                                style: TextStyle(fontWeight: FontWeight.bold, color: _corSetor),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TelaEstacaoLixa(osId: doc.id),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.grey),
          SizedBox(height: 20),
          Text('Nenhum lote aguardando lixa.',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}