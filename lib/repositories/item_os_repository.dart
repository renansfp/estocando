// lib/repositories/item_os_repository.dart

abstract class ItemOsRepository {
  /// Lê o documento `contadores/{empresaId}` mantido pela Cloud Function.
  /// Custo fixo de 1 documento por evento — use para o dashboard e telas de seleção.
  Stream<Map<String, int>> streamDocumentoContadores(String empresaId);

  /// [empresaId] é obrigatório — isola dados da empresa. Nunca chamar sem ele.
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
    Map<String, dynamic>? dadosOsExtra,
  });
  Future<void> reverterLote({
    required String osId,
    required String statusAtual,
    required String statusAnterior,
    required Map<String, dynamic> dadosOS,
  });
  Future<void> liberarLotePremontagem({
    required String osId,
    required List<Map<String, dynamic>> itens,
    required String operador,
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
  });
  Stream<List<Map<String, dynamic>>> streamItensPorOs(String osId);
  Future<void> expedirItem({
    required String itemId,
    required String osId,
    required String idCracha,
    required String? equipId,
  });
  Future<void> reprovarItem({
    required String itemId,
    required String statusDestino,
    required Map<String, dynamic> dadosFalha,
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
  });

  Future<void> registrarPecasTrocadas({
    required String itemId,
    required String osId,
    required String empresaId,
    // Map: legendaNumero → codigoProduto
    required Map<int, String> pecas,
  });

  Future<void> condenarItem({
    required String itemId,
    required Map<String, dynamic> item,
    required String etapa,
    required String motivo,
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
  });
  Future<void> finalizarEnsaioTH({
    required String itemId,
    required String? equipamentoId,
    required bool aprovado,
    required String proximaEtapa,
    required Map<String, dynamic> dadosTH,
    Map<String, dynamic>? updatesEquipamento,
  });
  Stream<List<Map<String, dynamic>>> streamItensDescarga(String empresaId);
  Future<void> liberarLoteParaLimpeza({
    required String osId,
    required List<String> itemIds,
  });
  Future<void> reverterParaDescarga(String osId);

  // ─── Novos métodos ────────────────────────────────────────────────────────

  /// Marca um item como descarga concluída (status = 'descarga_concluida').
  /// [operador] é o nome do usuário logado — gravado para rastreabilidade.
  Future<void> confirmarDescargaItem(String itemOsId, String operador);

  /// Busca um item pelo crachá na OS, atualiza para 'aguardando_limpeza'
  /// e avança a OS se for o último item pendente na descarga.
  /// [operador] é o nome do usuário logado — gravado para rastreabilidade.
  /// Lança [Exception] se o crachá não for encontrado.
  Future<void> confirmarDescargaPorCracha(
      String osId, String idCracha, String operador);

  /// Stream de itens aguardando descarga de uma OS, filtrado por agente.
  /// Usado pela TelaBalancoLote para mostrar itens do setor correspondente.
  Stream<List<Map<String, dynamic>>> streamItensDescargaOsPorAgente(
      String osId, List<String> filtrosAgente);


  /// Retorna todos os itens de uma OS com todos os dados aninhados
  /// (dadosTH, manutencao_valvula, recarga, roteiro, pecasTrocadas etc.).
  /// Usado pelo RelatorioOsService para montar o laudo.
  Future<List<Map<String, dynamic>>> buscarItensComDadosCompletos(String osId);


  /// Verifica se um crachá está em uso em qualquer OS no momento.
  /// Retorna true se o crachá está ocupado (statusAtual == 'entregue').
  Future<bool> verificarCrachaEmUso(String idCracha, String empresaId);

  /// Busca os dados do crachá físico pelo ID legível (ex: "R-042") e empresa.
  /// Retorna o documento completo da coleção `crachas`, incluindo
  /// `status`, `itemOsIdAtual` e `osIdAtual`.
  /// Retorna null se o crachá não existir no banco.
  Future<Map<String, dynamic>?> buscarInfoCracha(
      String idCracha, String empresaId);

  /// Busca um item_os diretamente pelo ID do documento.
  /// Usado pelo Scanner de Crachá para carregar os dados do extintor
  /// sem precisar conhecer o osId ou o status.
  Future<Map<String, dynamic>?> buscarItemPorId(String itemId);
}