// lib/repositories/firestore_parceiro_repository.dart

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/repositories/parceiro_repository.dart';

class FirestoreParceiroRepository implements ParceiroRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Map<String, dynamic> _toMap(DocumentSnapshot doc) => <String, dynamic>{
    'id': doc.id,
    ...(doc.data() as Map<String, dynamic>? ?? {}),
  };

  @override
  Stream<List<Map<String, dynamic>>> streamParceiros(String empresaId) {
    return _db
        .collection('parceiros')
        .where('empresaId', isEqualTo: empresaId)
        .orderBy('nome')
        .snapshots()
        .map((snap) => snap.docs.map(_toMap).toList());
  }

  @override
  Future<List<Map<String, dynamic>>> buscarTodosPorEmpresa(
      String empresaId) async {
    final snap = await _db
        .collection('parceiros')
        .where('empresaId', isEqualTo: empresaId)
        .orderBy('nome')
        .get();
    return snap.docs.map(_toMap).toList();
  }

  @override
  Future<bool> verificarCodigoDuplicado(
      String empresaId, String codigo, {String? excludeId}) async {
    final snap = await _db
        .collection('parceiros')
        .where('empresaId', isEqualTo: empresaId)
        .where('codigo', isEqualTo: codigo)
        .get();
    if (snap.docs.isEmpty) return false;
    if (excludeId != null) {
      return snap.docs.any((doc) => doc.id != excludeId);
    }
    return true;
  }

  @override
  Future<String> criar(Map<String, dynamic> dados) async {
    final ref = await _db.collection('parceiros').add({
      ...dados,
      'timestamp': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  @override
  Future<void> atualizar(String parceiroId, Map<String, dynamic> dados) async {
    await _db.collection('parceiros').doc(parceiroId).update(dados);
  }

  @override
  Future<void> excluir(String parceiroId) async {
    await _db.collection('parceiros').doc(parceiroId).delete();
  }

  // ─── Novos métodos ────────────────────────────────────────────────────────

  @override
  Future<({Set<String> codigos, Set<String> cnpjs})>
  buscarCodigosECnpjsExistentes(String empresaId) async {
    final snap = await _db
        .collection('parceiros')
        .where('empresaId', isEqualTo: empresaId)
        .get();

    final codigos = <String>{};
    final cnpjs = <String>{};

    for (final doc in snap.docs) {
      final data = doc.data();
      final codigo = data['codigo'] as String?;
      final cnpj = data['cnpj'] as String?;
      if (codigo != null && codigo.isNotEmpty) codigos.add(codigo);
      if (cnpj != null && cnpj.isNotEmpty) cnpjs.add(cnpj);
    }

    return (codigos: codigos, cnpjs: cnpjs);
  }

  @override
  Future<int> importarLote(List<Map<String, dynamic>> parceiros) async {
    if (parceiros.isEmpty) return 0;
    int criados = 0;

    // Chunks de 400 para respeitar o limite de 500 docs/batch do Firestore
    for (int i = 0; i < parceiros.length; i += 400) {
      final chunk = parceiros.sublist(i, min(i + 400, parceiros.length));
      final batch = _db.batch();
      for (final parceiro in chunk) {
        batch.set(_db.collection('parceiros').doc(), {
          ...parceiro,
          'timestamp': FieldValue.serverTimestamp(),
        });
        criados++;
      }
      await batch.commit();
    }

    return criados;
  }

  @override
  Future<List<Map<String, dynamic>>> buscarPorNome({
    required String empresaId,
    required String tipoParceiro,
    required String termo,
    int limite = 10,
  }) async {
    final termoUpper = termo.toUpperCase();
    final snap = await _db
        .collection('parceiros')
        .where('empresaId', isEqualTo: empresaId)
        .where('tipo', isEqualTo: tipoParceiro)
        .where('nome', isGreaterThanOrEqualTo: termoUpper)
        .where('nome', isLessThanOrEqualTo: '$termoUpper\uf8ff')
        .limit(limite)
        .get();
    return snap.docs.map(_toMap).toList();
  }


  @override
  Future<Map<String, dynamic>?> buscarPorId(String parceiroId) async {
    final doc = await _db.collection('parceiros').doc(parceiroId).get();
    if (!doc.exists) return null;
    return _toMap(doc);
  }
}