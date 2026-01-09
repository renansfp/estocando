// Salve como: lib/telas/producao/estacao/tela_lista_lotes_manutencao.dart
// (VERSÃO CORRIGIDA - Busca na coleção raiz 'itens_os')

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/telas/producao/tela_detalhes_lote_valvula.dart';

class TelaListaLotesManutencao extends StatefulWidget {
  const TelaListaLotesManutencao({super.key});

  @override
  State<TelaListaLotesManutencao> createState() => _TelaListaLotesManutencaoState();
}

class _TelaListaLotesManutencaoState extends State<TelaListaLotesManutencao> {
  final Color _corSetor = Colors.teal[700]!;

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
    final usuario = Provider.of<UsuarioProvider>(context).usuario;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lotes na Válvula (CO2)'),
        backgroundColor: _corSetor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Busca todas as OSs ativas (ordenadas pela entrada)
        stream: FirebaseFirestore.instance
            .collection('ordens_servico')
            .orderBy('dataEntrada', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final lotes = snapshot.data!.docs;

          if (lotes.isEmpty) {
            return const Center(child: Text('Nenhuma OS encontrada.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: lotes.length,
            itemBuilder: (context, index) {
              final doc = lotes[index];
              final dados = doc.data() as Map<String, dynamic>;
              final osId = doc.id;
              final cliente = dados['clienteNome'] ?? 'Cliente Desconhecido';

              String dataFormatada = "---";
              var campoData = dados['dataEntrada'];
              if (campoData != null && campoData is Timestamp) {
                dataFormatada = DateFormat('dd/MM HH:mm').format(campoData.toDate());
              }

              String idVisual = _obterIdCurto(osId, dados);

              // --- CAÇA-FANTASMAS DA VÁLVULA ---
              // Correção: Agora busca em 'itens_os' filtrando pelo ID da OS
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('itens_os') // <--- MUDANÇA AQUI
                    .where('osId', isEqualTo: osId) // <--- VÍNCULO NOVO
                    .where('status', isEqualTo: 'aguardando_manutencao_valvula')
                    .snapshots(),
                builder: (context, itemSnapshot) {
                  // Se não tem item pendente, esconde o card
                  if (!itemSnapshot.hasData || itemSnapshot.data!.docs.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final itensPendentes = itemSnapshot.data!.docs.length;

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
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
                              Icon(Icons.handyman, size: 14, color: _corSetor),
                              const SizedBox(width: 4),
                              Text(
                                '$itensPendentes válvulas para revisar',
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
                            builder: (context) => TelaDetalhesLoteValvula(
                              osId: osId,
                              clienteNome: cliente,
                              usuarioNome: usuario?.nome ?? 'Técnico',
                            ),
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
}