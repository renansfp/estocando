// lib/telas/producao/estacao/tela_selecao_recarga.dart
//
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  POR QUE ESTA TELA EXISTE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  Antes, a home screen sabia detalhes internos de cada tipo de
//  Recarga: qual CC usar, para onde reverter, quais filtros aplicar.
//  Isso era um problema porque a home screen tinha "obrigações" que
//  não eram dela.
//
//  Agora a home screen só diz: "vai para Recarga".
//  Esta tela cuida do resto — ela é quem conhece os tipos, os CCs
//  e os parâmetros de reversão de cada agente.
//
//  Os contadores por tipo (recargaABC, recargaBC...) vêm do
//  ItemOsProvider, que já está disponível na árvore de widgets.
//  Não precisamos passar nada pela home screen.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_recarga.dart';

class TelaSelecaoRecarga extends StatelessWidget {
  const TelaSelecaoRecarga({super.key});

  // ── Definição centralizada dos tipos de recarga ───────────────
  //
  // Tudo que a home screen sabia espalhado em callbacks está aqui,
  // num único lugar, organizado e fácil de manter.

  static const _tipos = [
    _TipoRecarga(
      titulo: 'Pó Químico — ABC',
      subtitulo: 'Agentes ABC e PQS',
      icone: Icons.ac_unit,
      cor: Color(0xFF6D4C41),
      chaveContador: 'recargaABC',
      filtrosAgente: ['ABC', 'PQS'],
      statusRecarga: 'aguardando_recarga_abc',
      nomeSetorCC: 'RECARGA E TESTES EQUIPAMENTOS PQS',
      statusAnteriorReverter: 'aguardando_manutencao_valvula_po',
      etapaAnteriorOS: 'manutencao_valvula_po',
      statusLoteAnteriorOS: 'em_manutencao_valvula_po',
      mensagemReverter: 'Deseja devolver este lote para VÁLVULA PÓ QUÍMICO?',
    ),
    _TipoRecarga(
      titulo: 'Pó Químico — BC',
      subtitulo: 'Agentes BC e PQS',
      icone: Icons.ac_unit,
      cor: Color(0xFF757575),
      chaveContador: 'recargaBC',
      filtrosAgente: ['BC', 'PQS'],
      statusRecarga: 'aguardando_recarga_bc',
      nomeSetorCC: 'RECARGA E TESTES EQUIPAMENTOS PQS',
      statusAnteriorReverter: 'aguardando_manutencao_valvula_po',
      etapaAnteriorOS: 'manutencao_valvula_po',
      statusLoteAnteriorOS: 'em_manutencao_valvula_po',
      mensagemReverter: 'Deseja devolver este lote para VÁLVULA PÓ QUÍMICO?',
    ),
    _TipoRecarga(
      titulo: 'Água / Espuma',
      subtitulo: 'Agentes AP, ESP e ÁGUA',
      icone: Icons.water_drop,
      cor: Color(0xFF1976D2),
      chaveContador: 'recargaAgua',
      filtrosAgente: ['AP', 'ESP', 'AGUA'],
      statusRecarga: 'aguardando_recarga_agua_espuma',
      nomeSetorCC: 'RECARGA E TESTES EQUIPAMENTOS AP',
      statusAnteriorReverter: 'aguardando_th',
      etapaAnteriorOS: 'th',
      statusLoteAnteriorOS: 'em_th',
      mensagemReverter: 'Deseja devolver este lote para TESTE HIDROSTÁTICO?',
    ),
    _TipoRecarga(
      titulo: 'CO2',
      subtitulo: 'Dióxido de carbono',
      icone: Icons.air,
      cor: Color(0xFF212121),
      chaveContador: 'recargaCO2',
      filtrosAgente: ['CO2'],
      statusRecarga: 'aguardando_recarga_co2',
      nomeSetorCC: 'RECARGA E TESTES EQUIPAMENTOS CO2',
      statusAnteriorReverter: 'aguardando_manutencao_valvula',
      etapaAnteriorOS: 'manutencao_valvula',
      statusLoteAnteriorOS: 'em_manutencao_valvula',
      mensagemReverter:
      'Deseja devolver este lote para MANUTENÇÃO DE COMPONENTES?',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Lê os contadores por tipo diretamente do provider — sem passar pela home
    final contadores = context.watch<ItemOsProvider>().contadores;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recarga'),
        backgroundColor: Colors.green.shade700,
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

  Widget _buildCard(BuildContext context, _TipoRecarga tipo, int count) {
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
            // Badge de contagem — só aparece quando há itens
            if (count > 0)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
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
            builder: (_) => TelaListaLotesRecarga(
              titulo: 'Recarga — ${tipo.titulo}',
              filtrosAgente: tipo.filtrosAgente,
              statusRecarga: tipo.statusRecarga,
              nomeSetorCC: tipo.nomeSetorCC,
              statusAnteriorReverter: tipo.statusAnteriorReverter,
              etapaAnteriorOS: tipo.etapaAnteriorOS,
              statusLoteAnteriorOS: tipo.statusLoteAnteriorOS,
              mensagemReverter: tipo.mensagemReverter,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Modelo de dados interno ───────────────────────────────────────
//
// Classe privada (prefixo _) — só existe dentro deste arquivo.
// Centraliza tudo que define um tipo de recarga num único objeto.

class _TipoRecarga {
  final String titulo;
  final String subtitulo;
  final IconData icone;
  final Color cor;
  final String chaveContador;
  final List<String> filtrosAgente;
  final String statusRecarga;
  final String nomeSetorCC;
  final String statusAnteriorReverter;
  final String etapaAnteriorOS;
  final String statusLoteAnteriorOS;
  final String mensagemReverter;

  const _TipoRecarga({
    required this.titulo,
    required this.subtitulo,
    required this.icone,
    required this.cor,
    required this.chaveContador,
    required this.filtrosAgente,
    required this.statusRecarga,
    required this.nomeSetorCC,
    required this.statusAnteriorReverter,
    required this.etapaAnteriorOS,
    required this.statusLoteAnteriorOS,
    required this.mensagemReverter,
  });
}