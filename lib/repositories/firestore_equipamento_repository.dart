// lib/repositories/firestore_equipamento_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/models/equipamento.dart';
import 'package:protecin_producao/repositories/equipamento_repository.dart';

class FirestoreEquipamentoRepository implements EquipamentoRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _col => _db.collection('equipamentos');

  @override
  Stream<List<Equipamento>> listarPorEmpresa(String empresaId) {
    return _col
        .where('empresaId', isEqualTo: empresaId)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Equipamento.fromJson(
      doc.data() as Map<String, dynamic>,
      doc.id,
    ))
        .toList());
  }

  @override
  Stream<List<Equipamento>> listarPorCliente(String clienteId, String empresaId) {
    return _col
        .where('empresaId', isEqualTo: empresaId)
        .where('clienteId', isEqualTo: clienteId)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Equipamento.fromJson(
      doc.data() as Map<String, dynamic>,
      doc.id,
    ))
        .toList());
  }

  @override
  Future<Equipamento?> buscarPorId(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return Equipamento.fromJson(doc.data() as Map<String, dynamic>, doc.id);
  }

  @override
  Future<bool> verificarDisponibilidade(String equipamentoId) async {
    final doc = await _col.doc(equipamentoId).get();
    if (!doc.exists) return true;

    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] ?? 'ativo';
    final osAtual = data['osIdAtual'] as String?;

    final estaOcupado =
        status == 'em_manutencao' || (osAtual != null && osAtual.isNotEmpty);

    return !estaOcupado;
  }

  @override
  Future<String> criar(Equipamento equipamento) async {
    final doc = await _col.add(equipamento.toJson());
    return doc.id;
  }

  @override
  Future<void> atualizar(Equipamento equipamento) async {
    await _col.doc(equipamento.id).update(equipamento.toJson());
  }

  @override
  Future<void> liberarBloqueio(String equipamentoId) async {
    await _col.doc(equipamentoId).update({
      'status': StatusEquipamento.ativo.name,
      'osIdAtual': FieldValue.delete(),
    });
  }

  @override
  Future<void> condenar(String equipamentoId, String motivo) async {
    await _col.doc(equipamentoId).update({
      'status': StatusEquipamento.baixado.name,
      'motivoCondenacao': motivo,
      'osIdAtual': FieldValue.delete(),
    });
  }

  @override
  Future<DiagnosticoBloqueio> diagnosticarBloqueio(String equipamentoId, String osId) async {
    final docOS = await _db.collection('ordens_servico').doc(osId).get();

    if (!docOS.exists) return DiagnosticoBloqueio.osInexistente;

    final dados = docOS.data() as Map<String, dynamic>;
    final finalizada = dados['statusLote'] == 'finalizada';

    return finalizada ? DiagnosticoBloqueio.osFinalizada : DiagnosticoBloqueio.osAberta;
  }

  @override
  Future<Equipamento?> buscarPorCodigo({
    required String empresaId,
    required String clienteId,
    required String codigo,
  }) async {
    // Dispara as duas queries em paralelo em vez de sequencial.
    // Antes: query1 termina → só então começa query2 (~600ms no pior caso).
    // Agora: ambas começam juntas → resultado em ~300ms independente do caso.
    final results = await Future.wait([
      _col
          .where('empresaId', isEqualTo: empresaId)
          .where('clienteId', isEqualTo: clienteId)
          .where('ativoFixo', isEqualTo: codigo)
          .limit(1)
          .get(),
      _col
          .where('empresaId', isEqualTo: empresaId)
          .where('clienteId', isEqualTo: clienteId)
          .where('numeroCilindro', isEqualTo: codigo)
          .limit(1)
          .get(),
    ]);

    // Prioriza resultado por ativoFixo; fallback para numeroCilindro
    final snap = results[0].docs.isNotEmpty ? results[0] : results[1];
    if (snap.docs.isEmpty) return null;

    final doc = snap.docs.first;
    return Equipamento.fromJson(doc.data() as Map<String, dynamic>, doc.id);
  }
}