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
}