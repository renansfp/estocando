// Salve como: lib/telas/producao/estacao/tela_lista_lotes_montagem.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
// ---> MUDANÇA 1: Importar a tela de execução que criamos
import 'tela_estacao_montagem.dart';

class TelaListaLotesMontagem extends StatefulWidget {
  const TelaListaLotesMontagem({super.key});

  @override
  State<TelaListaLotesMontagem> createState() => _TelaListaLotesMontagemState();
}

class _TelaListaLotesMontagemState extends State<TelaListaLotesMontagem> {
  final Color _corSetor = Colors.indigo;

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
    // Recupera usuário (mesmo não usando na navegação agora, é bom manter o padrão)
    final usuario = Provider.of<UsuarioProvider>(context).usuario;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lotes na Montagem'),
        backgroundColor: _corSetor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ordens_servico')
            .orderBy('dataEntrada', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final lotes = snapshot.data!.docs;

          if (lotes.isEmpty) {
            return const Center(child: Text('Nenhuma OS em produção.'));
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
                try {
                  if (dados['dataEntrada'] is Timestamp) {
                    dataFormatada = DateFormat('dd/MM HH:mm').format((dados['dataEntrada'] as Timestamp).toDate());
                  } else {
                    dataFormatada = dados['dataEntrada'].toString();
                  }
                } catch (e) {}
              }

              String idVisual = _obterIdCurto(osId, dados);

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('itens_os')
                    .where('osId', isEqualTo: osId)
                    .where('status', isEqualTo: 'aguardando_montagem')
                    .snapshots(),
                builder: (context, itemSnapshot) {
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
                              Icon(Icons.build, size: 14, color: _corSetor),
                              const SizedBox(width: 4),
                              Text(
                                '$itensPendentes para montar',
                                style: TextStyle(fontWeight: FontWeight.bold, color: _corSetor),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      // ---> MUDANÇA 2: Alterado de SnackBar para Navigator
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            // Passamos o ID da OS para a tela que criamos agora a pouco
                            builder: (context) => TelaEstacaoMontagem(osId: osId),
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