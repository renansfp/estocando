// Arquivo: lib/providers/usuario_provider.dart

import 'dart:async'; // Para o StreamSubscription
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/models/usuario.dart'; // <<< Usando o seu modelo

class UsuarioProvider with ChangeNotifier {

  // O "Crachá" - O objeto Usuario que vamos guardar
  Usuario? _usuario;

  // O "Vigilante" do Auth
  StreamSubscription<User?>? _authSubscription;

  // Acesso público e seguro ao "Crachá"
  Usuario? get usuario => _usuario;

  // O "Estado de Carregamento"
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  UsuarioProvider() {
    // 🧠 A "Grande Aula":
    // Assim que o Provider é criado, ele imediatamente começa
    // a "escutar" o Firebase Auth.
    _ouvirMudancasAuth();
  }

  void _ouvirMudancasAuth() {
    // Escuta o estado de autenticação (login/logout)
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null) {
        // --- CASO 1: USUÁRIO FEZ LOGOUT ---
        _usuario = null; // Limpa o "crachá"
        _isLoading = false; // Parou de carregar (mesmo que não tenha usuário)
        notifyListeners(); // Avisa a todos (ex: tela de Login)
      } else {
        // --- CASO 2: USUÁRIO FEZ LOGIN ---
        // Agora, vamos buscar os dados dele no Firestore
        _carregarDadosUsuario(user.uid);
      }
    });
  }

  Future<void> _carregarDadosUsuario(String uid) async {
    try {
      // Vai na coleção 'usuarios' e pega o documento com o UID do login
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();

      if (doc.exists) {
        // 🧠 A "Grande Aula":
        // Aqui usamos o "molde" que você já tinha!
        // Usamos o factory .fromFirestore para "traduzir"
        // o JSON do Firebase para a nossa classe Usuario.
        _usuario = Usuario.fromFirestore(
          doc.data() as Map<String, dynamic>,
          uid,
        );
      } else {
        // Segurança: usuário logado no Auth, mas sem registro no Firestore
        print('ALERTA: Usuário $uid não encontrado no Firestore.');
        _usuario = null;
      }
    } catch (e) {
      print('ERRO AO CARREGAR USUÁRIO: $e');
      _usuario = null; // Segurança em caso de erro
    } finally {
      // Seja sucesso ou falha, o carregamento inicial terminou
      _isLoading = false;
      notifyListeners(); // Avisa a todos que o usuário (ou null) está pronto
    }
  }

  // Boa prática: Limpar o "escutador" quando o Provider for destruído
  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}