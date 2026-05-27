// lib/telas/producao/estacao/tela_lista_lotes_recarga.dart
//
// Recarga filtra por tipo de agente (Pó ABC, CO2, Água...).
// A OS só aparece se houver itens com status que contenha 'recarga'.
//
// nomeSetorCC é opcional: permite que a home screen informe o CC
// correto para cada tipo de recarga (CO2, PQS, AP).
// Se não informado, o campo de CC na requisição fica em branco.

import 'package:flutter/material.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_base.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_recarga.dart';

class TelaListaLotesRecarga extends StatelessWidget {
  final String titulo;
  final List<String> filtrosAgente;

  /// Status exato salvo no banco para este tipo de recarga.
  /// Deve bater com o valor do roteiro gerado na triagem de limpeza.
  final String statusRecarga;

  /// Centro de custo do setor de recarga.
  /// Ex: 'RECARGA E TESTES EQUIPAMENTOS CO2' (→ 4233)
  ///     'RECARGA E TESTES EQUIPAMENTOS PQS' (→ 4235)
  ///     'RECARGA E TESTES EQUIPAMENTOS AP'  (→ 4234)
  final String nomeSetorCC;

  /// Status anterior para reversão.
  /// CO2 e Pó geralmente vêm de 'aguardando_manutencao_valvula' ou
  /// 'aguardando_manutencao_valvula_po'; Água/Espuma vêm de 'aguardando_th'.
  /// Se não informado, o botão de reverter não aparece.
  final String statusAnteriorReverter;
  final String etapaAnteriorOS;
  final String statusLoteAnteriorOS;
  final String mensagemReverter;

  const TelaListaLotesRecarga({
    super.key,
    required this.titulo,
    required this.filtrosAgente,
    required this.statusRecarga,
    this.nomeSetorCC = '',
    this.statusAnteriorReverter = '',
    this.etapaAnteriorOS = '',
    this.statusLoteAnteriorOS = '',
    this.mensagemReverter =
    'Deseja devolver este lote inteiro para a etapa anterior?',
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
      streamFonte: (repo, empresaId) => repo.streamItensEmProducao(empresaId),
      filtroItem: (doc) {
        final agente = doc['tipoAgente']?.toString().toUpperCase() ?? '';
        return filtrosAgente.any((f) => agente.contains(f.toUpperCase()));
      },
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
        statusRecarga: statusRecarga,
      ),
      // ── Novos recursos ──────────────────────────────────────────
      mostrarNomeCliente: true,
      mostrarBotaoRequisicao: true,
      nomeSetorCC: nomeSetorCC,
      // Só habilita o reverter se o caller informou para onde voltar
      mostrarBotaoReverter: statusAnteriorReverter.isNotEmpty,
      statusParaReverter: statusRecarga,
      statusAnteriorReverter: statusAnteriorReverter,
      etapaAnteriorOS: etapaAnteriorOS,
      statusLoteAnteriorOS: statusLoteAnteriorOS,
      mensagemReverter: mensagemReverter,
    );
  }
}