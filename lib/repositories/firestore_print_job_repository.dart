// lib/repositories/firestore_print_job_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/repositories/print_job_repository.dart';

class FirestorePrintJobRepository implements PrintJobRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<void> enviarComandoPPLA({
    required dynamic comandoPPLA,
    required String nomeImpressora,
    required String usuarioNome,
    required String empresaId,
  }) async {
    await _db.collection('print_jobs').add({
      'printerName': nomeImpressora,
      'command_list': comandoPPLA,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'usuario_solicitante': usuarioNome,
      'empresa_id': empresaId,
    });
  }
}