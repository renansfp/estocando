// lib/provider/parceiro_provider.dart

import 'package:flutter/material.dart';
import 'package:protecin_producao/repositories/parceiro_repository.dart';

class ParceiroProvider with ChangeNotifier {
  final ParceiroRepository _repository;

  ParceiroProvider(this._repository);

  /// Stream de todos os parceiros da empresa, ordenados por nome.
  Stream<List<Map<String, dynamic>>> streamParceiros(String empresaId) =>
      _repository.streamParceiros(empresaId);

  /// Fetch único — para dropdowns e formulários.
  Future<List<Map<String, dynamic>>> buscarTodosPorEmpresa(
      String empresaId) =>
      _repository.buscarTodosPorEmpresa(empresaId);

  /// Verifica se já existe um parceiro com esse código na empresa.
  Future<bool> verificarCodigoDuplicado(
      String empresaId, String codigo, {String? excludeId}) =>
      _repository.verificarCodigoDuplicado(empresaId, codigo,
          excludeId: excludeId);

  /// Cria um novo parceiro. Retorna o ID gerado.
  Future<String> criar(Map<String, dynamic> dados) =>
      _repository.criar(dados);

  /// Atualiza os dados de um parceiro existente.
  Future<void> atualizar(String parceiroId, Map<String, dynamic> dados) =>
      _repository.atualizar(parceiroId, dados);

  /// Remove um parceiro pelo ID.
  Future<void> excluir(String parceiroId) =>
      _repository.excluir(parceiroId);

  // ─── Novos métodos ────────────────────────────────────────────────────────

  /// Retorna códigos e CNPJs já cadastrados na empresa para validação de duplicatas.
  Future<({Set<String> codigos, Set<String> cnpjs})>
  buscarCodigosECnpjsExistentes(String empresaId) =>
      _repository.buscarCodigosECnpjsExistentes(empresaId);

  /// Importa parceiros em lote (batch). Retorna a quantidade criada.
  Future<int> importarLote(List<Map<String, dynamic>> parceiros) =>
      _repository.importarLote(parceiros);

  /// Busca parceiros por prefixo de nome — para o AutocompleteParceiroWidget.
  Future<List<Map<String, dynamic>>> buscarPorNome({
    required String empresaId,
    required String tipoParceiro,
    required String termo,
    int limite = 10,
  }) =>
      _repository.buscarPorNome(
        empresaId: empresaId,
        tipoParceiro: tipoParceiro,
        termo: termo,
        limite: limite,
      );


  Future<Map<String, dynamic>?> buscarPorId(String parceiroId) =>
      _repository.buscarPorId(parceiroId);
}