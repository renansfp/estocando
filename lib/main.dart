  import 'package:protecin_producao/telas/home_screen.dart';
  import 'package:protecin_producao/telas/tela_login.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:flutter/material.dart';
  import 'package:firebase_core/firebase_core.dart';
  import 'firebase_options.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:provider/provider.dart';
  import 'package:protecin_producao/provider/usuario_provider.dart';
  import 'package:protecin_producao/provider/equipamento_provider.dart';
  import 'package:protecin_producao/repositories/firestore_equipamento_repository.dart';
  import 'package:protecin_producao/provider/ordem_servico_provider.dart';
  import 'package:protecin_producao/repositories/firestore_ordem_servico_repository.dart';
  import 'package:protecin_producao/provider/item_os_provider.dart';
  import 'package:protecin_producao/repositories/firestore_item_os_repository.dart';
  import 'package:protecin_producao/repositories/requisicao_repository.dart';
  import 'package:protecin_producao/repositories/firestore_requisicao_repository.dart';
  import 'package:protecin_producao/repositories/item_os_repository.dart';
  import 'package:protecin_producao/repositories/ordem_servico_repository.dart';
  import 'package:protecin_producao/provider/produto_provider.dart';
  import 'package:protecin_producao/repositories/firestore_produto_repository.dart';
  import 'package:protecin_producao/provider/movimentacao_provider.dart';
  import 'package:protecin_producao/repositories/firestore_movimentacao_repository.dart';
  import 'package:protecin_producao/repositories/firestore_usuario_repository.dart';
  import 'package:protecin_producao/provider/parceiro_provider.dart';
  import 'package:protecin_producao/repositories/firestore_parceiro_repository.dart';
  import 'package:protecin_producao/provider/requisicao_provider.dart';
  // import 'package:protecin_producao/telas/windows/tela_servidor_impressao.dart'; // Pode comentar ou manter se tiver botão para ir pra lá

  Future<void> main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (context) => UsuarioProvider(FirestoreUsuarioRepository()),
          ),

          // NOVO — adicione estas 4 linhas:
          ChangeNotifierProvider(
            create: (context) => EquipamentoProvider(
              FirestoreEquipamentoRepository(),
            ),
          ),

          ChangeNotifierProvider(
            create: (context) => OrdemServicoProvider(
              FirestoreOrdemServicoRepository(),
            ),
          ),

          ChangeNotifierProvider(
            create: (context) => ItemOsProvider(
              FirestoreItemOsRepository(),
            ),
          ),

          Provider<RequisicaoRepository>(
            create: (context) => FirestoreRequisicaoRepository(),
          ),

          Provider<OrdemServicoRepository>(
            create: (context) => FirestoreOrdemServicoRepository(),
          ),

          Provider<ItemOsRepository>(
            create: (context) => FirestoreItemOsRepository(),
          ),
          ChangeNotifierProvider(
            create: (_) => ProdutoProvider(FirestoreProdutoRepository()),
          ),
          ChangeNotifierProvider(
            create: (_) => MovimentacaoProvider(FirestoreMovimentacaoRepository()),
          ),
          ChangeNotifierProvider(
            create: (_) => ParceiroProvider(FirestoreParceiroRepository()),
          ),
          ChangeNotifierProvider(
            create: (_) => RequisicaoProvider(FirestoreRequisicaoRepository()),
          ),
        ],
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
            titleLarge: GoogleFonts.mulish(
                textStyle: textTheme.titleLarge, fontWeight: FontWeight.bold),
            titleMedium: GoogleFonts.mulish(
                textStyle: textTheme.titleMedium, fontWeight: FontWeight.bold),
          ),
          useMaterial3: true,
        ),

        // ============================================================
        // 🔒 CÓDIGO ORIGINAL (RESTAURADO)
        // O App agora verifica se tem usuário logado.
        // Se tiver -> Vai pra Home.
        // Se não tiver -> Vai pro Login.
        // ============================================================
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }

            if (snapshot.hasData) {
              // Monitora o estado do usuário no Provider
              final usuarioProvider = context.watch<UsuarioProvider>();

              if (usuarioProvider.isLoading) {
                return const Scaffold(
                    body: Center(
                        child: CircularProgressIndicator(color: Colors.orange)));
              }

              return const HomeScreen();
            }

            return const TelaLogin();
          },
        ),
      );
    }
  }