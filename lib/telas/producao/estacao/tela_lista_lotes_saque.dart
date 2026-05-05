// lib/telas/producao/estacao/tela_lista_lotes_saque.dart

import 'package:flutter/material.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_base.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_saque.dart';

class TelaListaLotesSaque extends StatelessWidget {
  const TelaListaLotesSaque({super.key});

  @override
  Widget build(BuildContext context) {
    return TelaListaLotesBase(
      titulo: 'Fila: Saque de Válvula',
      corSetor: Colors.red.shade700,
      mostrarBotaoHome: true,
      statusAguardando: 'aguardando_saque_valvula',
      mensagemVazia: 'Nenhum item pendente de saque de válvula.',
      textoSubtitulo: (passaram, total) => passaram == total
          ? 'Lote completo para saque'
          : 'Aguardando itens do lote...',
      streamFonte: (repo) => repo.streamItensPorRoteiro('saque_valvula'),
      contadorJaPassaram: (itens) => itens.where((doc) {
        final st = doc['status']?.toString() ?? '';
        return st != 'aguardando_limpeza' &&
            st != 'em_limpeza' &&
            st != 'aguardando_lixa' &&
            st != 'aguardando_manutencao_valvula';
      }).length,
      // Nota: TelaEstacaoSaque usa 'numeroLote' em vez de 'osId'
      construtorTela: (osId) => TelaEstacaoSaque(numeroLote: osId),
    );
  }
}
