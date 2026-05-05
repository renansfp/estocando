// lib/repositories/print_job_repository.dart

abstract class PrintJobRepository {
  /// Envia um comando PPLA bruto para a fila de impressão.
  /// O Monitor Windows consome esse job e envia para a impressora física.
  Future<void> enviarComandoPPLA({
    required dynamic comandoPPLA,
    required String nomeImpressora,
    required String usuarioNome,
    required String empresaId,
  });
}