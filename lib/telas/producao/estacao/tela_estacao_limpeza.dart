// Salve como: lib/telas/producao/estacao/tela_estacao_limpeza.dart
// (VERSÃO v4.3 - A Verdadeira!)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_triagem_limpeza.dart';

class TelaEstacaoLimpeza extends StatefulWidget {
  final String osId;

  const TelaEstacaoLimpeza({Key? key, required this.osId}) : super(key: key);

  @override
  _TelaEstacaoLimpezaState createState() => _TelaEstacaoLimpezaState();
}

class _TelaEstacaoLimpezaState extends State<TelaEstacaoLimpeza> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Título fixo para sabermos que é a versão certa
        title: const Text('Estação: Limpeza & Triagem'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('osId', isEqualTo: widget.osId)
        // Aqui ele pega os itens que você liberou na tela de controle
            .where('status', isEqualTo: 'aguardando_limpeza')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final itens = snapshot.data!.docs;

          // Se estiver vazio, mostramos o aviso em vez de tela branca
          if (itens.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cleaning_services_outlined, size: 60, color: Colors.grey),
                    const SizedBox(height: 20),
                    const Text(
                      'Nenhum item liberado!',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Se a OS tem itens, vá no Painel de Controle (Descarga) e libere o lote.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Voltar"),
                    )
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: itens.length,
            itemBuilder: (context, index) {
              final itemDoc = itens[index];
              final dados = itemDoc.data() as Map<String, dynamic>;

              final idRastreio = dados['idCrachaTemporario'] ?? '???';
              final tipo = dados['tipoAgente'] ?? '?';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(Icons.cleaning_services, color: Colors.blue[900]),
                  ),
                  title: Text('Item: $idRastreio',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Tipo: ${tipo.toUpperCase()}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TelaTriagemLimpeza(
                          itemOsId: itemDoc.id,
                          idRastreio: idRastreio,
                          tipoAgente: tipo,
                          equipamentoId: dados['equipamentoId'] ?? '',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}