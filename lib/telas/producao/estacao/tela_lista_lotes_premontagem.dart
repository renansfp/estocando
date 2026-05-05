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
      // Ícone no avatar em vez de contador (relógio = aguardando, check = pronto)
      iconeAvatar: Icons.pending_actions,
      statusAguardando: 'aguardando_premontagem', // referência, substituído pelo filtroOS
      // filtroOS customizado: mostra a OS se qualquer item tem status de premontagem
      filtroOS: (itens) => itens.any(_estaEmPremontagem),
      mensagemVazia: 'Nenhum lote pendente para montagem.',
      textoSubtitulo: (passaram, total) => passaram == total
          ? 'LOTE COMPLETO — PRONTO PARA MONTAR'
          : 'Aguardando itens da estanqueidade ($passaram/$total)',
      streamFonte: (repo) => repo.streamItensEmProducao(),
      // Conta quantos itens JÁ chegaram à pré-montagem
      contadorJaPassaram: (itens) => itens.where(_estaEmPremontagem).length,
      construtorTela: (osId) => TelaEstacaoPremontagem(osId: osId),
    );
  }
}
