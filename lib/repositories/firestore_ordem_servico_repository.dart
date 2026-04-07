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
        .map((doc) => OrdemServico.fromJson(
      doc.data(),
      doc.id,
    ))
        .toList());
  }
}