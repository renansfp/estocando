// CÓDIGO ATUALIZADO COM "MOSTRAR/ESCONDER SENHA"

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoginMode = true;
  bool _isLoading = false;

  // ---> NOVA VARIÁVEL: Para controlar a visibilidade da senha <---
  bool _isPasswordVisible = false;

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

  Future<void> _mostrarDialogoEsqueciSenha(BuildContext context) async {
    final emailController = TextEditingController();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Redefinir Senha'),
          content: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Digite seu e-mail de cadastro',
              hintText: 'seu.email@exemplo.com',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Enviar Link'),
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isNotEmpty && email.contains('@')) {
                  try {
                    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('E-mail de redefinição enviado! Verifique sua caixa de entrada.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } on FirebaseAuthException catch (e) {
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    String mensagemErro = 'Ocorreu um erro. Tente novamente.';
                    if (e.code == 'user-not-found') {
                      mensagemErro = 'Nenhum usuário encontrado com este e-mail.';
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(mensagemErro),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor, digite um e-mail válido.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitAuthForm() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() { _isLoading = true; });

    try {
      final email = _emailController.text.trim();
      final senha = _senhaController.text.trim();

      if (_isLoginMode) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: senha);
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: senha);
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cadastro realizado! Sua conta aguarda aprovação.'), backgroundColor: Colors.green),
          );
          setState(() {
            _isLoginMode = true;
            _senhaController.clear();
            _confirmarSenhaController.clear();
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      String mensagemErro = 'Ocorreu um erro. Verifique suas credenciais.';
      if (e.code == 'user-disabled') {
        mensagemErro = 'Sua conta está aguardando aprovação de um administrador.';
      } else if (e.code == 'weak-password') {
        mensagemErro = 'A senha é muito fraca.';
      } else if (e.code == 'email-already-in-use') {
        mensagemErro = 'Este e-mail já está em uso.';
      } else if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        mensagemErro = 'E-mail ou senha incorretos.';
      }
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensagemErro), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ocorreu um erro inesperado: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      // ---> MUDANÇA 1: Trocamos 'true' pela nossa variável com '!' na frente <---
                      // O "PORQUÊ": Quando a variável for true (visível), o obscureText será false.
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        border: const OutlineInputBorder(),
                        // ---> MUDANÇA 2: Adicionamos o ícone de "olho" <---
                        suffixIcon: IconButton(
                          // O "PORQUÊ": O ícone muda dependendo se a senha está visível ou não.
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            // O "PORQUÊ": setState avisa a tela para se redesenhar com o novo valor.
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'A senha deve ter no mínimo 6 caracteres.';
                        }
                        return null;
                      },
                    ),

                    if (_isLoginMode)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _mostrarDialogoEsqueciSenha(context),
                          child: const Text('Esqueci minha senha'),
                        ),
                      ),

                    if (!_isLoginMode) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmarSenhaController,
                        // ---> MUDANÇA 3: Aplicamos a mesma lógica aqui <---
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Confirmar Senha',
                          border: const OutlineInputBorder(),
                          // ---> MUDANÇA 4: E adicionamos o mesmo ícone <---
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value != _senhaController.text) {
                            return 'As senhas não coincidem.';
                          }
                          return null;
                        },
                      ),
                    ],

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