// lib/provider/item_os_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:protecin_producao/repositories/item_os_repository.dart';

class ItemOsProvider with ChangeNotifier {
  final ItemOsRepository _repository;

  ItemOsProvider(this._repository);

  Map<String, int> _contadores = {};
  StreamSubscription<Map<String, int>>? _subscription;

  Map<String, int> get contadores => _contadores;

  void iniciarEscuta(String empresaId) {
    _subscription?.cancel();
    _subscription = _repository
        .streamDocumentoContadores(empresaId)
        .listen(
          (mapa) {
        _contadores = mapa;
        notifyListeners();
      },
      onError: (e) => debugPrint('ItemOsProvider erro: $e'),
    );
  }

  Future<void> liberarLotePremontagem({
    required String osId,
    required List<Map<String, dynamic>> itens,
    required String operador,
  }) =>
      _repository.liberarLotePremontagem(
          osId: osId, itens: itens, operador: operador);

  Future<void> criarPrintJob({
    required List<String> itensIds,
    required String osId,
    required bool imprimirGarantia,
    required bool imprimirNR23,
    required String impressora,
  }) =>
      _repository.criarPrintJob(
        itensIds: itensIds,
        osId: osId,
        imprimirGarantia: imprimirGarantia,
        imprimirNR23: imprimirNR23,
        impressora: impressora,
      );

  Future<void> salvarManutencaoValvula({
    required String itemId,
    required String osId,
    required String equipamentoId,
    required String operador,
    required String pesoVazio,
    required String pesoCheioMeta,
    required String proximaEstacao,
  }) =>
      _repository.salvarManutencaoValvula(
        itemId: itemId,
        osId: osId,
        equipamentoId: equipamentoId,
        operador: operador,
        pesoVazio: pesoVazio,
        pesoCheioMeta: pesoCheioMeta,
        proximaEstacao: proximaEstacao,
      );

  Stream<List<Map<String, dynamic>>> streamItensPorOs(String osId) =>
      _repository.streamItensPorOs(osId);

  Future<void> expedirItem({
    required String itemId,
    required String osId,
    required String idCracha,
    required String? equipId,
  }) =>
      _repository.expedirItem(
          itemId: itemId, osId: osId, idCracha: idCracha, equipId: equipId);

  Future<void> reprovarItem({
    required String itemId,
    required String statusDestino,
    required Map<String, dynamic> dadosFalha,
  }) =>
      _repository.reprovarItem(
          itemId: itemId,
          statusDestino: statusDestino,
          dadosFalha: dadosFalha);

  Stream<List<Map<String, dynamic>>> streamItensAguardandoDescarga(
      String empresaId, List<String> filtrosAgente) =>
      _repository.streamItensAguardandoDescarga(empresaId, filtrosAgente);

  Stream<List<Map<String, dynamic>>> streamItensPorOsEStatus(
      String osId, String status, String empresaId) =>
      _repository.streamItensPorOsEStatus(osId, status,empresaId);

  Future<Map<String, dynamic>?> buscarItemPorCracha(
      String osId, String cracha, String status, String empresaId) =>
      _repository.buscarItemPorCracha(osId, cracha, status,empresaId);

  Future<Map<String, dynamic>?> buscarItemPorCrachaEOsId(
      String osId, String cracha, String empresaId) =>
      _repository.buscarItemPorCrachaEOsId(osId, cracha, empresaId);


  Future<void> processarRecarga({
    required String itemId,
    required String osId,
    required String equipamentoId,
    required String idCrachaTemporario,
    required bool substituirPo,
    required bool isPo,
    required double pesoCarga,
    required double pesoFinalRegistrado,
    required String agente,
    required String loteFinal,
    required String tipoRegistro,
    required String? loteSelecionadoId,
    required String? produtoId,
    required String? clienteNome,
    required String cc,
    required String operador,
  }) =>
      _repository.processarRecarga(
        itemId: itemId,
        osId: osId,
        equipamentoId: equipamentoId,
        idCrachaTemporario: idCrachaTemporario,
        substituirPo: substituirPo,
        isPo: isPo,
        pesoCarga: pesoCarga,
        pesoFinalRegistrado: pesoFinalRegistrado,
        agente: agente,
        loteFinal: loteFinal,
        tipoRegistro: tipoRegistro,
        loteSelecionadoId: loteSelecionadoId,
        produtoId: produtoId,
        clienteNome: clienteNome,
        cc: cc,
        operador: operador,
      );

