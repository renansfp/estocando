// lib/repositories/firestore_usuario_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:protecin_producao/repositories/usuario_repository.dart';

class FirestoreUsuarioRepository implements UsuarioRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
  FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  Map<String, dynamic> _toMap(DocumentSnapshot doc) => <String, dynamic>{
    'id': doc.id,
    ...(doc.data() as Map<String, dynamic>? ?? {}),
  };

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

  @override
  Future<void> aprovar(String uid) async {
    final callable = _functions.httpsCallable('approveUser');
    await callable.call({'uid': uid});
  }

  @override
  Future<void> recusar(String uid) async {
    final callable = _functions.httpsCallable('rejectUser');
    await callable.call({'uid': uid});
  }

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
}