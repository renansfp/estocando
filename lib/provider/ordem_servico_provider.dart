// lib/provider/ordem_servico_provider.dart

import 'package:flutter/material.dart';
import 'package:protecin_producao/models/item_os.dart';
import 'package:protecin_producao/models/ordem_servico.dart';
import 'package:protecin_producao/models/parceiro.dart';
import 'package:protecin_producao/repositories/ordem_servico_repository.dart';

class OrdemServicoProvider with ChangeNotifier {
  final OrdemServicoRepository _repository;

  OrdemServicoProvider(this._repository);

  bool _isSaving = false;
  String? _erro;

  bool get isSaving => _isSaving;
  String? get erro => _erro;

  Future<String?> criarOS({
    required OrdemServico os,
    required List<ItemOS> itens,
    required Parceiro cliente,
    required String observacoes,
  }) async {
    _isSaving = true;
    _erro = null;
    notifyListeners();

    try {
      final numeroOS = await _repository.criarOS(
        os: os,
        itens: itens,
        cliente: cliente,
        observacoes: observacoes,
      );
      return numeroOS;
    } catch (e) {
      _erro = 'Erro ao criar OS: $e';
      notifyListeners();
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // ─── Novo método ─────────────────────────────────────────────────────────

  /// Busca uma OS pelo número dentro de uma empresa.
  /// Tenta com o número exato e depois com zero-padding.
  /// Retorna [null] se não encontrar.
  Future<Map<String, dynamic>?> buscarPorNumero(
      String empresaId, String numeroOS) =>
      _repository.buscarPorNumero(empresaId, numeroOS);

  Stream<List<Map<String, dynamic>>> streamTodasOrdenadas(
      String empresaId, {
        bool somentAbertas = false,
      }) =>
      _repository.streamTodasOrdenadas(empresaId, somentAbertas: somentAbertas);

  Future<List<Map<String, dynamic>>> buscarOSAbertas(String empresaId) =>
      _repository.buscarOSAbertas(empresaId);

  Stream<Map<String, dynamic>?> streamPorId(String osId) =>
      _repository.streamPorId(osId);


  Future<OrdemServico?> buscarPorId(String osId) =>
      _repository.buscarPorId(osId);
}