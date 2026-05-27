// lib/telas/producao/estacao/tela_lista_lotes_limpeza.dart
//
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  Antes: 179 linhas com toda a lógica própria (StatefulWidget).
//  Agora: ~35 linhas — alinhada com todas as outras telas de lotes.
//
//  O que mudou:
//  - Usa TelaListaLotesBase como todas as outras 11 telas
//  - A busca por clienteNome é feita pela Base (mostrarNomeCliente)
//  - O botão 🛒 e o reverter por long press também vêm da Base
//  - Removido o import de OrdemServicoRepository (Base cuida disso)
//  - Removido o import de MapeadorCustos (Base cuida disso)
//  - Lógica de _reverterParaDescarga eliminada (Base cuida disso)
//  - StatefulWidget → StatelessWidget
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_base.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_limpeza.dart';

class TelaListaLotesLimpeza extends StatelessWidget {
  const TelaListaLotesLimpeza({super.key});

  @override
  Widget build(BuildContext context) {
    return TelaListaLotesBase(
      titulo: 'Fila de Limpeza',
      corSetor: const Color(0xFF1565C0),
      mostrarBotaoHome: true,
      statusAguardando: 'aguardando_limpeza',
      mensagemVazia: 'Nenhuma OS na fila.',
      streamFonte: (repo, empresaId) => repo.streamItensEmProducao(empresaId),
      contadorJaPassaram: (itens) => itens.where((doc) {
        final st = doc['status']?.toString() ?? '';
        return st != 'aguardando_limpeza' && st != 'em_limpeza';
      }).length,
      construtorTela: (osId) => TelaEstacaoLimpeza(osId: osId),
      // ── Novos recursos ──────────────────────────────────────────
      mostrarNomeCliente: true,
      mostrarBotaoRequisicao: true,
      nomeSetorCC: 'DESCARGA E PREPARAÇÃO', // → CC 4221 (setor de entrada)
      mostrarBotaoReverter: true,
      statusParaReverter: 'aguardando_limpeza',
      statusAnteriorReverter: 'aguardando_descarga',
      etapaAnteriorOS: 'descarga',
      statusLoteAnteriorOS: 'em_descarga',
      mensagemReverter:
      'Deseja devolver este lote inteiro para a etapa de DESCARGA?',
    );
  }
}