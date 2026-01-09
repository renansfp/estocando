import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_saque.dart';

class TelaListaLotesSaque extends StatefulWidget {
  const TelaListaLotesSaque({super.key});

  @override
  State<TelaListaLotesSaque> createState() => _TelaListaLotesSaqueState();
}

class _TelaListaLotesSaqueState extends State<TelaListaLotesSaque> {
  // Cor do setor Saque (Vermelho para atenção)
  final Color _corSetor = Colors.red[700]!;

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
        title: const Text('Lotes no Saque de Válvula'),
        backgroundColor: _corSetor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Busca todas as OSs ativas no chão de fábrica
        stream: FirebaseFirestore.instance
            .collection('ordens_servico')
            .where('statusLote', isNotEqualTo: 'finalizada')
            .orderBy('statusLote')
            .orderBy('dataEntrada', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

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

              String idVisual = _obterIdCurto(osId, dados);

              // --- CAÇA-FANTASMAS DO SAQUE 👻 ---
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('itens_os')
                    .where('osId', isEqualTo: osId)
                    .where('status', isEqualTo: 'aguardando_saque_valvula')
                    .snapshots(),
                builder: (context, itemSnapshot) {
                  // Se não tem dados ou a lista está vazia, esconde o card
                  if (!itemSnapshot.hasData || itemSnapshot.data!.docs.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final itensPendentes = itemSnapshot.data!.docs.length;

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
                      title: Text(cliente, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Entrada: $dataFormatada', style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.settings_backup_restore, size: 14, color: _corSetor),
                              const SizedBox(width: 4),
                              Text(
                                '$itensPendentes para sacar',
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
                            builder: (context) => TelaEstacaoSaque(numeroLote: osId),
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
          Text('Nenhuma válvula para sacar.', style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }
}