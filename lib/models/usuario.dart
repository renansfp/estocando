// Arquivo: lib/models/usuario.dart

class Usuario {
  final String uid; // ID do Firebase Auth
  final String email;
  final String nome;
  final String empresaId; // A CHAVE-MESTRA!
  final String permissao; // Ex: 'admin', 'tecnico'

  Usuario({
    required this.uid,
    required this.email,
    required this.nome,
    required this.empresaId,
    required this.permissao,
  });

  // Um tradutor simples vindo do documento da coleção 'usuarios' do Firestore
  factory Usuario.fromFirestore(Map<String, dynamic> data, String uid) {
    return Usuario(
      uid: uid,
      email: data['email'] ?? '',
      nome: data['nome'] ?? '',
      empresaId: data['empresaId'] ?? '',
      permissao: data['permissao'] ?? 'leitura', // Padrão seguro
    );
  }
}