import 'package:flutter/material.dart';
import 'package:estocando/telas/tela_home.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _usuarioController = TextEditingController();
  final _senhaController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login - Almoxarife'),
        backgroundColor: Colors.blueGrey,
      ),
      // Adicionamos um Padding para dar um respiro nas bordas
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        // O Widget Column empilha os outros widgets verticalmente
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Centraliza a coluna na tela
          children: [
            // Campo de texto para o usuário
            TextField(
              controller: _usuarioController,
              decoration: InputDecoration(
                labelText: 'Usuário',
                border: OutlineInputBorder(),
              ),
            ),

            // Um espaço vertical entre os campos
            const SizedBox(height: 20),

            // Campo de texto para a senha
            TextField(
              controller: _senhaController,
              obscureText: true, // Isso faz o texto virar "bolinhas"
              decoration: InputDecoration(
                labelText: 'Senha',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 30),

            // Botão de Entrar
            ElevatedButton(
              onPressed: () {
                final String usuario = _usuarioController.text;
                final String senha = _senhaController.text;

                // 1. Lógica de validação
                if (usuario == 'almoxarife' && senha == '123') {
                  // 2. Navegar para a próxima tela em caso de sucesso
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TelaHome()),
                  );
                } else {
                  // 3. Mostrar mensagem de erro
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Usuário ou senha incorretos!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50), // Faz o botão ocupar toda a largura
              ),
              child: const Text('Entrar'),
            ),
          ],
        ),
      ),
    );
  }
}