// lib/repositories/parceiro_repository.dart

abstract class ParceiroRepository {
  /// Stream de todos os parceiros de uma empresa, ordenados por nome.
  Stream<List<Map<String, dynamic>>> streamParceiros(String empresaId);

  /// Fetch único de todos os parceiros de uma empresa.
  Future<List<Map<String, dynamic>>> buscarTodosPorEmpresa(String empresaId);

  /// Verifica se já existe um parceiro com esse código na empresa.
  /// Em modo edição, passa [excludeId] para ignorar o próprio documento.
  Future<bool> verificarCodigoDuplicado(
      String empresaId, String codigo, {String? excludeId});

  /// Cria um novo parceiro. Retorna o ID gerado.
  Future<String> criar(Map<String, dynamic> dados);

  /// Atualiza os dados de um parceiro existente.
  Future<void> atualizar(String parceiroId, Map<String, dynamic> dados);

  /// Remove um parceiro pelo ID.
  Future<void> excluir(String parceiroId);

  // ─── Novos métodos ────────────────────────────────────────────────────────

  /// Retorna os códigos e CNPJs já cadastrados na empresa.
  /// Usado para validar duplicatas durante a importação em lote.
  Future<({Set<String> codigos, Set<String> cnpjs})> buscarCodigosECnpjsExistentes(
      String empresaId);

  /// Importa uma lista de parceiros novos em batch.
  /// Recebe os dados já prontos (com empresaId incluso).
  /// Retorna o número de parceiros efetivamente criados.
  Future<int> importarLote(List<Map<String, dynamic>> parceiros);

  /// Busca parceiros por prefixo de nome, filtrado por empresa e tipo.
  /// Usado pelo AutocompleteParceiroWidget.
  Future<List<Map<String, dynamic>>> buscarPorNome({
    required String empresaId,
    required String tipoParceiro,
    required String termo,
    int limite = 10,
  });


  /// Busca um parceiro pelo ID. Retorna null se não encontrado.
  Future<Map<String, dynamic>?> buscarPorId(String parceiroId);
}