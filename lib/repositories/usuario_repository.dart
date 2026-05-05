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
  /// A Cloud Function cuida de setar o status e as permissões necessárias.
  Future<void> aprovar(String uid);

  /// Recusa e exclui um usuário chamando a Cloud Function [rejectUser].
  /// A Cloud Function exclui o usuário do Authentication e do Firestore.
  Future<void> recusar(String uid);

  /// Retorna todas as empresas distintas cadastradas na coleção [usuarios].
  /// Cada item é um Map com 'id' (empresaId) e 'nome'.
  /// Usado pelas telas de importação admin.
  Future<List<Map<String, String>>> buscarTodasEmpresas();
}