// Salve como: lib/telas/producao/tela_detalhes_lote_valvula.dart
// (VERSÃO CORRIGIDA - Busca na coleção raiz 'itens_os')

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_manutencao_valvula.dart';

class TelaDetalhesLoteValvula extends StatelessWidget {
  final String osId;
  final String clienteNome;
  final String usuarioNome;

  const TelaDetalhesLoteValvula({
    super.key,
    required this.osId,
    required this.clienteNome,
    required this.usuarioNome,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Itens do Lote (Válvula)', style: TextStyle(fontSize: 16)),
            Text(clienteNome, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300)),
          ],
        ),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal[700],
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text("BIPAR MANUAL", style: TextStyle(color: Colors.white)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TelaEstacaoManutencaoValvula(
                usuarioNome: usuarioNome,
                estacaoNome: 'Bancada Válvula 01',
              ),
            ),
          );
        },
      ),
      body: StreamBuilder<QuerySnapshot>(
        // --- CORREÇÃO AQUI: Busca em 'itens_os' ---
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('osId', isEqualTo: osId)
        // Aqui mostramos TUDO que for CO2 ou estiver na Válvula, para ter histórico
        // Mas para facilitar, vamos focar no que está pendente:
            .where('status', isEqualTo: 'aguardando_manutencao_valvula')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final itens = snapshot.data!.docs;

          if (itens.isEmpty) {
            return const Center(child: Text('Todos os itens deste lote já foram processados!'));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: itens.length,
            itemBuilder: (context, index) {
              final doc = itens[index];
              final item = doc.data() as Map<String, dynamic>;

              final codigo = item['idCrachaTemporario'] ?? '---';
              final tipo = item['tipoAgente'] ?? '';

              return Card(
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal, // Cor da Válvula
                    child: const Icon(Icons.build, color: Colors.white, size: 20),
                  ),
                  title: Text("Item: $codigo"),
                  subtitle: Text("Tipo: $tipo"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.teal),

                  onTap: () {
                    // Navega simulando o Bip com o ID do equipamento (que está salvo no item)
                    // O campo 'equipamentoId' é o ID do documento na coleção equipamentos
                    final equipamentoId = item['equipamentoId'];

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TelaEstacaoManutencaoValvula(
                          usuarioNome: usuarioNome,
                          estacaoNome: 'Bancada Válvula 01',
                          // Passamos o ID para a tela já buscar os dados
                          codigoPreDefinido: equipamentoId,
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