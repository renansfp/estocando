// Salve como: lib/telas/producao/tela_lista_lotes_th.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_th.dart';
import 'package:provider/provider.dart';

class TelaListaLotesTH extends StatelessWidget {
  const TelaListaLotesTH({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = Provider.of<UsuarioProvider>(context).usuario;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lotes em TH (Aguardando)'),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ordens_servico')
            .where('statusLote', isNotEqualTo: 'finalizada')
            .orderBy('statusLote')
            .orderBy('dataEntrada', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final lotes = snapshot.data!.docs;

          if (lotes.isEmpty) {
            return const Center(child: Text('Nenhuma OS em produção.'));
          }

          return ListView.builder(
            itemCount: lotes.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final doc = lotes[index];
              final lote = doc.data() as Map<String, dynamic>;
              final osId = doc.id;

              String dataFormatada = '---';
              var campoData = lote['dataEntrada'] ?? lote['dataAbertura'];
              if (campoData != null && campoData is Timestamp) {
                dataFormatada = DateFormat('dd/MM HH:mm').format(campoData.toDate());
              }

              // Busca itens desta OS que estão parados no TH
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('itens_os')
                    .where('osId', isEqualTo: osId)
                    .where('status', isEqualTo: 'aguardando_teste_hidro')
                    .snapshots(),
                builder: (context, itemSnapshot) {
                  if (!itemSnapshot.hasData || itemSnapshot.data!.docs.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final qtd = itemSnapshot.data!.docs.length;

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Icon(Icons.science, color: Colors.blue.shade900),
                      ),
                      title: Text(
                        "${lote['numeroOS']} - ${lote['clienteNome']}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("Entrada: $dataFormatada \n$qtd itens para testar"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TelaEstacaoTH(
                              usuarioNome: usuario?.nome ?? 'Técnico',
                              estacaoNome: 'Bancada TH 01',
                              osIdAtual: osId, // <--- ENVIANDO O ID DA OS
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