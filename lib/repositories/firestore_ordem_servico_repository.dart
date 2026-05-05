// lib/repositories/firestore_ordem_servico_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/models/item_os.dart';
import 'package:protecin_producao/models/ordem_servico.dart';
import 'package:protecin_producao/models/parceiro.dart';
import 'package:protecin_producao/repositories/ordem_servico_repository.dart';

class FirestoreOrdemServicoRepository implements OrdemServicoRepository {
  final FirebaseFirestore _db;

  FirestoreOrdemServicoRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  // Converte todos os Timestamp do Firestore para DateTime antes de entregar
  // para as telas. Assim nenhuma tela precisa importar cloud_firestore.
  Map<String, dynamic> _convertTimestamps(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (value is Timestamp) return MapEntry(key, value.toDate());
      if (value is Map<String, dynamic>) {
        return MapEntry(key, _convertTimestamps(value));
      }
      if (value is List) {
        return MapEntry(key, value.map((e) {
          if (e is Timestamp) return e.toDate();
          if (e is Map<String, dynamic>) return _convertTimestamps(e);
          return e;
        }).toList());
      }
      return MapEntry(key, value);
    });
  }

  Map<String, dynamic> _toMap(DocumentSnapshot doc) {
    final raw = <String, dynamic>{
      'id': doc.id,
      ...(doc.data() as Map<String, dynamic>? ?? {}),
    };
    return _convertTimestamps(raw);
  }

  @override
  Future<String> criarOS({
    required OrdemServico os,
    required List<ItemOS> itens,
    required Parceiro cliente,
    required String observacoes,
  }) async {
    final batch = _db.batch();
    final configRef = _db.collection('config').doc('contadores');

    // Lê o contador atual
    final configDoc = await configRef.get();
    int proximoNumero = 1;
    if (configDoc.exists && configDoc.data()!.containsKey('ultima_os')) {
      final val = configDoc.get('ultima_os');
      proximoNumero = (val is int ? val : int.tryParse(val.toString()) ?? 0) + 1;
    }
    final String idFormatado = proximoNumero.toString().padLeft(5, '0');

    // Prepara a OS
    final osRef = _db.collection('ordens_servico').doc(idFormatado);
    final osMap = os.toJson();
    osMap['id'] = idFormatado;
    osMap['numeroOS'] = idFormatado;
    osMap['statusLote'] = 'na_descarga';
    osMap['etapaAtual'] = 'descarga';
    osMap['quantidadeTotal'] = itens.length;
    osMap['numeroSequencial'] = proximoNumero;
    osMap['observacoes'] = observacoes;
    batch.set(osRef, osMap);

    // Prepara os itens e atualiza equipamentos
    for (final item in itens) {
      final itemRef = _db.collection('itens_os').doc();
      final itemJson = item.toJson();
      itemJson['osId'] = idFormatado;
      itemJson['numeroOS'] = idFormatado;
      itemJson['clienteNome'] = cliente.nome;
      itemJson['status'] = 'aguardando_descarga';
      itemJson['statusAtual'] = 'emProducao';
      itemJson['dataEntrada'] = FieldValue.serverTimestamp();
      batch.set(itemRef, itemJson);

      final equipRef = _db.collection('equipamentos').doc(item.equipamentoId);
      batch.set(equipRef, {
        'status': 'em_manutencao',
        'osIdAtual': idFormatado,
        'itemIdAtual': itemRef.id,
      }, SetOptions(merge: true));
    }

    // Atualiza o contador
    batch.set(configRef, {'ultima_os': proximoNumero}, SetOptions(merge: true));

    await batch.commit();
    return idFormatado;
  }

  @override
  Stream<List<OrdemServico>> listarPorEmpresa(String empresaId) {
    return _db
        .collection('ordens_servico')
        .where('empresaId', isEqualTo: empresaId)
        .snapshots()
        .map((snap) => snap.docs
        .map((doc) => OrdemServico.fromJson(doc.data(), doc.id))
        .toList());
  }

  @override
  Stream<List<Map<String, dynamic>>> streamTodasOrdenadas() {
    return _db
        .collection('ordens_servico')
        .orderBy('dataEntrada', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(_toMap).toList());
  }

  // ─── Novo método ─────────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>?> buscarPorNumero(
      String empresaId, String numeroOS) async {
    // Tenta com o número exato primeiro
    var query = await _db
        .collection('ordens_servico')
        .where('empresaId', isEqualTo: empresaId)
        .where('numeroOS', isEqualTo: numeroOS)
        .limit(1)
        .get();

    // Se não encontrou e o número é curto, tenta com zero-padding (ex: "105" → "00105")
    if (query.docs.isEmpty && numeroOS.length < 5) {
      query = await _db
          .collection('ordens_servico')
          .where('empresaId', isEqualTo: empresaId)
          .where('numeroOS', isEqualTo: numeroOS.padLeft(5, '0'))
          .limit(1)
          .get();
    }

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    return {'id': doc.id, ...doc.data()};
  }

  @override
  Stream<Map<String, dynamic>?> streamPorId(String osId) {
    return _db
        .collection('ordens_servico')
        .doc(osId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return _toMap(doc);
    });
  }


  @override
  Future<OrdemServico?> buscarPorId(String osId) async {
    final doc = await _db.collection('ordens_servico').doc(osId).get();
    if (!doc.exists) return null;
    return OrdemServico.fromJson(doc.data() as Map<String, dynamic>, doc.id);
  }
}