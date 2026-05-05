// lib/telas/producao/estacao/tela_lista_lotes_recarga.dart
//
// Recarga filtra por tipo de agente (Pó ABC, CO2, Água...).
// A OS só aparece se houver itens com status que contenha 'recarga'.
//
// O parâmetro filtrosAgente é mantido igual ao original para não quebrar
// as telas que já instanciam esta classe.

import 'package:flutter/material.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_base.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_recarga.dart';

class TelaListaLotesRecarga extends StatelessWidget {
  final String titulo;
  final List<String> filtrosAgente;

  const TelaListaLotesRecarga({
    super.key,
    required this.titulo,
    required this.filtrosAgente,
  });

  @override
  Widget build(BuildContext context) {
    return TelaListaLotesBase(
      titulo: titulo,
      corSetor: Colors.green.shade700,
      iconeAvatar: Icons.gas_meter,
      statusAguardando: 'aguardando_recarga', // referência; filtroOS sobrescreve
      mensagemVazia: 'Nenhum lote para este setor.',
      textoSubtitulo: (passaram, total) =>
          'Prontos para Recarga: $passaram de $total',
      streamFonte: (repo) => repo.streamItensEmProducao(),
      // Filtra apenas itens do agente correto
      filtroItem: (doc) {
        final agente = doc['tipoAgente']?.toString().toUpperCase() ?? '';
        return filtrosAgente.any((f) => agente.contains(f.toUpperCase()));
      },
      // OS aparece apenas se tiver itens prontos (status contém 'recarga')
      filtroOS: (itens) => itens.any((doc) {
        final st = doc['status']?.toString().toLowerCase() ?? '';
        return st.contains('recarga');
      }),
      contadorJaPassaram: (itens) => itens.where((doc) {
        final st = doc['status']?.toString().toLowerCase() ?? '';
        return st.contains('recarga');
      }).length,
      construtorTela: (osId) => TelaEstacaoRecarga(
        osId: osId,
        filtrosAgente: filtrosAgente,
      ),
    );
  }
}
