// lib/provider/requisicao_provider.dart

import 'package:flutter/material.dart';
import 'package:protecin_producao/models/requisicao.dart';
import 'package:protecin_producao/repositories/requisicao_repository.dart';

class RequisicaoProvider with ChangeNotifier {
  final RequisicaoRepository _repository;

  RequisicaoProvider(this._repository);

  /// Emite [true] quando há pelo menos uma requisição PENDENTE.
  Stream<bool> streamTemPendentes(String empresaId) =>
      _repository.streamTemPendentes(empresaId);

  /// Stream de requisições PENDENTES, da mais antiga para a mais recente.
  Stream<List<Map<String, dynamic>>> streamRequisicoesPendentes(
      String empresaId) =>
      _repository.streamRequisicoesPendentes(empresaId);

  /// Cria uma nova requisição. Retorna o ID gerado.
  Future<String> criar(Requisicao requisicao) =>
      _repository.criar(requisicao);

  /// Atende uma requisição em transação atômica.
  Future<void> atenderRequisicao({
    required Requisicao requisicao,
    required String atendidoPorId,
    required String atendidoPorNome,
  }) =>
      _repository.atenderRequisicao(
        requisicao: requisicao,
        atendidoPorId: atendidoPorId,
        atendidoPorNome: atendidoPorNome,
      );

  /// Cancela uma requisição registrando quem cancelou e o motivo.
  Future<void> reprovarRequisicao({
    required String requisicaoId,
    required String atendidoPorId,
    required String atendidoPorNome,
    String? motivo,
  }) =>
      _repository.reprovarRequisicao(
        requisicaoId: requisicaoId,
        atendidoPorId: atendidoPorId,
        atendidoPorNome: atendidoPorNome,
        motivo: motivo,
      );
}