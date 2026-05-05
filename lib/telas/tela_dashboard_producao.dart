// lib/telas/tela_dashboard_producao.dart
// Migrada para Repository Pattern — sem acesso direto ao Firestore.
// Usa ItemOsProvider.streamContadoresDashboard() que já retorna Map<String, int>.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';

class TelaDashboardProducao extends StatelessWidget {
  const TelaDashboardProducao({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<UsuarioProvider>().usuario;

    if (usuario == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel de Produção'),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade100,
      body: StreamBuilder<Map<String, int>>(
        stream: context
            .read<ItemOsProvider>()
            .streamContadoresDashboard(usuario.empresaId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Erro: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final contadores = snapshot.data ?? {};

          final naDescarga = contadores['aguardando_descarga'] ?? 0;
          final naLimpeza = contadores['aguardando_limpeza'] ?? 0;
          final naPintura = contadores['aguardando_pintura'] ?? 0;
          final noTeste = contadores['aguardando_th'] ?? 0;
          final naRecarga = contadores['recarga_montagem'] ?? 0;
          final total = contadores.values.fold(0, (a, b) => a + b);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Total de Itens em Produção: $total',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 12),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 10),
                const Text('1. Entrada',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildCard('Descarga', naDescarga, Colors.orange,
                        Icons.fire_extinguisher),
                    _buildCard('Limpeza', naLimpeza, Colors.brown,
                        Icons.cleaning_services),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('2. Processos',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildCard('Pintura', naPintura, Colors.red,
                        Icons.format_paint),
                    _buildCard('Teste Hidro', noTeste, Colors.blue,
                        Icons.water_drop),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('3. Finalização',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildCard('Recarga/Montagem', naRecarga, Colors.green,
                    Icons.build_circle,
                    fullWidth: true),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(
      String titulo, int quantidade, Color cor, IconData icone,
      {bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : 160,
      constraints: const BoxConstraints(minWidth: 150),
      height: 110,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: cor, width: 5)),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1), blurRadius: 5)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icone, color: cor, size: 28),
              Text(
                '$quantidade',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: cor),
              ),
            ],
          ),
          Text(titulo,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}