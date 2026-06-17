// lib/repositories/firestore_ordem_servico_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/models/item_os.dart';
import 'package:protecin_producao/models/ordem_servico.dart';
import 'package:protecin_producao/models/parceiro.dart';
import 'package:protecin_producao/repositories/ordem_servico_repository.dart';
import 'package:protecin_producao/utils/firestore_utils.dart';

class FirestoreOrdemServicoRepository implements OrdemServicoRepository {
  final FirebaseFirestore _db;

  FirestoreOrdemServicoRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  Map<String, dynamic> _toMap(DocumentSnapshot doc) {
    final raw = <String, dynamic>{
      'id': doc.id,
      ...(doc.data() as Map<String, dynamic>? ?? {}),
    };
    return convertTimestamps(raw);
  }

  @override
  Future<String> criarOS({
    required OrdemServico os,
    required List<ItemOS> itens,
    required Parceiro cliente,
    required String observacoes,
  }) async {
    if (itens.length > 249) {
      throw Exception(
        'Uma OS não pode ter mais de 249 itens. '
            'Divida em duas OS se necessário.',
      );
    }

    final configRef = _db.collection('config').doc('contadores');

    late String idFormatado;

    await _db.runTransaction((transaction) async {
      // ── 1. Lê o contador DENTRO da transação ─────────────────────────────
      final configDoc = await transaction.get(configRef);
      int proximoNumero = 1;
      if (configDoc.exists &&
          (configDoc.data() as Map<String, dynamic>?)
              ?.containsKey('ultima_os') ==
              true) {
        final val = configDoc.get('ultima_os');
        proximoNumero =
            (val is int ? val : int.tryParse(val.toString()) ?? 0) + 1;
      }
      idFormatado = proximoNumero.toString().padLeft(5, '0');

      // ── 2. Cria o documento da OS ─────────────────────────────────────────
      final osRef = _db.collection('ordens_servico').doc(idFormatado);
      final osMap = os.toJson();
      osMap['id'] = idFormatado;
      osMap['numeroOS'] = idFormatado;
      osMap['statusLote'] = 'na_descarga';
      osMap['etapaAtual'] = 'descarga';
      osMap['quantidadeTotal'] = itens.length;
      osMap['numeroSequencial'] = proximoNumero;
      osMap['observacoes'] = observacoes;
      osMap['pendentes'] = {'aguardando_descarga': itens.length};
      transaction.set(osRef, osMap);

      // ── 3. Gera as referências dos itens DENTRO da transação ──────────────
      // Só agora conhecemos o idFormatado, então as refs da subcoleção
      // são geradas aqui. doc() sem argumento é operação local — sem rede.
      final itenRefs = List.generate(
        itens.length,
            (_) => _db
            .collection('ordens_servico')
            .doc(idFormatado)
            .collection('itens')
            .doc(),
      );

      // ── 4. Cria os itens na subcoleção e atualiza os equipamentos ─────────
      for (int i = 0; i < itens.length; i++) {
        final item = itens[i];
        final itemRef = itenRefs[i];

        final itemJson = item.toJson();
        itemJson['osId'] = idFormatado;       // mantido para collectionGroup
        itemJson['numeroOS'] = idFormatado;
        itemJson['clienteNome'] = cliente.nome;
        itemJson['status'] = 'aguardando_descarga';
        itemJson['statusAtual'] = 'emProducao';
        itemJson['dataEntrada'] = FieldValue.serverTimestamp();
        transaction.set(itemRef, itemJson);

        final equipRef =
        _db.collection('equipamentos').doc(item.equipamentoId);
        transaction.set(
          equipRef,
          {
            'status': 'em_manutencao',
            'osIdAtual': idFormatado,
            'itemIdAtual': itemRef.id,
          },
          SetOptions(merge: true),
        );
      }

      // ── 5. Atualiza o contador de OS e os contadores do dashboard ────────
      transaction.set(
        configRef,
        {'ultima_os': proximoNumero},
        SetOptions(merge: true),
      );

      // descarga += N — o documento é criado se não existir (merge: true)
      final contadoresRef = _db.collection('contadores').doc(os.empresaId);
      transaction.set(
        contadoresRef,
        {'descarga': FieldValue.increment(itens.length)},
        SetOptions(merge: true),
      );
    });

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
  Stream<List<Map<String, dynamic>>> streamTodasOrdenadas(
      String empresaId, {
        bool somentAbertas = false,
      }) {
    Query<Map<String, dynamic>> query = _db
        .collection('ordens_servico')
        .where('empresaId', isEqualTo: empresaId);

    if (somentAbertas) {
      query = query.where('dataEncerramento', isNull: true);
    }

    return query
        .orderBy('dataEntrada', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(_toMap).toList());
  }

  @override
  Future<List<Map<String, dynamic>>> buscarOSAbertas(String empresaId) async {
    final snap = await _db
        .collection('ordens_servico')
        .where('empresaId', isEqualTo: empresaId)
        .where('dataEncerramento', isNull: true)
        .get();
    return snap.docs.map(_toMap).toList();
  }

  @override
  Future<Map<String, dynamic>?> buscarPorNumero(
      String empresaId, String numeroOS) async {
    var query = await _db
        .collection('ordens_servico')
        .where('empresaId', isEqualTo: empresaId)
        .where('numeroOS', isEqualTo: numeroOS)
        .limit(1)
        .get();

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