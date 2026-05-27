// lib/repositories/firestore_usuario_repository.dart
//
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  POR QUE HTTP E NÃO cloud_functions?
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  O pacote cloud_functions não tem suporte completo no Windows
//  Desktop. As chamadas a approveUser, rejectUser e recalcularContadores
//  falhavam silenciosamente nessa plataforma.
//
//  Cloud Functions callable são, por baixo dos panos, requisições
//  HTTP POST. Chamá-las diretamente com o pacote http funciona em
//  todas as plataformas (Web, Android, iOS, Windows, macOS, Linux).
//
//  Formato da chamada:
//    POST https://southamerica-east1-protecin-producao.cloudfunctions.net/{fn}
//    Authorization: Bearer {idToken do usuário logado}
//    Content-Type: application/json
//    Body: { "data": { ...parâmetros... } }
//
//  Formato da resposta de sucesso:  { "result": { ... } }
//  Formato de erro:                 { "error": { "message": "..." } }
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:protecin_producao/repositories/usuario_repository.dart';

class FirestoreUsuarioRepository implements UsuarioRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Base URL das Cloud Functions do projeto
  static const _baseUrl =
      'https://southamerica-east1-protecin-producao.cloudfunctions.net';

  Map<String, dynamic> _toMap(DocumentSnapshot doc) => <String, dynamic>{
    'id': doc.id,
    ...(doc.data() as Map<String, dynamic>? ?? {}),
  };

  // ── Chamada genérica a qualquer Cloud Function callable ──────────
  //
  // Obtém o token do usuário logado, monta o POST e lança exceção
  // se a função retornar erro (mesmo que o HTTP status seja 200).
  Future<Map<String, dynamic>> _callFunction(
      String functionName,
      Map<String, dynamic> params,
      ) async {
    // Token de autenticação — obrigatório para funções que verificam context.auth
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Nenhum usuário autenticado.');
    }
    final idToken = await user.getIdToken();

    final uri = Uri.parse('$_baseUrl/$functionName');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'data': params}),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    // Cloud Functions retorna erro dentro do body mesmo com status 200
    if (body.containsKey('error')) {
      final msg = body['error']?['message'] ?? 'Erro desconhecido na função.';
      throw Exception(msg);
    }

    return body['result'] as Map<String, dynamic>? ?? {};
  }

  // ── Streams e leituras do Firestore (sem alteração) ──────────────

  @override
  Stream<List<Map<String, dynamic>>> streamUsuariosPendentes() {
    return _db
        .collection('usuarios')
        .where('status', isEqualTo: 'pendente')
        .snapshots()
        .map((snap) => snap.docs.map(_toMap).toList());
  }

  @override
  Stream<List<Map<String, dynamic>>> streamUsuariosPorEmpresa(
      String empresaId) {
    return _db
        .collection('usuarios')
        .where('empresaId', isEqualTo: empresaId)
        .snapshots()
        .map((snap) => snap.docs.map(_toMap).toList());
  }

  @override
  Future<Map<String, dynamic>?> buscarPorId(String uid) async {
    final doc = await _db.collection('usuarios').doc(uid).get();
    if (!doc.exists) return null;
    return _toMap(doc);
  }

  @override
  Future<void> atualizar(String uid, Map<String, dynamic> dados) async {
    await _db.collection('usuarios').doc(uid).update(dados);
  }

  // ── Chamadas às Cloud Functions via HTTP (funciona em Windows) ───

  @override
  Future<void> aprovar(String uid) async {
    await _callFunction('approveUser', {'uid': uid});
  }

  @override
  Future<void> recusar(String uid) async {
    await _callFunction('rejectUser', {'uid': uid});
  }

  @override
  Future<void> recalcularContadores(String empresaId) async {
    await _callFunction('recalcularContadores', {'empresaId': empresaId});
  }

  // ── Leitura de empresas ───────────────────────────────────────────

  @override
  Future<List<Map<String, String>>> buscarTodasEmpresas() async {
    final snap = await _db.collection('usuarios').get();
    final Map<String, String> empresasMap = {};
    for (final doc in snap.docs) {
      final data = doc.data();
      final empresaId = data['empresaId'] as String?;
      final nomeEmpresa = data['nome'] as String?;
      if (empresaId != null &&
          empresaId.isNotEmpty &&
          nomeEmpresa != null &&
          nomeEmpresa.isNotEmpty) {
        empresasMap.putIfAbsent(empresaId, () => nomeEmpresa);
      }
    }
    return empresasMap.entries
        .map((e) => {'id': e.key, 'nome': e.value})
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> buscarOperadoresPorEstacao(
      String empresaId, String estacao) async {
    // Busca todos os usuários aprovados da empresa em uma única query.
    // O filtro fino (quem tem acesso à estação) é feito no cliente —
    // o Firestore não suporta "array-contains OR permissao in [admin, lider]"
    // em uma única query sem índice composto extra.
    final snap = await _db
        .collection('usuarios')
        .where('empresaId', isEqualTo: empresaId)
        .where('status', isEqualTo: 'aprovado')
        .get();

    return snap.docs
        .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
        .where((u) {
      final permissao = (u['permissao'] as String? ?? '').toLowerCase();
      // Admin e líder têm acesso a tudo
      if (permissao == 'admin' || permissao == 'lider') return true;
      // Operador: só se a estação estiver na lista dele
      if (permissao == 'operador') {
        final estacoes = u['estacoesLiberadas'];
        if (estacoes is List) return estacoes.contains(estacao);
      }
      return false;
    })
        .toList();
  }
}