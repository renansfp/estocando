// lib/repositories/movimentacao_repository.dart

abstract class MovimentacaoRepository {
  Stream<List<Map<String, dynamic>>> streamMovimentacoesFiltradas(
      String empresaId, {
        DateTime? dataInicio,
        DateTime? dataFim,
        String? tipo,
      });

  Stream<List<Map<String, dynamic>>> streamMovimentacoesPorEmpresa(
      String empresaId, {int limit = 50});

  Stream<List<Map<String, dynamic>>> streamMovimentacoesPorProduto(
      String empresaId, String produtoId);

  Stream<List<Map<String, dynamic>>> streamMovimentacoesPorLote(
      String empresaId, String loteId);

  Future<List<Map<String, dynamic>>> buscarTodosPorEmpresa(String empresaId);

  Future<void> excluirComEstorno({
    required String movimentacaoId,
    required Map<String, dynamic> dadosMovimentacao,
    required String usuarioId,
    required String usuarioNome,
  });

  Future<void> importarMovimentacaoComEstoque({
    required String empresaId,
    required String codigoProduto,
    required String tipo,
    required double quantidade,
    required DateTime data,
    String? destino,
    double? valorUnitario,
    String? centroCusto,
  });

  Future<void> resetarDadosEmpresa(String empresaId);

  // ─── Novo método ─────────────────────────────────────────────────────────

  /// Salva uma movimentação em uma transação atômica:
  ///   1. Lê e valida o estoque do produto
  ///   2. Atualiza o estoque (e o valor unitário se for COMPRA)
  ///   3. Faz upsert do lote (se o produto exigir controle de lote)
  ///   4. Cria o documento da movimentação
  ///
  /// Lança [Exception] se o estoque for insuficiente para saídas.
  Future<void> salvarMovimentacao({
    required String empresaId,
    required String produtoId,
    required String tipo,        // 'entrada' | 'saida'
    required double quantidade,
    required double valorUnitario,
    required String? subTipo,
    // lote
    required bool exigeLote,
    String? loteNumero,
    DateTime? loteValidade,
    // contexto da movimentação
    String? nomeCliente,
    String? nomeFornecedor,
    String? numeroNF,
    String? numeroOS,
    String? nomeDevolucao,
    String? motivoAcerto,
    String? numeroAG,
    String? nomeColaborador,
    String? centroDeCusto,
    String? numeroPedido,
    required String usuarioId,
    required String usuarioNome,
  });
}