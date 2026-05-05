// lib/services/servico_impressao_nuvem.dart
// Migrado para Repository Pattern — sem acesso direto ao Firestore.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/repositories/print_job_repository.dart';

class ServicoImpressaoNuvem {
  /// Envia um comando PPLA para a fila 'print_jobs' que o Monitor está ouvindo.
  static Future<void> enviarParaFila({
    required BuildContext context,
    required dynamic comandoPPLA,
    required String nomeImpressoraDestino,
    required PrintJobRepository repository,
  }) async {
    try {
      final usuario =
          Provider.of<UsuarioProvider>(context, listen: false).usuario;

      await repository.enviarComandoPPLA(
        comandoPPLA: comandoPPLA,
        nomeImpressora: nomeImpressoraDestino,
        usuarioNome: usuario?.nome ?? 'Desconhecido',
        empresaId: usuario?.empresaId ?? '',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enviado para $nomeImpressoraDestino!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('ServicoImpressaoNuvem erro: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}