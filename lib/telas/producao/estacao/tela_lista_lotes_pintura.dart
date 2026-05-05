// lib/telas/producao/estacao/tela_lista_lotes_pintura.dart

import 'package:flutter/material.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_base.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_pintura.dart';

class TelaListaLotesPintura extends StatelessWidget {
  const TelaListaLotesPintura({super.key});

  @override
  Widget build(BuildContext context) {
    return TelaListaLotesBase(
      titulo: 'Fila: Pintura',
      corSetor: Colors.brown.shade700,
      iconeTrailing: const Icon(Icons.format_paint, color: Colors.brown),
      statusAguardando: 'aguardando_pintura',
      mensagemVazia: 'Nenhum extintor pendente de pintura.',
      textoSubtitulo: (passaram, total) =>
          passaram == total ? 'Lote pintado!' : 'Aguardando pintura...',
      streamFonte: (repo) => repo.streamItensPorRoteiro('pintura'),
      contadorJaPassaram: (itens) => itens.where((doc) {
        final st = doc['status']?.toString() ?? '';
        return st != 'aguardando_limpeza' &&
            st != 'aguardando_lixa' &&
            st != 'aguardando_th' &&
            st != 'aguardando_manutencao_valvula';
      }).length,
      construtorTela: (osId) => TelaEstacaoPintura(osId: osId),
    );
  }
}
