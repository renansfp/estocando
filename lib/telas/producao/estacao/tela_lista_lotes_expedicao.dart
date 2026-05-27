// lib/telas/producao/estacao/tela_lista_lotes_expedicao.dart
//
// Expedição tem dois destaques:
//   1. O avatar mostra um ícone de caminhão em vez de contador
//   2. O subtítulo mostra "X de Y cilindros carregados"

import 'package:flutter/material.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_base.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_expedicao.dart';

class TelaListaLotesExpedicao extends StatelessWidget {
  const TelaListaLotesExpedicao({super.key});

  @override
  Widget build(BuildContext context) {
    return TelaListaLotesBase(
      titulo: 'Fila: Expedição e Carregamento',
      corSetor: Colors.black87,
      iconeAvatar: Icons.local_shipping,
      statusAguardando: 'aguardando_expedicao',
      mensagemVazia: 'Nenhum lote pronto para carregar.',
      textoSubtitulo: (passaram, total) => '$passaram de $total cilindros carregados',
      streamFonte: (repo, empresaId) => repo.streamItensEmProducao(empresaId),
      contadorJaPassaram: (itens) => itens.where((doc) {
        final st = doc['status']?.toString() ?? '';
        return st == 'finalizado' || st == 'entregue';
      }).length,
      construtorTela: (osId) => TelaEstacaoExpedicao(osId: osId),
      // ── Novos recursos ──────────────────────────────────────────
      mostrarNomeCliente: true,
      mostrarBotaoRequisicao: true,
      nomeSetorCC: '', // Expedição não tem CC de produção — usuário preenche se precisar
      mostrarBotaoReverter: true,
      statusParaReverter: 'aguardando_expedicao',
      statusAnteriorReverter: 'aguardando_montagem',
      etapaAnteriorOS: 'montagem',
      statusLoteAnteriorOS: 'em_montagem',
      mensagemReverter:
      'Deseja devolver este lote inteiro para a etapa de MONTAGEM?',
    );
  }
}