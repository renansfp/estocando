// lib/models/usuario.dart

class Usuario {
  final String uid; // ID do Firebase Auth
  final String email;
  final String nome;
  final String empresaId; // A CHAVE-MESTRA!
  final String permissao; // Ex: 'admin', 'tecnico'
  final String? status;   // Ex: 'pendente', 'ativo'

  Usuario({
    required this.uid,
    required this.email,
    required this.nome,
    required this.empresaId,
    required this.permissao,
    this.status,
  });

  /// Usado pelo repository — converte Map<String, dynamic> (com 'id' incluso) em Usuario.
  factory Usuario.fromMap(Map<String, dynamic> data, String uid) {
    return Usuario(
      uid: uid,
      email: data['email'] as String? ?? '',
      nome: data['nome'] as String? ?? '',
      empresaId: data['empresaId'] as String? ?? '',
      permissao: data['permissao'] as String? ?? 'leitura',
      status: data['status'] as String?,
    );
  }

  /// Mantido para compatibilidade com código existente.
  factory Usuario.fromFirestore(Map<String, dynamic> data, String uid) {
    return Usuario.fromMap(data, uid);
  }
}