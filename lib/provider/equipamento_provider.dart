// lib/provider/equipamento_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:protecin_producao/models/equipamento.dart';
import 'package:protecin_producao/repositories/equipamento_repository.dart';

class EquipamentoProvider with ChangeNotifier {
  final EquipamentoRepository _repository;

  EquipamentoProvider(this._repository);

  List<Equipamento> _equipamentos = [];
  bool _isLoading = false;
  String? _erro;
  StreamSubscription<List<Equipamento>>? _subscription;

  List<Equipamento> get equipamentos => _equipamentos;
  bool get isLoading => _isLoading;
  String? get erro => _erro;

  void iniciarEscuta(String empresaId) {
    _subscription?.cancel();
    _isLoading = true;
    _erro = null;
    notifyListeners();

    _subscription = _repository.listarPorEmpresa(empresaId).listen(
          (lista) {
        _equipamentos = lista;
        _isLoading = false;
        _erro = null;
        notifyListeners();
      },
      onError: (e) {
        _erro = 'Erro ao carregar equipamentos: $e';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void iniciarEscutaPorCliente(String clienteId) {
    _subscription?.cancel();
    _isLoading = true;
    _erro = null;
    notifyListeners();

    _subscription = _repository.listarPorCliente(clienteId).listen(
          (lista) {
        _equipamentos = lista;
        _isLoading = false;
        _erro = null;
        notifyListeners();
      },
      onError: (e) {
        _erro = 'Erro ao carregar equipamentos: $e';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void pararEscuta() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<Equipamento?> buscarPorId(String id) =>
      _repository.buscarPorId(id);

  Future<bool> verificarDisponibilidade(String equipamentoId) {
    return _repository.verificarDisponibilidade(equipamentoId);
  }

  Future<String> criar(Equipamento equipamento) async {
    return await _repository.criar(equipamento);
  }

  Future<void> atualizar(Equipamento equipamento) async {
    await _repository.atualizar(equipamento);
  }

  Future<DiagnosticoBloqueio> diagnosticarBloqueio(String equipamentoId, String osId) {
    return _repository.diagnosticarBloqueio(equipamentoId, osId);
  }

  Future<void> liberarBloqueio(String equipamentoId) async {
    await _repository.liberarBloqueio(equipamentoId);
  }

  Future<void> condenar(String equipamentoId, String motivo) async {
    await _repository.condenar(equipamentoId, motivo);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }


  Future<Equipamento?> buscarPorCodigo({
    required String empresaId,
    required String clienteId,
    required String codigo,
  }) =>
      _repository.buscarPorCodigo(
        empresaId: empresaId,
        clienteId: clienteId,
        codigo: codigo,
      );
}