  Future<void> confirmarEtapa({
    required String itemId,
    required Map<String, dynamic> dadosItem,
    required String osId,
    required String statusPendente,
    required String proximaEstacao,
    Map<String, dynamic>? dadosOsExtra,
  }) =>
      _repository.confirmarEtapa(
        itemId: itemId,
        dadosItem: dadosItem,
        osId: osId,
        statusPendente: statusPendente,
        proximaEstacao: proximaEstacao,
        dadosOsExtra: dadosOsExtra,
      );

  // ─── Novo método ─────────────────────────────────────────────────────────

  /// Condena um item em batch atômico (atualiza item + baixa equipamento).
  Future<void> condenarItem({
    required String itemId,
    required Map<String, dynamic> item,
    required String etapa,
    required String motivo,
  }) =>
      _repository.condenarItem(
        itemId: itemId,
        item: item,
        etapa: etapa,
        motivo: motivo,
      );

  Future<void> confirmarTriagem({
    required String itemId,
    required String osId,
    required List<String> roteiro,
    required String proximoStatus,
    required String proximaEstacao,
    required bool precisaPintura,
    required bool testeVencido,
    required String operador,
  }) =>
      _repository.confirmarTriagem(
        itemId: itemId,
        osId: osId,
        roteiro: roteiro,
        proximoStatus: proximoStatus,
        proximaEstacao: proximaEstacao,
        precisaPintura: precisaPintura,
        testeVencido: testeVencido,
        operador: operador,
      );

  /// Finaliza o ensaio hidrostático, atualizando item e equipamento.
  Future<void> finalizarEnsaioTH({
    required String itemId,
    required String? equipamentoId,
    required bool aprovado,
    required String proximaEtapa,
    required Map<String, dynamic> dadosTH,
    Map<String, dynamic>? updatesEquipamento,
  }) =>
      _repository.finalizarEnsaioTH(
        itemId: itemId,
        equipamentoId: equipamentoId,
        aprovado: aprovado,
        proximaEtapa: proximaEtapa,
        dadosTH: dadosTH,
        updatesEquipamento: updatesEquipamento,
      );

  /// Stream de itens na descarga (aguardando_descarga ou descarga_concluida).
  Stream<List<Map<String, dynamic>>> streamItensDescarga(String empresaId) =>
      _repository.streamItensDescarga(empresaId);

  /// Libera um lote para a limpeza (atualiza itens + OS mãe).
  Future<void> liberarLoteParaLimpeza({
    required String osId,
    required List<String> itemIds,
  }) =>
      _repository.liberarLoteParaLimpeza(osId: osId, itemIds: itemIds);

  /// Reverte itens da limpeza de volta para a descarga (admin).
  Future<void> reverterParaDescarga(String osId) =>
      _repository.reverterParaDescarga(osId);

  /// Marca um item como descarga concluída.
  Future<void> confirmarDescargaItem(String itemOsId, String operador) =>
      _repository.confirmarDescargaItem(itemOsId, operador);

  /// Confirma a descarga de um item pelo crachá, avançando a OS se necessário.
  Future<void> confirmarDescargaPorCracha(
      String osId, String idCracha, String operador) =>
      _repository.confirmarDescargaPorCracha(osId, idCracha, operador);

  /// Stream de itens aguardando descarga em uma OS, filtrado por agente.
  Stream<List<Map<String, dynamic>>> streamItensDescargaOsPorAgente(
      String osId, List<String> filtrosAgente) =>
      _repository.streamItensDescargaOsPorAgente(osId, filtrosAgente);

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }


  Future<List<Map<String, dynamic>>> buscarItensComDadosCompletos(String osId) =>
      _repository.buscarItensComDadosCompletos(osId);


  Future<bool> verificarCrachaEmUso(String idCracha, String empresaId) =>
      _repository.verificarCrachaEmUso(idCracha, empresaId);

  Future<Map<String, dynamic>?> buscarInfoCracha(
      String idCracha, String empresaId) =>
      _repository.buscarInfoCracha(idCracha, empresaId);

  Future<Map<String, dynamic>?> buscarItemPorId(String itemId) =>
      _repository.buscarItemPorId(itemId);

  Future<void> registrarPecasTrocadas({
    required String itemId,
    required String osId,
    required String empresaId,
    required Map<int, String> pecas,
  }) async {
    await _repository.registrarPecasTrocadas(
      itemId    : itemId,
      osId      : osId,
      empresaId : empresaId,
      pecas     : pecas,
    );
  }
}