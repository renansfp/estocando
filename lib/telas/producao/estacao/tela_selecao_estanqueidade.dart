// lib/telas/producao/estacao/tela_selecao_estanqueidade.dart
//
// Mesmo princípio da TelaSelecaoRecarga: a home screen não precisa
// saber nada sobre os tipos de estanqueidade. Esta tela cuida disso.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_estanqueidade.dart';

class TelaSelecaoEstanqueidade extends StatelessWidget {
  const TelaSelecaoEstanqueidade({super.key});

  static const _tipos = [
    _TipoEstanqueidade(
      titulo: 'Pó Químico — ABC',
      subtitulo: 'Agentes ABC e PQS',
      icone: Icons.bubble_chart,
      cor: Color(0xFF6D4C41),
      chaveContador: 'estanqueABC',
      filtrosAgente: ['ABC', 'PQS'],
      nomeSetorCC: 'RECARGA E TESTES EQUIPAMENTOS PQS', // → CC 4235
    ),
    _TipoEstanqueidade(
      titulo: 'Pó Químico — BC',
      subtitulo: 'Agentes BC e PQS',
      icone: Icons.bubble_chart,
      cor: Color(0xFF757575),
      chaveContador: 'estanqueBC',
      filtrosAgente: ['BC', 'PQS'],
      nomeSetorCC: 'RECARGA E TESTES EQUIPAMENTOS PQS', // → CC 4235
    ),
    _TipoEstanqueidade(
      titulo: 'Água / Espuma',
      subtitulo: 'Agentes AP, ESP e ÁGUA',
      icone: Icons.water_drop,
      cor: Color(0xFF1976D2),
      chaveContador: 'estanqueAgua',
      filtrosAgente: ['AP', 'ESP', 'AGUA'],
      nomeSetorCC: 'RECARGA E TESTES EQUIPAMENTOS AP', // → CC 4234
    ),
    _TipoEstanqueidade(
      titulo: 'CO2',
      subtitulo: 'Dióxido de carbono',
      icone: Icons.air,
      cor: Color(0xFF212121),
      chaveContador: 'estanqueCO2',
      filtrosAgente: ['CO2'],
      nomeSetorCC: 'RECARGA E TESTES EQUIPAMENTOS CO2', // → CC 4233
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final contadores = context.watch<ItemOsProvider>().contadores;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estanqueidade'),
        backgroundColor: Colors.lightBlue.shade800,
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

  Widget _buildCard(BuildContext context, _TipoEstanqueidade tipo, int count) {
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
                  color: Colors.lightBlue.shade800,
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
            builder: (_) => TelaListaLotesEstanqueidade(
              titulo: tipo.titulo,
              filtrosAgente: tipo.filtrosAgente,
              nomeSetorCC: tipo.nomeSetorCC,
            ),
          ),
        ),
      ),
    );
  }
}

class _TipoEstanqueidade {
  final String titulo;
  final String subtitulo;
  final IconData icone;
  final Color cor;
  final String chaveContador;
  final List<String> filtrosAgente;
  final String nomeSetorCC;

  const _TipoEstanqueidade({
    required this.titulo,
    required this.subtitulo,
    required this.icone,
    required this.cor,
    required this.chaveContador,
    required this.filtrosAgente,
    required this.nomeSetorCC,
  });
}