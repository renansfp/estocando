// lib/telas/producao/estacao/tela_lista_lotes_lixa.dart
//
// Antes: ~80 linhas com toda a lógica copiada.
// Agora: ~20 linhas — só o que é diferente desta estação.

import 'package:flutter/material.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_base.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_lixa.dart';

class TelaListaLotesLixa extends StatelessWidget {
  const TelaListaLotesLixa({super.key});

  @override
  Widget build(BuildContext context) {
    return TelaListaLotesBase(
      titulo: 'Fila de Lixa / Jato',
      corSetor: const Color(0xFF455A64),
      statusAguardando: 'aguardando_lixa',
      mensagemVazia: 'Nenhum item pendente de lixa.',
      streamFonte: (repo) => repo.streamItensPorRoteiro('lixa'),
      contadorJaPassaram: (itens) => itens.where((doc) {
        final st = doc['status']?.toString() ?? '';
        return st != 'aguardando_limpeza' && st != 'em_limpeza';
      }).length,
      construtorTela: (osId) => TelaEstacaoLixa(osId: osId),
    );
  }
}
