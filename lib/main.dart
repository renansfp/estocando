// Arquivo: main.dart (COMPLETO E ATUALIZADO)

import 'package:protecin_producao/telas/home_screen.dart'; // ---> MUDANÇA 1: Importamos a nova 'home_screen2.dart'
import 'package:protecin_producao/telas/tela_login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    // 🧠 A "Grande Aula":
    // O MultiProvider "injeta" nossos "Portadores de Crachá" (Providers)
    // no topo da árvore de widgets do aplicativo.
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          // Aqui nós criamos a instância do "Portador de Crachá"
          create: (context) => UsuarioProvider(),
        ),
        // (No futuro, podemos adicionar outros providers aqui)
      ],
      // O "filho" do MultiProvider é o seu aplicativo normal.
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color azulProtecin = Color.fromRGBO(17, 52, 82, 1);
    const Color vermelhoProtecin = Color.fromRGBO(190, 32, 40, 1);
    final textTheme = Theme.of(context).textTheme;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Protecin Producao',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: azulProtecin,
          primary: azulProtecin,
          secondary: vermelhoProtecin,
          error: vermelhoProtecin,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: azulProtecin,
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: vermelhoProtecin,
          foregroundColor: Colors.white,
        ),
        textTheme: GoogleFonts.mulishTextTheme(textTheme).copyWith(
          titleLarge: GoogleFonts.mulish(textStyle: textTheme.titleLarge, fontWeight: FontWeight.bold),
          titleMedium: GoogleFonts.mulish(textStyle: textTheme.titleMedium, fontWeight: FontWeight.bold),
        ),
        useMaterial3: true,
      ),

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // ================== CÓDIGO DE DEPURAÇÃO ==================
          // Estas linhas nos dirão o que o StreamBuilder está "vendo"
          print('--- VIGIA DE AUTENTICAÇÃO ATIVADO ---');
          print('Estado da Conexão: ${snapshot.connectionState}');
          if (snapshot.hasData) {
            print('Resultado: Usuário LOGADO. ID: ${snapshot.data!.uid}');
          } else if (snapshot.hasError) {
            print('Resultado: Ocorreu um ERRO no stream: ${snapshot.error}');
          } else {
            print('Resultado: Usuário DESLOGADO.');
          }
          print('-----------------------------------------');
          // ==========================================================

          if (snapshot.connectionState == ConnectionState.waiting) {
            // O "Vigia" (Stream) ainda está esperando o Firebase Auth...
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          // --- INÍCIO DO MÓDULO 16 ---
          if (snapshot.hasData) {
            // O "Vigia" diz: "Usuário LOGADO!"

            // 🧠 A "Grande Aula":
            // Agora, perguntamos ao "Portador de Crachá" (Provider):
            // "Ok, você já carregou os DADOS desse usuário?"

            // Usamos .watch() para "escutar" o provider
            final usuarioProvider = context.watch<UsuarioProvider>();

            if (usuarioProvider.isLoading) {
              // Se o "Portador de Crachá" ainda está buscando os dados...
              // Mostramos um loading (com uma cor diferente, para depuração)
              return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.orange)));
            }

            // Se o "Vigia" diz LOGADO (snapshot.hasData)
            // E o "Portador de Crachá" diz CARREGADO (!usuarioProvider.isLoading)
            // ... SÓ ENTÃO estamos prontos para entrar!
            return const HomeScreen();
          }
          // --- FIM DO MÓDULO 16 ---

          // Se o "Vigia" (Stream) não tem dados (snapshot.hasData == false)
          // ... então o usuário está DESLOGADO.
          return const TelaLogin();
        },
      ),
    );
  }
}