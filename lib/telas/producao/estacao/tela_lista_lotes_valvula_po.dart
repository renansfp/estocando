// lib/telas/producao/estacao/tela_lista_lotes_valvula_po.dart
//
// Diferença em relação ao padrão: o círculo avatar mostra quantos
// itens AINDA FALTAM (pendentes), não quantos já passaram.

import 'package:flutter/material.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_base.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_valvula_po.dart';

class TelaListaLotesValvulaPo extends StatelessWidget {
  const TelaListaLotesValvulaPo({super.key});

  @override
  Widget build(BuildContext context) {
    return TelaListaLotesBase(
      titulo: 'Fila: Válvula Pó Químico',
      corSetor: Colors.deepOrange.shade700,
      mostrarBotaoHome: true,
      statusAguardando: 'aguardando_manutencao_valvula_po',
      mensagemVazia: 'Nenhum extintor de pó aguardando válvula.',
      streamFonte: (repo) => repo.streamItensPorRoteiro('manutencao_valvula_po'),
      contadorJaPassaram: (itens) => itens.where((doc) {
        final st = doc['status']?.toString() ?? '';
        return st != 'aguardando_manutencao_valvula_po';
      }).length,
      // Mostra quantos FALTAM no avatar (total - passaram)
      textoAvatar: (passaram, total) => '${total - passaram}',
      textoSubtitulo: (passaram, total) =>
          '${total - passaram} de $total itens aguardando válvula',
      construtorTela: (osId) => TelaEstacaoValvulaPo(osId: osId),
    );
  }
}
