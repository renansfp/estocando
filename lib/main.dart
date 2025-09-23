import 'package:estocando/telas/tela_login.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color azulProtecin = Color.fromRGBO(17, 52, 82, 1);
    const Color vermelhoProtecin = Color.fromRGBO(190, 32, 40, 1);

    // Usamos o tema base para poder mesclar com a nova fonte
    final textTheme = Theme.of(context).textTheme;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Estocando PROTECIN',

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

        // MODIFICAÇÃO: Usando a fonte "Muli" (Mulish), uma alternativa visualmente similar
        // O método 'mulishTextTheme' existe e funciona corretamente.
        textTheme: GoogleFonts.mulishTextTheme(textTheme).copyWith(
          titleLarge: GoogleFonts.mulish(textStyle: textTheme.titleLarge, fontWeight: FontWeight.bold),
          titleMedium: GoogleFonts.mulish(textStyle: textTheme.titleMedium, fontWeight: FontWeight.bold),
        ),

        useMaterial3: true,
      ),
      home: const TelaLogin(),
    );
  }
}