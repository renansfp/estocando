import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_pintura.dart'; // Vamos criar a seguir

class TelaListaLotesPintura extends StatefulWidget {
  const TelaListaLotesPintura({super.key});

  @override
  State<TelaListaLotesPintura> createState() => _TelaListaLotesPinturaState();
}

class _TelaListaLotesPinturaState extends State<TelaListaLotesPintura> {
  // Cor da Pintura (Marrom)
  final Color _corSetor = Colors.brown[700]!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lotes na Pintura (Estufa)'),
        backgroundColor: _corSetor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ordens_servico')
            .where('statusLote', isNotEqualTo: 'finalizado')
            .orderBy('statusLote')
            .orderBy('dataEntrada', descending: false)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final lotes = snapshot.data!.docs;

          if (lotes.isEmpty) return _buildEmptyState();

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: lotes.length,
            itemBuilder: (context, index) {
              final doc = lotes[index];
              final dados = doc.data() as Map<String, dynamic>;
              final numeroOS = doc.id;
              final cliente = dados['clienteNome'] ?? 'Cliente Desconhecido';

              String dataFormatada = "Data N/D";
              if (dados['dataEntrada'] != null) {
                final timestamp = dados['dataEntrada'] as Timestamp;
                dataFormatada = DateFormat('dd/MM HH:mm').format(timestamp.toDate());
              }

              // --- CAÇA-FANTASMAS DA PINTURA 🎨 ---
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('itens_os')
                    .where('osId', isEqualTo: numeroOS)
                    .where('status', isEqualTo: 'aguardando_pintura') // Filtro da Pintura
                    .snapshots(),
                builder: (context, itemSnapshot) {
                  if (!itemSnapshot.hasData) return const SizedBox.shrink();

                  final itensPendentes = itemSnapshot.data!.docs.length;

                  if (itensPendentes == 0) return const SizedBox.shrink();

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      leading: CircleAvatar(
                        backgroundColor: _corSetor,
                        radius: 25,
                        child: Text(
                          numeroOS.length >= 3 ? numeroOS.substring(numeroOS.length - 2) : '#',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        'Lote: $numeroOS',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cliente, maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.format_paint, size: 14, color: _corSetor),
                              const SizedBox(width: 4),
                              Text(
                                '$itensPendentes para pintar',
                                style: TextStyle(fontWeight: FontWeight.bold, color: _corSetor),
                              ),
                              const Spacer(),
                              Text(dataFormatada, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TelaEstacaoPintura(osId: doc.id),
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
          Icon(Icons.format_paint, size: 80, color: Colors.grey),
          SizedBox(height: 20),
          Text('Estufa vazia. Nenhuma pintura pendente.',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}