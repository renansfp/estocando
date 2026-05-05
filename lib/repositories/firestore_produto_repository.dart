// lib/repositories/firestore_produto_repository.dart

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/repositories/produto_repository.dart';

class FirestoreProdutoRepository implements ProdutoRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Map<String, dynamic> _toMap(DocumentSnapshot doc) {
    return <String, dynamic>{
      'id': doc.id,
      ...(doc.data() as Map<String, dynamic>? ?? {}),
    };
  }

  @override
  Stream<List<Map<String, dynamic>>> streamProdutosComControleLote(
      String empresaId) {
    return _db
        .collection('produtos')
        .where('empresaId', isEqualTo: empresaId)
        .where('controlarLote', isEqualTo: true)
        .where('ativo', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(_toMap).toList());
  }

  @override
  Stream<List<Map<String, dynamic>>> streamProdutos(String empresaId) {
    return _db
        .collection('produtos')
        .where('empresaId', isEqualTo: empresaId)
        .orderBy('nome')
        .snapshots()
        .map((snap) => snap.docs.map(_toMap).toList());
  }

  @override
  Stream<List<Map<String, dynamic>>> streamProdutosFiltrados(
      String empresaId, {String? busca}) {
    Query query = _db
        .collection('produtos')
        .where('empresaId', isEqualTo: empresaId)
        .orderBy('nome');

    if (busca != null && busca.isNotEmpty) {
      final buscaUpper = busca.toUpperCase();
      query = query.startAt([buscaUpper]).endAt(['$buscaUpper\uf8ff']);
    }

    return query.snapshots().map((snap) => snap.docs.map(_toMap).toList());
  }

  @override
  Future<List<Map<String, dynamic>>> buscarTodosPorEmpresa(
      String empresaId) async {
    final snap = await _db
        .collection('produtos')
        .where('empresaId', isEqualTo: empresaId)
        .where('ativo', isEqualTo: true)
        .orderBy('nome')
        .get();
    return snap.docs.map(_toMap).toList();
  }

  @override
  Future<Map<String, dynamic>?> buscarPorCodigo(String codigo) async {
    final snap = await _db
        .collection('produtos')
        .where('codigo', isEqualTo: codigo)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return _toMap(snap.docs.first);
  }

  @override
  Stream<List<Map<String, dynamic>>> streamLotesPorProduto(String produtoId) {
    return _db
        .collection('produtos')
        .doc(produtoId)
        .collection('lotes')
        .snapshots()
        .map((snap) => snap.docs.map(_toMap).toList());
  }

  @override
  Future<bool> verificarCodigoDuplicado(
      String empresaId, String codigo, {String? excludeId}) async {
    final snap = await _db
        .collection('produtos')
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
    final ref = await _db.collection('produtos').add({
      ...dados,
      'timestamp': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  @override
  Future<void> atualizar(String produtoId, Map<String, dynamic> dados) async {
    await _db.collection('produtos').doc(produtoId).update(dados);
  }

  @override
  Future<void> excluir(String produtoId) async {
    await _db.collection('produtos').doc(produtoId).delete();
  }

  @override
  Future<void> descontarEstoque({
    required String produtoId,
    required String loteId,
    required double quantidade,
  }) async {
    final batch = _db.batch();
    batch.update(
      _db.collection('produtos').doc(produtoId),
      {'quantidadeAtual': FieldValue.increment(-quantidade)},
    );
    batch.update(
      _db.collection('produtos').doc(produtoId).collection('lotes').doc(loteId),
      {'quantidadeAtual': FieldValue.increment(-quantidade)},
    );
    await batch.commit();
  }

  @override
  Future<void> adicionarEstoque({
    required String produtoId,
    required String loteId,
    required double quantidade,
    required Map<String, dynamic> dadosLote,
  }) async {
    final batch = _db.batch();
    batch.update(
      _db.collection('produtos').doc(produtoId),
      {'quantidadeAtual': FieldValue.increment(quantidade)},
    );
    final dadosCompletos = <String, dynamic>{
      'quantidadeAtual': FieldValue.increment(quantidade),
      ...dadosLote,
    };
    batch.set(
      _db.collection('produtos').doc(produtoId).collection('lotes').doc(loteId),
      dadosCompletos,
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  // ─── Novos métodos ────────────────────────────────────────────────────────

  @override
  Future<Set<String>> buscarCodigosExistentes(String empresaId) async {
    final snap = await _db
        .collection('produtos')
        .where('empresaId', isEqualTo: empresaId)
        .get();
    return snap.docs
        .map((doc) => (doc.data()['codigo'] as String?) ?? '')
        .where((c) => c.isNotEmpty)
        .toSet();
  }

  @override
  Future<int> importarLote(List<Map<String, dynamic>> produtos) async {
    if (produtos.isEmpty) return 0;
    int criados = 0;

    // Chunks de 400 para respeitar o limite de 500 docs/batch do Firestore
    for (int i = 0; i < produtos.length; i += 400) {
      final chunk = produtos.sublist(i, min(i + 400, produtos.length));
      final batch = _db.batch();
      for (final produto in chunk) {
        batch.set(_db.collection('produtos').doc(), {
          ...produto,
          'timestamp': FieldValue.serverTimestamp(),
        });
        criados++;
      }
      await batch.commit();
    }

    return criados;
  }
}