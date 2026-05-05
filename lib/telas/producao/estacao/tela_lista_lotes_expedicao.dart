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
      // Avatar com caminhão em vez de contador numérico
      iconeAvatar: Icons.local_shipping,
      statusAguardando: 'aguardando_expedicao',
      mensagemVazia: 'Nenhum lote pronto para carregar.',
      textoSubtitulo: (passaram, total) => '$passaram de $total cilindros carregados',
      streamFonte: (repo) => repo.streamItensEmProducao(),
      // Conta itens já bipados na expedição ou entregues
      contadorJaPassaram: (itens) => itens.where((doc) {
        final st = doc['status']?.toString() ?? '';
        return st == 'finalizado' || st == 'entregue';
      }).length,
      construtorTela: (osId) => TelaEstacaoExpedicao(osId: osId),
    );
  }
}
