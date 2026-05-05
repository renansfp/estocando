// lib/provider/usuario_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:protecin_producao/models/usuario.dart';
import 'package:protecin_producao/repositories/usuario_repository.dart';

class UsuarioProvider with ChangeNotifier {
  final UsuarioRepository _repository;

  Usuario? _usuario;
  StreamSubscription<User?>? _authSubscription;

  Usuario? get usuario => _usuario;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  UsuarioProvider(this._repository) {
    _ouvirMudancasAuth();
  }

  void _ouvirMudancasAuth() {
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
          if (user == null) {
            _usuario = null;
            _isLoading = false;
            notifyListeners();
          } else {
            _carregarDadosUsuario(user.uid);
          }
        });
  }

  Future<void> _carregarDadosUsuario(String uid) async {
    try {
      final dados = await _repository.buscarPorId(uid);
      if (dados != null) {
        _usuario = Usuario.fromMap(dados, uid);
      } else {
        debugPrint('ALERTA: Usuário $uid não encontrado no Firestore.');
        _usuario = null;
      }
    } catch (e) {
      debugPrint('ERRO AO CARREGAR USUÁRIO: $e');
      _usuario = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Retorna todas as empresas distintas cadastradas na coleção [usuarios].
  /// Cada item é um Map com 'id' (empresaId) e 'nome'.
  /// Usado pelas telas de importação admin.
  Future<List<Map<String, String>>> buscarTodasEmpresas() =>
      _repository.buscarTodasEmpresas();

  // ─── Métodos admin (via UsuarioRepository) ───────────────────────────────

  /// Stream de usuários com status 'pendente'.
  /// Usado pela tela de aprovação.
  Stream<List<Map<String, dynamic>>> streamUsuariosPendentes() =>
      _repository.streamUsuariosPendentes();

  /// Stream de todos os usuários de uma empresa.
  Stream<List<Map<String, dynamic>>> streamUsuariosPorEmpresa(
      String empresaId) =>
      _repository.streamUsuariosPorEmpresa(empresaId);

  /// Aprova um usuário via Cloud Function [approveUser].
  Future<void> aprovar(String uid) => _repository.aprovar(uid);

  /// Recusa e exclui um usuário via Cloud Function [rejectUser].
  Future<void> recusar(String uid) => _repository.recusar(uid);

  /// Atualiza os dados de um usuário.
  Future<void> atualizar(String uid, Map<String, dynamic> dados) =>
      _repository.atualizar(uid, dados);

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}