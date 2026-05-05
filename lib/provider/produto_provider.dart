// lib/provider/produto_provider.dart

import 'package:flutter/material.dart';
import 'package:protecin_producao/repositories/produto_repository.dart';

class ProdutoProvider with ChangeNotifier {
  final ProdutoRepository _repository;

  ProdutoProvider(this._repository);

  Stream<List<Map<String, dynamic>>> streamProdutosComControleLote(
      String empresaId) =>
      _repository.streamProdutosComControleLote(empresaId);

  Stream<List<Map<String, dynamic>>> streamProdutos(String empresaId) =>
      _repository.streamProdutos(empresaId);

  Stream<List<Map<String, dynamic>>> streamProdutosFiltrados(
      String empresaId, {String? busca}) =>
      _repository.streamProdutosFiltrados(empresaId, busca: busca);

  Future<List<Map<String, dynamic>>> buscarTodosPorEmpresa(
      String empresaId) =>
      _repository.buscarTodosPorEmpresa(empresaId);

  Future<Map<String, dynamic>?> buscarPorCodigo(String codigo) =>
      _repository.buscarPorCodigo(codigo);

  Stream<List<Map<String, dynamic>>> streamLotesPorProduto(
      String produtoId) =>
      _repository.streamLotesPorProduto(produtoId);

  Future<bool> verificarCodigoDuplicado(
      String empresaId, String codigo, {String? excludeId}) =>
      _repository.verificarCodigoDuplicado(empresaId, codigo,
          excludeId: excludeId);

  Future<String> criar(Map<String, dynamic> dados) =>
      _repository.criar(dados);

  Future<void> atualizar(String produtoId, Map<String, dynamic> dados) =>
      _repository.atualizar(produtoId, dados);

  Future<void> excluir(String produtoId) =>
      _repository.excluir(produtoId);

  Future<void> descontarEstoque({
    required String produtoId,
    required String loteId,
    required double quantidade,
  }) =>
      _repository.descontarEstoque(
          produtoId: produtoId, loteId: loteId, quantidade: quantidade);

  Future<void> adicionarEstoque({
    required String produtoId,
    required String loteId,
    required double quantidade,
    required Map<String, dynamic> dadosLote,
  }) =>
      _repository.adicionarEstoque(
          produtoId: produtoId,
          loteId: loteId,
          quantidade: quantidade,
          dadosLote: dadosLote);

  // ─── Novos métodos ────────────────────────────────────────────────────────

  /// Retorna os códigos já cadastrados na empresa para evitar duplicatas.
  Future<Set<String>> buscarCodigosExistentes(String empresaId) =>
      _repository.buscarCodigosExistentes(empresaId);

  /// Importa produtos em lote (batch). Retorna a quantidade criada.
  Future<int> importarLote(List<Map<String, dynamic>> produtos) =>
      _repository.importarLote(produtos);
}