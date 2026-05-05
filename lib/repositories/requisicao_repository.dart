// lib/repositories/requisicao_repository.dart

import 'package:protecin_producao/models/requisicao.dart';

abstract class RequisicaoRepository {
  /// Emite [true] quando há pelo menos uma requisição PENDENTE.
  Stream<bool> streamTemPendentes(String empresaId);

  /// Stream de todas as requisições PENDENTES da empresa,
  /// ordenadas da mais antiga para a mais recente.
  Stream<List<Map<String, dynamic>>> streamRequisicoesPendentes(
      String empresaId);

  /// Cria uma nova requisição na coleção [requisicoes].
  /// Retorna o ID do documento criado.
  Future<String> criar(Requisicao requisicao);

  /// Atende uma requisição em uma única transação atômica.
  Future<void> atenderRequisicao({
    required Requisicao requisicao,
    required String atendidoPorId,
    required String atendidoPorNome,
  });

  /// Cancela uma requisição registrando quem cancelou e o motivo.
  Future<void> reprovarRequisicao({
    required String requisicaoId,
    required String atendidoPorId,
    required String atendidoPorNome,
    String? motivo,
  });
}