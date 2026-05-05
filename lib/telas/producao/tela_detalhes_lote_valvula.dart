// lib/telas/producao/tela_detalhes_lote_valvula.dart
// Migrada para Repository Pattern — sem acesso direto ao Firestore.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
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
            const Text('Itens do Lote (Válvula)',
                style: TextStyle(fontSize: 16)),
            Text(clienteNome,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w300)),
          ],
        ),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal[700],
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text('BIPAR MANUAL',
            style: TextStyle(color: Colors.white)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TelaEstacaoManutencaoValvula(
              usuarioNome: usuarioNome,
              estacaoNome: 'Bancada Válvula 01',
              osId: osId,
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: context
            .read<ItemOsProvider>()
            .streamItensPorOsEStatus(osId, 'aguardando_manutencao_valvula'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final itens = snapshot.data!;

          if (itens.isEmpty) {
            return const Center(
              child: Text(
                  'Todos os itens deste lote já foram processados!'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: itens.length,
            itemBuilder: (context, index) {
              final item = itens[index];
              final codigoCracha = item['idCrachaTemporario'] ?? '---';
              final tipo = item['tipoAgente'] ?? '';

              return Card(
                elevation: 2,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Icon(Icons.build, color: Colors.white, size: 20),
                  ),
                  title: Text('Item: $codigoCracha'),
                  subtitle: Text('Tipo: $tipo'),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.teal),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TelaEstacaoManutencaoValvula(
                        usuarioNome: usuarioNome,
                        estacaoNome: 'Bancada Válvula 01',
                        osId: osId,
                        codigoPreDefinido: codigoCracha,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}