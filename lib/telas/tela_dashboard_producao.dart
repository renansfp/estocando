// Salve como: lib/telas/tela_dashboard_producao.dart
// (VERSÃO v3.1 - "Correção de Sintaxe")

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:provider/provider.dart';

class TelaDashboardProducao extends StatelessWidget {
  const TelaDashboardProducao({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = Provider.of<UsuarioProvider>(context).usuario;

    if (usuario == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel de Produção'),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade100,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('empresaId', isEqualTo: usuario.empresaId)
            .snapshots(),
        builder: (context, snapshot) {

          // 1. Tratamento de Erros
          if (snapshot.hasError) {
            return Center(child: Text("Erro: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          }

          // 🔧 CORREÇÃO AQUI: Usamos '==' para verificar se está esperando
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nenhum dado encontrado."));
          }

          // 2. Contabilidade
          final docs = snapshot.data!.docs;

          int naDescarga = 0;
          int naLimpeza = 0;
          int naPintura = 0;
          int noTeste = 0;
          int naRecarga = 0;

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] as String? ?? '';

            if (status == 'aguardando_descarga') naDescarga++;
            else if (status == 'aguardando_limpeza') naLimpeza++;
            else if (status == 'aguardando_pintura') naPintura++;
            else if (status == 'aguardando_teste_hidro') noTeste++;
            else if (status.contains('recarga') || status.contains('montagem') || status.contains('valvula')) naRecarga++;
          }

          // 3. Layout
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Total de Itens no Banco: ${docs.length}",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 10),

                const Text("1. Entrada", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildCard("Descarga", naDescarga, Colors.orange, Icons.fire_extinguisher),
                    _buildCard("Limpeza", naLimpeza, Colors.brown, Icons.cleaning_services),
                  ],
                ),

                const SizedBox(height: 20),
                const Text("2. Processos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildCard("Pintura", naPintura, Colors.red, Icons.format_paint),
                    _buildCard("Teste Hidro", noTeste, Colors.blue, Icons.water_drop),
                  ],
                ),

                const SizedBox(height: 20),
                const Text("3. Finalização", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildCard("Recarga/Montagem", naRecarga, Colors.green, Icons.build_circle, fullWidth: true),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(String titulo, int quantidade, Color cor, IconData icone, {bool fullWidth = false}) {
    final double width = fullWidth ? double.infinity : 160;

    return Container(
      width: width,
      constraints: const BoxConstraints(minWidth: 150),
      height: 110,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: cor, width: 5)),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icone, color: cor, size: 28),
              Text("$quantidade", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cor)),
            ],
          ),
          Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}