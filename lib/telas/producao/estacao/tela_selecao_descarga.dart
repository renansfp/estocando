// lib/telas/producao/estacao/tela_selecao_descarga.dart
//
// Mesmo princípio das telas TelaSelecaoRecarga e TelaSelecaoEstanqueidade:
// a home screen não sabe nada sobre os tipos de descarga.
// Esta tela cuida da seleção por agente e navega diretamente para
// TelaEstacaoDescarga com os parâmetros corretos.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_descarga.dart';

class TelaSelecaoDescarga extends StatelessWidget {
  const TelaSelecaoDescarga({super.key});

  static const _tipos = [
    _TipoDescarga(
      titulo: 'Pó Químico — ABC',
      subtitulo: 'Agentes ABC e PQS',
      icone: Icons.ac_unit,
      cor: Color(0xFF6D4C41), // brown 700
      chaveContador: 'descargaABC',
      tituloEstacao: 'Descarga PQS ABC',
      filtrosAgente: ['ABC', 'PQS', 'PO'],
    ),
    _TipoDescarga(
      titulo: 'Pó Químico — BC',
      subtitulo: 'Agentes BC e PQS',
      icone: Icons.ac_unit,
      cor: Color(0xFF757575), // grey 600
      chaveContador: 'descargaBC',
      tituloEstacao: 'Descarga PQS BC',
      filtrosAgente: ['BC', 'PQS', 'PO'],
    ),
    _TipoDescarga(
      titulo: 'Água / Espuma',
      subtitulo: 'Agentes AP, ESP e ÁGUA',
      icone: Icons.water_drop,
      cor: Color(0xFF1976D2), // blue 700
      chaveContador: 'descargaAgua',
      tituloEstacao: 'Descarga Água/Espuma',
      filtrosAgente: ['AP', 'ESP', 'AGUA'],
    ),
    _TipoDescarga(
      titulo: 'CO2',
      subtitulo: 'Dióxido de carbono',
      icone: Icons.air,
      cor: Color(0xFF212121), // grey 900
      chaveContador: 'descargaCO2',
      tituloEstacao: 'Descarga CO2',
      filtrosAgente: ['CO2'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final contadores = context.watch<ItemOsProvider>().contadores;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Descarga'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _tipos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final tipo = _tipos[index];
          final count = contadores[tipo.chaveContador] ?? 0;
          return _buildCard(context, tipo, count);
        },
      ),
    );
  }

  Widget _buildCard(BuildContext context, _TipoDescarga tipo, int count) {
    return Card(
      elevation: 3,
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: tipo.cor,
          child: Icon(tipo.icone, color: Colors.white),
        ),
        title: Text(
          tipo.titulo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(tipo.subtitulo),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count > 0)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TelaEstacaoDescarga(
              tituloEstacao: tipo.tituloEstacao,
              filtrosAgente: tipo.filtrosAgente,
            ),
          ),
        ),
      ),
    );
  }
}

class _TipoDescarga {
  final String titulo;
  final String subtitulo;
  final IconData icone;
  final Color cor;
  final String chaveContador;
  final String tituloEstacao;
  final List<String> filtrosAgente;

  const _TipoDescarga({
    required this.titulo,
    required this.subtitulo,
    required this.icone,
    required this.cor,
    required this.chaveContador,
    required this.tituloEstacao,
    required this.filtrosAgente,
  });
}