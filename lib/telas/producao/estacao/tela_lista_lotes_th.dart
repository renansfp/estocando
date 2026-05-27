// lib/telas/producao/estacao/tela_lista_lotes_th.dart

import 'package:flutter/material.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_base.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_th.dart';

class TelaListaLotesTH extends StatelessWidget {
  const TelaListaLotesTH({super.key});

  @override
  Widget build(BuildContext context) {
    return TelaListaLotesBase(
      titulo: 'Fila: Teste Hidrostático',
      corSetor: Colors.purple.shade700,
      statusAguardando: 'aguardando_th',
      mensagemVazia: 'Nenhum extintor pendente de TH.',
      streamFonte: (repo, empresaId) => repo.streamItensEmProducao(empresaId),
      contadorJaPassaram: (itens) => itens.where((doc) {
        final st = doc['status']?.toString() ?? '';
        return st != 'aguardando_limpeza' &&
            st != 'em_limpeza' &&
            st != 'aguardando_lixa';
      }).length,
      // Nota: TelaEstacaoTH usa o parâmetro 'osIdAtual' em vez de 'osId'
      construtorTela: (osId) => TelaEstacaoTH(osIdAtual: osId),
      // ── Novos recursos ──────────────────────────────────────────
      mostrarNomeCliente: true,
      mostrarBotaoRequisicao: true,
      nomeSetorCC: 'TESTE HIDROSTÁTICO EXTINTORES', // → CC 4231
      mostrarBotaoReverter: true,
      statusParaReverter: 'aguardando_th',
      statusAnteriorReverter: 'aguardando_lixa',
      etapaAnteriorOS: 'lixa',
      statusLoteAnteriorOS: 'em_lixa',
      mensagemReverter:
      'Deseja devolver este lote inteiro para a etapa de LIXA?',
    );
  }
}