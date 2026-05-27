// lib/repositories/produto_repository.dart

abstract class ProdutoRepository {
  /// Stream de produtos com controle de lote ativo.
  Stream<List<Map<String, dynamic>>> streamProdutosComControleLote(
      String empresaId);

  /// Stream de todos os produtos de uma empresa.
  Stream<List<Map<String, dynamic>>> streamProdutos(String empresaId);

  /// Stream de produtos com filtro opcional por texto (nome ou código).
  Stream<List<Map<String, dynamic>>> streamProdutosFiltrados(
      String empresaId, {String? busca});

  /// Fetch único de todos os produtos ativos de uma empresa.
  Future<List<Map<String, dynamic>>> buscarTodosPorEmpresa(String empresaId);

  /// Busca um produto pelo código mestre sem filtro de empresa.
  /// Usado na execução de recarga.
  /// [empresaId] é obrigatório — garante que o produto retornado pertence
  /// à empresa correta. Nunca chamar sem ele.
  Future<Map<String, dynamic>?> buscarPorCodigo(
      String empresaId, String codigo);

  /// Stream dos lotes de um produto específico.
  Stream<List<Map<String, dynamic>>> streamLotesPorProduto(String produtoId);

  /// Verifica se já existe um produto com esse código na empresa.
  Future<bool> verificarCodigoDuplicado(
      String empresaId, String codigo, {String? excludeId});

  /// Cria um novo produto. Retorna o ID gerado.
  Future<String> criar(Map<String, dynamic> dados);

  /// Atualiza os dados de um produto existente.
  Future<void> atualizar(String produtoId, Map<String, dynamic> dados);

  /// Remove um produto pelo ID.
  Future<void> excluir(String produtoId);

  /// Desconta quantidade de um lote e do produto pai — operação atômica.
  Future<void> descontarEstoque({
    required String produtoId,
    required String loteId,
    required double quantidade,
  });

  /// Adiciona quantidade a um lote e ao produto pai — operação atômica.
  Future<void> adicionarEstoque({
    required String produtoId,
    required String loteId,
    required double quantidade,
    required Map<String, dynamic> dadosLote,
  });

  // ─── Novos métodos ────────────────────────────────────────────────────────

  /// Retorna o conjunto de códigos já cadastrados na empresa.
  /// Usado para evitar duplicatas durante a importação em lote.
  Future<Set<String>> buscarCodigosExistentes(String empresaId);

  /// Importa uma lista de produtos novos em batch atômico.
  /// Recebe os dados já prontos (com empresaId incluso).
  /// Retorna o número de produtos efetivamente criados.
  Future<int> importarLote(List<Map<String, dynamic>> produtos);
}