import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// O "PORQUÊ": Removemos o import da TelaHome daqui.
// A navegação para a tela principal deve ser controlada pelo StreamBuilder
// no seu main.dart, que ouve o estado de autenticação. A tela de login
// não deve mais ser responsável por essa navegação direta.

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoginMode = true;
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _submitAuthForm() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final email = _emailController.text.trim();
      final senha = _senhaController.text.trim();

      if (_isLoginMode) {
        // LÓGICA DE LOGIN (Entrar)
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: senha,
        );
        // Se o login for bem-sucedido, o StreamBuilder no main.dart
        // irá detectar o usuário logado e redirecionar para a TelaHome.
        // Não precisamos mais de um Navigator.push aqui.

      } else {
        // LÓGICA DE CADASTRO
        // O "PORQUÊ": Aqui está a principal mudança de fluxo.
        // 1. Criamos o usuário no Firebase Auth.
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: senha,
        );

        // 2. Deslogamos o usuário imediatamente. Nossa Cloud Function no backend
        // já foi acionada e já desabilitou a conta.
        await FirebaseAuth.instance.signOut();

        // 3. Exibimos uma mensagem de sucesso e orientação para o usuário.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cadastro realizado! Sua conta aguarda aprovação.'),
              backgroundColor: Colors.green,
            ),
          );

          // 4. Voltamos para o modo de login e limpamos os campos de senha.
          setState(() {
            _isLoginMode = true;
            _senhaController.clear();
            _confirmarSenhaController.clear();
          });
        }
      }

    } on FirebaseAuthException catch (e) {
      String mensagemErro = 'Ocorreu um erro. Verifique suas credenciais.';

      // NOVA LÓGICA: Capturamos o erro específico de usuário desabilitado.
      if (e.code == 'user-disabled') {
        mensagemErro = 'Sua conta está aguardando aprovação de um administrador.';
      } else if (e.code == 'weak-password') {
        mensagemErro = 'A senha é muito fraca.';
      } else if (e.code == 'email-already-in-use') {
        mensagemErro = 'Este e-mail já está em uso.';
      } else if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        mensagemErro = 'E-mail ou senha incorretos.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagemErro), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ocorreu um erro inesperado: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // O Widget build continua exatamente o mesmo, sem nenhuma alteração.
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isLoginMode ? 'Bem-vindo de Volta!' : 'Crie sua Conta',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
                      validator: (value) {
                        if (value == null || !value.contains('@')) {
                          return 'Por favor, insira um e-mail válido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _senhaController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Senha', border: OutlineInputBorder()),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'A senha deve ter no mínimo 6 caracteres.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    if (!_isLoginMode)
                      TextFormField(
                        controller: _confirmarSenhaController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Confirmar Senha', border: OutlineInputBorder()),
                        validator: (value) {
                          if (value != _senhaController.text) {
                            return 'As senhas não coincidem.';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 24),

                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      ElevatedButton(
                        onPressed: _submitAuthForm,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: Text(_isLoginMode ? 'Entrar' : 'Cadastrar'),
                      ),
                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLoginMode = !_isLoginMode;
                        });
                      },
                      child: Text(_isLoginMode ? 'Criar uma nova conta' : 'Já tenho uma conta'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
