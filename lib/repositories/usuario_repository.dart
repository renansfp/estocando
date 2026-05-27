// lib/repositories/usuario_repository.dart

abstract class UsuarioRepository {
  /// Stream de todos os usuários com status 'pendente'.
  /// Usado pela tela de aprovação de usuários.
  Stream<List<Map<String, dynamic>>> streamUsuariosPendentes();

  /// Stream de todos os usuários de uma empresa.
  Stream<List<Map<String, dynamic>>> streamUsuariosPorEmpresa(
      String empresaId);

  /// Busca um usuário pelo UID.
  Future<Map<String, dynamic>?> buscarPorId(String uid);

  /// Atualiza os dados de um usuário existente.
  Future<void> atualizar(String uid, Map<String, dynamic> dados);

  /// Aprova um usuário chamando a Cloud Function [approveUser].
  Future<void> aprovar(String uid);

  /// Recusa e exclui um usuário chamando a Cloud Function [rejectUser].
  Future<void> recusar(String uid);

  /// Retorna todas as empresas distintas cadastradas na coleção [usuarios].
  /// Cada item é um Map com 'id' (empresaId) e 'nome'.
  Future<List<Map<String, String>>> buscarTodasEmpresas();

  /// Chama a Cloud Function [recalcularContadores] para recriar o documento
  /// contadores/{empresaId} a partir de todos os itens_os existentes.
  /// Usar apenas na inicialização do sistema ou para corrigir dessincronias.
  Future<void> recalcularContadores(String empresaId);

  /// Retorna todos os operadores habilitados para uma estação específica.
  /// Inclui admins e líderes (acesso total) + operadores com a estação
  /// em [estacoesLiberadas]. Usado pelo seletor de operador ativo.
  Future<List<Map<String, dynamic>>> buscarOperadoresPorEstacao(
      String empresaId, String estacao);
}