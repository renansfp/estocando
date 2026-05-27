// lib/provider/movimentacao_provider.dart

import 'package:flutter/material.dart';
import 'package:protecin_producao/repositories/movimentacao_repository.dart';

class MovimentacaoProvider with ChangeNotifier {
  final MovimentacaoRepository _repository;

  MovimentacaoProvider(this._repository);

  Future<List<Map<String, dynamic>>> buscarMovimentacoesFiltradas(
      String empresaId, {
        DateTime? dataInicio,
        DateTime? dataFim,
        String? tipo,
      }) =>
      _repository.buscarMovimentacoesFiltradas(
        empresaId,
        dataInicio: dataInicio,
        dataFim: dataFim,
        tipo: tipo,
      );

  Stream<List<Map<String, dynamic>>> streamMovimentacoesPorEmpresa(
      String empresaId, {int limit = 50}) =>
      _repository.streamMovimentacoesPorEmpresa(empresaId, limit: limit);

  Future<List<Map<String, dynamic>>> buscarMovimentacoesPorProduto(
      String empresaId, String produtoId) =>
      _repository.buscarMovimentacoesPorProduto(empresaId, produtoId);

  Future<List<Map<String, dynamic>>> buscarMovimentacoesPorLote(
      String empresaId, String loteId) =>
      _repository.buscarMovimentacoesPorLote(empresaId, loteId);

  Future<List<Map<String, dynamic>>> buscarTodosPorEmpresa(
      String empresaId, {int? limit}) =>
      _repository.buscarTodosPorEmpresa(empresaId, limit: limit);

  Future<void> excluirComEstorno({
    required String movimentacaoId,
    required Map<String, dynamic> dadosMovimentacao,
    required String usuarioId,
    required String usuarioNome,
  }) =>
      _repository.excluirComEstorno(
        movimentacaoId: movimentacaoId,
        dadosMovimentacao: dadosMovimentacao,
        usuarioId: usuarioId,
        usuarioNome: usuarioNome,
      );

  Future<void> importarMovimentacaoComEstoque({
    required String empresaId,
    required String codigoProduto,
    required String tipo,
    required double quantidade,
    required DateTime data,
    String? destino,
    double? valorUnitario,
    String? centroCusto,
  }) =>
      _repository.importarMovimentacaoComEstoque(
        empresaId: empresaId,
        codigoProduto: codigoProduto,
        tipo: tipo,
        quantidade: quantidade,
        data: data,
        destino: destino,
        valorUnitario: valorUnitario,
        centroCusto: centroCusto,
      );

  Future<void> resetarDadosEmpresa(String empresaId, String operador) =>
      _repository.resetarDadosEmpresa(empresaId, operador);

  // ─── Novo método ─────────────────────────────────────────────────────────

  /// Salva uma movimentação em transação atômica.
  /// Valida estoque, atualiza produto, faz upsert do lote e cria a movimentação.
  Future<void> salvarMovimentacao({
    required String empresaId,
    required String produtoId,
    required String tipo,
    required double quantidade,
    required double valorUnitario,
    required String? subTipo,
    required bool exigeLote,
    String? loteNumero,
    DateTime? loteValidade,
    String? nomeCliente,
    String? nomeFornecedor,
    String? numeroNF,
    String? numeroOS,
    String? nomeDevolucao,
    String? motivoAcerto,
    String? numeroAG,
    String? nomeColaborador,
    String? centroDeCusto,
    String? numeroPedido,
    required String usuarioId,
    required String usuarioNome,
  }) =>
      _repository.salvarMovimentacao(
        empresaId: empresaId,
        produtoId: produtoId,
        tipo: tipo,
        quantidade: quantidade,
        valorUnitario: valorUnitario,
        subTipo: subTipo,
        exigeLote: exigeLote,
        loteNumero: loteNumero,
        loteValidade: loteValidade,
        nomeCliente: nomeCliente,
        nomeFornecedor: nomeFornecedor,
        numeroNF: numeroNF,
        numeroOS: numeroOS,
        nomeDevolucao: nomeDevolucao,
        motivoAcerto: motivoAcerto,
        numeroAG: numeroAG,
        nomeColaborador: nomeColaborador,
        centroDeCusto: centroDeCusto,
        numeroPedido: numeroPedido,
        usuarioId: usuarioId,
        usuarioNome: usuarioNome,
      );
}