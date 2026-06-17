// lib/repositories/item_os_repository.dart

abstract class ItemOsRepository {
  /// Lê o documento `contadores/{empresaId}` mantido pela Cloud Function.
  Stream<Map<String, int>> streamDocumentoContadores(String empresaId);

  /// [empresaId] é obrigatório — isola dados da empresa. Nunca chamar sem ele.
  /// Usa collectionGroup('itens') para varrer todas as OSs.
  Stream<List<Map<String, dynamic>>> streamItensEmProducao(String empresaId);
  Stream<List<Map<String, dynamic>>> streamItensPorOsEStatus(
      String osId, String status, String empresaId);
  Stream<List<Map<String, dynamic>>> streamItensAguardandoDescarga(
      String empresaId, List<String> filtrosAgente);
  Future<Map<String, dynamic>?> buscarItemPorCracha(
      String osId, String cracha, String status, String empresaId);
  Future<void> confirmarEtapa({
    required String itemId,
    required Map<String, dynamic> dadosItem,
    required String osId,
    required String statusPendente,
    required String proximaEstacao,
    required String empresaId,
    Map<String, dynamic>? dadosOsExtra,
  });
  Future<void> reverterLote({
    required String osId,
    required String empresaId,
    required String statusAtual,
    required String statusAnterior,
    required Map<String, dynamic> dadosOS,
    String Function(Map<String, dynamic>)? statusAnteriorFn,
  });
  Future<void> liberarLotePremontagem({
    required String osId,
    required List<Map<String, dynamic>> itens,
    required String operador,
    required String empresaId,
  });
  Future<void> criarPrintJob({
    required List<String> itensIds,
    required String osId,
    required bool imprimirGarantia,
    required bool imprimirNR23,
    required String impressora,
  });
  Future<void> salvarManutencaoValvula({
    required String itemId,
    required String osId,
    required String equipamentoId,
    required String operador,
    required String pesoVazio,
    required String pesoCheioMeta,
    required String proximaEstacao,
    required String statusAtualItem,
    required String empresaId,
  });
  Stream<List<Map<String, dynamic>>> streamItensPorOs(String osId);
  Future<void> expedirItem({
    required String itemId,
    required String osId,
    required String idCracha,
    required String? equipId,
    required String empresaId,
  });
  Future<void> reprovarItem({
    required String itemId,
    required String osId,
    required String statusAtual,
    required String statusDestino,
    required Map<String, dynamic> dadosFalha,
    required String empresaId,
  });
  Future<Map<String, dynamic>?> buscarItemPorCrachaEOsId(
      String osId, String cracha, String empresaId);
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
    required String empresaId,
    required String statusAtualItem,
  });

  Future<void> registrarPecasTrocadas({
    required String itemId,
    required String osId,
    required String empresaId,
    required Map<int, String> pecas,
  });

  Future<void> condenarItem({
    required String itemId,
    required Map<String, dynamic> item,
    required String etapa,
    required String motivo,
    required String empresaId,
  });
  Future<void> confirmarTriagem({
    required String itemId,
    required String osId,
    required List<String> roteiro,
    required String proximoStatus,
    required String proximaEstacao,
    required bool precisaPintura,
    required bool testeVencido,
    required String operador,
    required String empresaId,
  });

  /// [osId] obrigatório — localiza o item na subcoleção correta.
  Future<void> finalizarEnsaioTH({
    required String itemId,
    required String osId,
    required String? equipamentoId,
    required bool aprovado,
    required String proximaEtapa,
    required Map<String, dynamic> dadosTH,
    Map<String, dynamic>? updatesEquipamento,
    required String empresaId,
  });

  Stream<List<Map<String, dynamic>>> streamItensDescarga(String empresaId);
  Future<void> liberarLoteParaLimpeza({
    required String osId,
    required List<String> itemIds,
    required String empresaId,
  });
  Future<void> reverterParaDescarga(String osId, String empresaId);

  /// [osId] obrigatório — localiza o item na subcoleção correta.
  Future<void> confirmarDescargaItem(
      String itemOsId, String osId, String operador);

  Future<void> confirmarDescargaPorCracha(
      String osId, String idCracha, String operador, String empresaId);

  Stream<List<Map<String, dynamic>>> streamItensDescargaOsPorAgente(
      String osId, List<String> filtrosAgente);

  Future<List<Map<String, dynamic>>> buscarItensComDadosCompletos(String osId);

  Future<bool> verificarCrachaEmUso(String idCracha, String empresaId);

  Future<Map<String, dynamic>?> buscarInfoCracha(
      String idCracha, String empresaId);

  /// [osId] obrigatório — localiza o item na subcoleção correta.
  Future<Map<String, dynamic>?> buscarItemPorId(String itemId, String osId);
}