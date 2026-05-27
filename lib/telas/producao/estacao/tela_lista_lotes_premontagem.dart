// lib/telas/producao/estacao/tela_lista_lotes_premontagem.dart
//
// Pré-Montagem usa lógica diferente: o status não é uma string fixa,
// é qualquer status que contenha a palavra 'premontagem'.
// Por isso, tanto o filtro de OS quanto o contador são customizados.

import 'package:flutter/material.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_base.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_premontagem.dart';

class TelaListaLotesPremontagem extends StatelessWidget {
  const TelaListaLotesPremontagem({super.key});

  // Verifica se o status "pertence" à pré-montagem
  static bool _estaEmPremontagem(Map<String, dynamic> doc) {
    final st = doc['status']?.toString().toLowerCase().replaceAll('_', '') ?? '';
    return st.contains('premontagem');
  }

  @override
  Widget build(BuildContext context) {
    return TelaListaLotesBase(
      titulo: 'Fila: Pré-Montagem',
      corSetor: Colors.indigo.shade700,
      iconeAvatar: Icons.pending_actions,
      statusAguardando: 'aguardando_premontagem', // referência, substituído pelo filtroOS
      filtroOS: (itens) => itens.any(_estaEmPremontagem),
      mensagemVazia: 'Nenhum lote pendente para montagem.',
      textoSubtitulo: (passaram, total) => passaram == total
          ? 'LOTE COMPLETO — PRONTO PARA MONTAR'
          : 'Aguardando itens da estanqueidade ($passaram/$total)',
      streamFonte: (repo, empresaId) => repo.streamItensEmProducao(empresaId),
      contadorJaPassaram: (itens) => itens.where(_estaEmPremontagem).length,
      construtorTela: (osId) => TelaEstacaoPremontagem(osId: osId),
      // ── Novos recursos ──────────────────────────────────────────
      mostrarNomeCliente: true,
      mostrarBotaoRequisicao: true,
      nomeSetorCC: '', // sem CC direto — usuário preenche manualmente se precisar
      mostrarBotaoReverter: true,
      statusParaReverter: 'aguardando_premontagem',
      statusAnteriorReverter: 'aguardando_estanqueidade',
      etapaAnteriorOS: 'estanqueidade',
      statusLoteAnteriorOS: 'em_estanqueidade',
      mensagemReverter:
      'Deseja devolver este lote inteiro para a etapa de ESTANQUEIDADE?',
    );
  }
}