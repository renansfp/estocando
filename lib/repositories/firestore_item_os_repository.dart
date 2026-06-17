// lib/repositories/firestore_item_os_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:protecin_producao/repositories/item_os_repository.dart';
import 'package:protecin_producao/utils/firestore_utils.dart';

class FirestoreItemOsRepository implements ItemOsRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Helper central ───────────────────────────────────────────────────────
  // Retorna a referência da subcoleção de itens de uma OS específica.
  // Todas as operações que conhecem o osId usam este atalho.
  CollectionReference<Map<String, dynamic>> _itensRef(String osId) =>
      _db.collection('ordens_servico').doc(osId).collection('itens');

  // Referência para o documento de contadores da empresa no dashboard.
  DocumentReference<Map<String, dynamic>> _contadoresRef(String empresaId) =>
      _db.collection('contadores').doc(empresaId);

  // Mapeia qualquer status de item para a chave do contador no dashboard.
  // Retorna '' para statuses fora do fluxo (condenado, entregue, etc.).
  static String _chaveContador(String status) {
    if (status == 'aguardando_descarga' || status == 'descarga_concluida') return 'descarga';
    if (status == 'aguardando_limpeza') return 'limpeza';
    if (status == 'aguardando_lixa') return 'lixa';
    if (status.startsWith('aguardando_manutencao')) return 'manutencao';
    if (status.startsWith('aguardando_saque')) return 'saque';
    if (status == 'aguardando_th') return 'teste';
    if (status == 'aguardando_pintura') return 'pintura';
    if (status.startsWith('aguardando_valvula_po')) return 'valvulaPo';
    if (status.startsWith('aguardando_recarga')) return 'recarga';
    if (status.startsWith('aguardando_estanqueidade')) return 'estanqueidade';
    if (status == 'aguardando_pre_montagem') return 'premontagem';
    if (status == 'aguardando_montagem') return 'montagem';
    if (status == 'aguardando_expedicao') return 'expedicao';
    return ''; // condenado, entregue, finalizado — não contabilizado
  }

  // Monta o map de incremento/decremento para o doc de contadores.
  // Chamado dentro de transactions e batches.
  static Map<String, dynamic> _deltaContadores(String statusSaiu, String statusEntrou) {
    final Map<String, dynamic> delta = {};
    final chaveSaiu = _chaveContador(statusSaiu);
    final chaveEntrou = _chaveContador(statusEntrou);
    if (chaveSaiu.isNotEmpty) delta[chaveSaiu] = FieldValue.increment(-1);
    if (chaveEntrou.isNotEmpty && chaveEntrou != chaveSaiu) {
      delta[chaveEntrou] = FieldValue.increment(1);
    } else if (chaveEntrou.isNotEmpty && chaveEntrou == chaveSaiu) {
      // mesma chave — os incrementos se cancelam, não grava nada
      delta.remove(chaveSaiu);
    }
    return delta;
  }

  // Converte todos os Timestamp do Firestore para DateTime antes de entregar
  // para as telas. Assim nenhuma tela precisa importar cloud_firestore.
  Map<String, dynamic> _toMap(DocumentSnapshot doc) {
    final raw = <String, dynamic>{
      'id': doc.id,
      ...(doc.data() as Map<String, dynamic>? ?? {}),
    };
    return convertTimestamps(raw);
  }

  // ─── Contadores ───────────────────────────────────────────────────────────

  @override
  Stream<Map<String, int>> streamDocumentoContadores(String empresaId) {
    return _db
        .collection('contadores')
        .doc(empresaId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        debugPrint(
            'streamDocumentoContadores: documento contadores/$empresaId não existe ainda.');
        return <String, int>{};
      }
      final data = doc.data() as Map<String, dynamic>? ?? {};
      return data.map(
            (chave, valor) => MapEntry(chave, (valor as num?)?.toInt() ?? 0),
      );
    });
  }

  // ─── Streams globais (collectionGroup) ───────────────────────────────────
  // Usados por telas de fábrica que exibem itens de TODAS as OSs abertas.
  // Requerem índices compostos no Firebase — o log do app fornece os links.

  @override
  Stream<List<Map<String, dynamic>>> streamItensEmProducao(String empresaId) {
    return _db
        .collectionGroup('itens')
        .where('empresaId', isEqualTo: empresaId)
        .where('statusAtual', isEqualTo: 'emProducao')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList());
  }

  @override
  Stream<List<Map<String, dynamic>>> streamItensAguardandoDescarga(
      String empresaId, List<String> filtrosAgente) {
    return _db
        .collectionGroup('itens')
        .where('empresaId', isEqualTo: empresaId)
        .where('status', isEqualTo: 'aguardando_descarga')
        .where('tipoAgente', whereIn: filtrosAgente)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList());
  }

  @override
  Stream<List<Map<String, dynamic>>> streamItensDescarga(String empresaId) {
    return _db
        .collectionGroup('itens')
        .where('empresaId', isEqualTo: empresaId)
        .where('status', whereIn: ['aguardando_descarga', 'descarga_concluida'])
        .snapshots()
        .map((snap) => snap.docs
        .map((doc) => <String, dynamic>{
      'id': doc.id,
      ...doc.data(),
    })
        .toList());
  }

  // ─── Streams por OS (acesso direto via subcoleção) ────────────────────────

  @override
  Stream<List<Map<String, dynamic>>> streamItensPorOs(String osId) {
    return _itensRef(osId)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList());
  }

  @override
  Stream<List<Map<String, dynamic>>> streamItensPorOsEStatus(
      String osId, String status, String empresaId) {
    // empresaId mantido na assinatura por compatibilidade mas não é necessário
    // na query: a subcoleção já está isolada pelo caminho da OS.
    return _itensRef(osId)
        .where('status', isEqualTo: status)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList());
  }

  @override
  Stream<List<Map<String, dynamic>>> streamItensDescargaOsPorAgente(
      String osId, List<String> filtrosAgente) {
    Query<Map<String, dynamic>> query = _itensRef(osId)
        .where('status', isEqualTo: 'aguardando_descarga');

    if (filtrosAgente.isNotEmpty) {
      query = query.where('tipoAgente', whereIn: filtrosAgente);
    }

    return query.snapshots().map((snap) => snap.docs
        .map((doc) => <String, dynamic>{
      'id': doc.id,
      ...doc.data(),
    })
        .toList());
  }

  // ─── Buscas pontuais ──────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>?> buscarItemPorCracha(
      String osId, String cracha, String status, String empresaId) async {
    final query = await _itensRef(osId)
        .where('idCrachaTemporario', isEqualTo: cracha)
        .where('status', isEqualTo: status)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    return {'id': doc.id, ...doc.data()};
  }

  @override
  Future<Map<String, dynamic>?> buscarItemPorCrachaEOsId(
      String osId, String cracha, String empresaId) async {
    final query = await _itensRef(osId)
        .where('idCrachaTemporario', isEqualTo: cracha)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    return {'id': doc.id, ...doc.data()};
  }

  @override
  Future<Map<String, dynamic>?> buscarItemPorId(
      String itemId, String osId) async {
    final doc = await _itensRef(osId).doc(itemId).get();
    if (!doc.exists) return null;
    return _toMap(doc);
  }

  @override
  Future<List<Map<String, dynamic>>> buscarItensComDadosCompletos(
      String osId) async {
    final snap = await _itensRef(osId).get();
    return snap.docs.map(_toMap).toList();
  }

  // ─── Confirmações de etapa ────────────────────────────────────────────────

  @override
  Future<void> confirmarEtapa({
    required String itemId,
    required Map<String, dynamic> dadosItem,
    required String osId,
    required String statusPendente,
    required String proximaEstacao,
    required String empresaId,
    Map<String, dynamic>? dadosOsExtra,
  }) async {
    final itemRef = _itensRef(osId).doc(itemId);
    final osRef = _db.collection('ordens_servico').doc(osId);
    final contRef = _contadoresRef(empresaId);

    await _db.runTransaction((transaction) async {
      final osDoc = await transaction.get(osRef);
      final placar = Map<String, dynamic>.from(
        (osDoc.data() as Map<String, dynamic>?)?['pendentes'] ?? {},
      );

      final int anterior = (placar[statusPendente] as num?)?.toInt() ?? 0;
      final int novo = (anterior - 1).clamp(0, 99999);

      transaction.update(itemRef, {
        'status': 'aguardando_$proximaEstacao',
        ...dadosItem,
      });

      final Map<String, dynamic> osUpdate = {
        'pendentes.$statusPendente': novo,
        'pendentes.aguardando_$proximaEstacao': FieldValue.increment(1),
      };
      if (novo <= 0) {
        osUpdate['etapaAtual'] = proximaEstacao;
        if (dadosOsExtra != null) osUpdate.addAll(dadosOsExtra);
      }
      transaction.update(osRef, osUpdate);

      final delta = _deltaContadores(statusPendente, 'aguardando_$proximaEstacao');
      if (delta.isNotEmpty) transaction.set(contRef, delta, SetOptions(merge: true));
    });
  }

  @override
  Future<void> confirmarTriagem({
    required String itemId,
    required String osId,
    required List<String> roteiro,
    required String proximoStatus,
    required String proximaEstacao,
    required bool precisaPintura,
    required bool testeVencido,
    required String operador,
    required String empresaId,
  }) async {
    final itemRef = _itensRef(osId).doc(itemId);
    final osRef = _db.collection('ordens_servico').doc(osId);
    final contRef = _contadoresRef(empresaId);

    await _db.runTransaction((transaction) async {
      final osDoc = await transaction.get(osRef);
      final placar = Map<String, dynamic>.from(
        (osDoc.data() as Map<String, dynamic>?)?['pendentes'] ?? {},
      );

      const statusAtual = 'aguardando_limpeza';
      final int anterior = (placar[statusAtual] as num?)?.toInt() ?? 0;
      final int novo = (anterior - 1).clamp(0, 99999);

      transaction.update(itemRef, {
        'status': proximoStatus,
        'statusAtual': 'emProducao',
        'roteiro': roteiro,
        'triagem': {
          'precisaPintura': precisaPintura,
          'testeVencido': testeVencido,
          'data': FieldValue.serverTimestamp(),
          'operador': operador,
        },
      });

      final Map<String, dynamic> osUpdate = {
        'pendentes.$statusAtual': novo,
        'pendentes.$proximoStatus': FieldValue.increment(1),
      };
      if (novo <= 0) {
        osUpdate['etapaAtual'] = proximaEstacao;
        osUpdate['statusLote'] = 'em_producao';
        osUpdate['dataFimLimpeza'] = FieldValue.serverTimestamp();
      }
      transaction.update(osRef, osUpdate);

      final delta = _deltaContadores(statusAtual, proximoStatus);
      if (delta.isNotEmpty) transaction.set(contRef, delta, SetOptions(merge: true));
    });
  }

  @override
  Future<void> confirmarDescargaItem(
      String itemOsId, String osId, String operador) async {
    await _itensRef(osId).doc(itemOsId).update({
      'status': 'descarga_concluida',
      'dataDescarga': FieldValue.serverTimestamp(),
      'realizadoPor': operador,
    });
  }

  @override
  Future<void> confirmarDescargaPorCracha(
      String osId, String idCracha, String operador, String empresaId) async {
    final query = await _itensRef(osId)
        .where('idCrachaTemporario', isEqualTo: idCracha)
        .where('status', isEqualTo: 'aguardando_descarga')
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Crachá não encontrado nesta OS ou já baixado.');
    }

    final itemRef = query.docs.first.reference;
    final osRef = _db.collection('ordens_servico').doc(osId);
    final contRef = _contadoresRef(empresaId);

    await _db.runTransaction((transaction) async {
      final osDoc = await transaction.get(osRef);
      final placar = Map<String, dynamic>.from(
        (osDoc.data() as Map<String, dynamic>?)?['pendentes'] ?? {},
      );

      const statusAtual = 'aguardando_descarga';
      final int anterior = (placar[statusAtual] as num?)?.toInt() ?? 0;
      final int novo = (anterior - 1).clamp(0, 99999);

      transaction.update(itemRef, {
        'status': 'aguardando_limpeza',
        'dataDescarga': FieldValue.serverTimestamp(),
        'realizadoPor': operador,
      });

      final Map<String, dynamic> osUpdate = {
        'pendentes.$statusAtual': novo,
        'pendentes.aguardando_limpeza': FieldValue.increment(1),
      };
      if (novo <= 0) {
        osUpdate['etapaAtual'] = 'limpeza';
        osUpdate['statusLote'] = 'na_limpeza';
        osUpdate['dataFimDescarga'] = FieldValue.serverTimestamp();
      }
      transaction.update(osRef, osUpdate);

      final delta = _deltaContadores(statusAtual, 'aguardando_limpeza');
      if (delta.isNotEmpty) transaction.set(contRef, delta, SetOptions(merge: true));
    });
  }

  // ─── Lote / liberação ─────────────────────────────────────────────────────

  @override
  Future<void> liberarLotePremontagem({
    required String osId,
    required List<Map<String, dynamic>> itens,
    required String operador,
    required String empresaId,
  }) async {
    final batch = _db.batch();
    String proximaDaOS = 'montagem';
    final Map<String, int> novosContadores = {};
    final Map<String, int> deltaContEmpresa = {};

    for (int i = 0; i < itens.length; i++) {
      final item = itens[i];
      final List<String> roteiro = List<String>.from(item['roteiro'] ?? []);
      int indexAtual = roteiro.indexOf('pre_montagem');
      String proxima = (indexAtual != -1 && indexAtual < roteiro.length - 1)
          ? roteiro[indexAtual + 1]
          : 'montagem';

      if (i == itens.length - 1) proximaDaOS = proxima;

      novosContadores['aguardando_$proxima'] =
          (novosContadores['aguardando_$proxima'] ?? 0) + 1;

      // delta empresa: premontagem -= 1, chave(proxima) += 1
      deltaContEmpresa['premontagem'] = (deltaContEmpresa['premontagem'] ?? 0) - 1;
      final chaveProx = _chaveContador('aguardando_$proxima');
      if (chaveProx.isNotEmpty) {
        deltaContEmpresa[chaveProx] = (deltaContEmpresa[chaveProx] ?? 0) + 1;
      }

      batch.update(_itensRef(osId).doc(item['id']), {
        'status': 'aguardando_$proxima',
        'premontagem': {
          'data': FieldValue.serverTimestamp(),
          'operador': operador,
        },
      });
    }

    final Map<String, dynamic> osUpdate = {'etapaAtual': proximaDaOS};
    novosContadores.forEach((status, count) {
      osUpdate['pendentes.$status'] = count;
    });

    batch.update(_db.collection('ordens_servico').doc(osId), osUpdate);

    final Map<String, dynamic> contUpdate = {};
    deltaContEmpresa.forEach((chave, delta) {
      contUpdate[chave] = FieldValue.increment(delta);
    });
    if (contUpdate.isNotEmpty) {
      batch.set(_contadoresRef(empresaId), contUpdate, SetOptions(merge: true));
    }

    await batch.commit();
  }

  @override
  Future<void> liberarLoteParaLimpeza({
    required String osId,
    required List<String> itemIds,
    required String empresaId,
  }) async {
    final batch = _db.batch();
    for (final id in itemIds) {
      batch.update(_itensRef(osId).doc(id), {
        'status': 'aguardando_limpeza',
        'historico_descarga': FieldValue.serverTimestamp(),
      });
    }
    batch.update(_db.collection('ordens_servico').doc(osId), {
      'etapaAtual': 'limpeza',
      'statusLote': 'na_limpeza',
      'pendentes.aguardando_limpeza': itemIds.length,
    });
    // descarga -= N, limpeza += N
    batch.set(_contadoresRef(empresaId), {
      'descarga': FieldValue.increment(-itemIds.length),
      'limpeza': FieldValue.increment(itemIds.length),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  @override
  Future<void> reverterLote({
    required String osId,
    required String empresaId,
    required String statusAtual,
    required String statusAnterior,
    required Map<String, dynamic> dadosOS,
    String Function(Map<String, dynamic>)? statusAnteriorFn,
  }) async {
    final snapshot = await _itensRef(osId)
        .where('status', isEqualTo: statusAtual)
        .get();

    final batch = _db.batch();
    final Map<String, int> contadorDestinos = {};

    for (var doc in snapshot.docs) {
      final destino = statusAnteriorFn != null
          ? statusAnteriorFn(doc.data())
          : statusAnterior;
      batch.update(doc.reference, {'status': destino});
      contadorDestinos[destino] = (contadorDestinos[destino] ?? 0) + 1;
    }

    final Map<String, dynamic> osUpdate = {
      ...dadosOS,
      'pendentes.$statusAtual': 0,
    };
    for (final entry in contadorDestinos.entries) {
      osUpdate['pendentes.${entry.key}'] = FieldValue.increment(entry.value);
    }

    batch.update(_db.collection('ordens_servico').doc(osId), osUpdate);

    // Contadores empresa: statusAtual -= total, distribuir por destino
    final Map<String, dynamic> contUpdate = {};
    int totalItens = 0;
    for (final entry in contadorDestinos.entries) {
      final chaveDest = _chaveContador(entry.key);
      if (chaveDest.isNotEmpty) {
        contUpdate[chaveDest] = FieldValue.increment(entry.value);
      }
      totalItens += entry.value;
    }
    final chaveAtual = _chaveContador(statusAtual);
    if (chaveAtual.isNotEmpty) {
      contUpdate[chaveAtual] = FieldValue.increment(-totalItens);
    }
    if (contUpdate.isNotEmpty) {
      batch.set(_contadoresRef(empresaId), contUpdate, SetOptions(merge: true));
    }

    await batch.commit();
  }

  @override
  Future<void> reverterParaDescarga(String osId, String empresaId) async {
    // empresaId mantido na assinatura por compatibilidade — não necessário
    // na query pois a subcoleção já está isolada pelo caminho.
    final query = await _itensRef(osId)
        .where('status', isEqualTo: 'aguardando_limpeza')
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Nenhum item dessa OS está na Limpeza.');
    }

    final batch = _db.batch();
    for (final doc in query.docs) {
      batch.update(doc.reference, {'status': 'aguardando_descarga'});
    }
    batch.update(_db.collection('ordens_servico').doc(osId), {
      'etapaAtual': 'descarga',
      'statusLote': 'em_descarga',
      'pendentes.aguardando_limpeza': 0,
      'pendentes.aguardando_descarga': query.docs.length,
    });
    batch.set(_contadoresRef(empresaId), {
      'limpeza': FieldValue.increment(-query.docs.length),
      'descarga': FieldValue.increment(query.docs.length),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  // ─── Expedição ────────────────────────────────────────────────────────────

  @override
  Future<void> expedirItem({
    required String itemId,
    required String osId,
    required String idCracha,
    required String? equipId,
    required String empresaId,
  }) async {
    final dataAtual =
        '${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}';

    final itemRef = _itensRef(osId).doc(itemId);
    final osRef = _db.collection('ordens_servico').doc(osId);

    final queryCracha = await _db
        .collection('crachas')
        .where('idCracha', isEqualTo: idCracha)
        .limit(1)
        .get();

    await _db.runTransaction((transaction) async {
      final osDoc = await transaction.get(osRef);
      final placar = Map<String, dynamic>.from(
        (osDoc.data() as Map<String, dynamic>?)?['pendentes'] ?? {},
      );

      const statusAtual = 'aguardando_expedicao';
      final int anterior = (placar[statusAtual] as num?)?.toInt() ?? 0;
      final int novo = (anterior - 1).clamp(0, 99999);

      transaction.update(itemRef, {
        'status': 'entregue',
        'statusAtual': 'finalizado',
        'dataExpedicao': FieldValue.serverTimestamp(),
      });

      if (equipId != null && equipId.isNotEmpty) {
        transaction.update(_db.collection('equipamentos').doc(equipId), {
          'status': 'ativo',
          'osIdAtual': FieldValue.delete(),
          'itemIdAtual': FieldValue.delete(),
          'ultimaRecarga': dataAtual,
        });
      }

      if (queryCracha.docs.isNotEmpty) {
        transaction.update(queryCracha.docs.first.reference, {
          'status': 'disponivel',
          'itemOsIdAtual': FieldValue.delete(),
          'osIdAtual': FieldValue.delete(),
        });
      }

      final Map<String, dynamic> osUpdate = {
        'pendentes.$statusAtual': novo,
      };
      if (novo <= 0) {
        osUpdate['etapaAtual'] = 'finalizado';
        osUpdate['statusLote'] = 'entregue_ao_cliente';
        osUpdate['dataEncerramento'] = FieldValue.serverTimestamp();
      }
      transaction.update(osRef, osUpdate);

      // expedicao -= 1 (item sai do fluxo ao ser entregue)
      transaction.set(_contadoresRef(empresaId), {
        'expedicao': FieldValue.increment(-1),
      }, SetOptions(merge: true));
    });
  }

  // ─── Reprova / condenação ─────────────────────────────────────────────────

  @override
  Future<void> reprovarItem({
    required String itemId,
    required String osId,
    required String statusAtual,
    required String statusDestino,
    required Map<String, dynamic> dadosFalha,
    required String empresaId,
  }) async {
    final batch = _db.batch();
    batch.update(_itensRef(osId).doc(itemId), {
      'status': statusDestino,
      ...dadosFalha,
    });
    final delta = _deltaContadores(statusAtual, statusDestino);
    if (delta.isNotEmpty) {
      batch.set(_contadoresRef(empresaId), delta, SetOptions(merge: true));
    }
    await batch.commit();
  }

  @override
  Future<void> condenarItem({
    required String itemId,
    required Map<String, dynamic> item,
    required String etapa,
    required String motivo,
    required String empresaId,
  }) async {
    final batch = _db.batch();
    final String? osId = item['osId'] as String?;
    final String? statusAtual = item['status'] as String?;

    if (osId == null || osId.isEmpty) {
      throw Exception('condenarItem: osId ausente no item — impossível localizar na subcoleção.');
    }

    batch.update(_itensRef(osId).doc(itemId), {
      'status': 'condenado',
      'statusAtual': 'condenado',
      'motivoCondenacao': motivo,
      etapa: {
        'data': FieldValue.serverTimestamp(),
        'resultado': 'CONDENADO',
        'motivo': motivo,
      },
    });

    final equipId = item['equipamentoId'];
    if (equipId != null && equipId.toString().isNotEmpty) {
      batch.update(
        _db.collection('equipamentos').doc(equipId as String),
        {
          'status': 'baixado',
          'motivoCondenacao': motivo,
          'dataBaixa': FieldValue.serverTimestamp(),
          'osIdAtual': FieldValue.delete(),
          'itemIdAtual': FieldValue.delete(),
        },
      );
    }

    if (statusAtual != null) {
      batch.update(_db.collection('ordens_servico').doc(osId), {
        'pendentes.$statusAtual': FieldValue.increment(-1),
      });
      final chave = _chaveContador(statusAtual);
      if (chave.isNotEmpty) {
        batch.set(_contadoresRef(empresaId), {
          chave: FieldValue.increment(-1),
        }, SetOptions(merge: true));
      }
    }

    await batch.commit();
  }

  // ─── Ensaio hidrostático ──────────────────────────────────────────────────

  @override
  Future<void> finalizarEnsaioTH({
    required String itemId,
    required String osId,
    required String? equipamentoId,
    required bool aprovado,
    required String proximaEtapa,
    required Map<String, dynamic> dadosTH,
    Map<String, dynamic>? updatesEquipamento,
    required String empresaId,
  }) async {
    final batch = _db.batch();

    batch.update(_itensRef(osId).doc(itemId), {
      'status': aprovado ? 'aguardando_$proximaEtapa' : 'condenado',
      'dadosTH': {
        ...dadosTH,
        'data': FieldValue.serverTimestamp(),
      },
    });

    if (equipamentoId != null &&
        equipamentoId.isNotEmpty &&
        updatesEquipamento != null) {
      final updatesFinais = aprovado
          ? {...updatesEquipamento, 'motivoCondenacao': FieldValue.delete()}
          : updatesEquipamento;
      batch.update(
        _db.collection('equipamentos').doc(equipamentoId),
        updatesFinais,
      );
    }

    // teste -= 1 sempre; se aprovado, chave(próxima) += 1
    final Map<String, dynamic> contUpdate = {'teste': FieldValue.increment(-1)};
    if (aprovado) {
      final chaveProx = _chaveContador('aguardando_$proximaEtapa');
      if (chaveProx.isNotEmpty) contUpdate[chaveProx] = FieldValue.increment(1);
    }
    batch.set(_contadoresRef(empresaId), contUpdate, SetOptions(merge: true));

    await batch.commit();
  }

  // ─── Recarga ──────────────────────────────────────────────────────────────

  @override
  Future<void> processarRecarga({
    required String itemId,
    required String osId,
    required String equipamentoId,
    required String idCrachaTemporario,
    required bool substituirPo,
    required bool isPo,
    required double pesoCarga,
    required double pesoFinalRegistrado,
    required String agente,
    required String loteFinal,
    required String tipoRegistro,
    required String? loteSelecionadoId,
    required String? produtoId,
    required String? clienteNome,
    required String cc,
    required String operador,
    required String empresaId,
    required String statusAtualItem,
  }) async {
    final batch = _db.batch();
    final dataAtual =
        '${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}';

    if (isPo && substituirPo && loteSelecionadoId != null && produtoId != null) {
      batch.update(
        _db.collection('produtos').doc(produtoId).collection('lotes').doc(loteSelecionadoId),
        {'quantidadeAtual': FieldValue.increment(-pesoCarga)},
      );
      batch.update(
        _db.collection('produtos').doc(produtoId),
        {'quantidadeAtual': FieldValue.increment(-pesoCarga)},
      );
      batch.set(_db.collection('movimentacoes').doc(), {
        'data': FieldValue.serverTimestamp(),
        'produtoId': produtoId,
        'loteId': loteSelecionadoId,
        'tipo': 'saida',
        'quantidade': pesoCarga,
        'numeroOS': osId,
        'equipamento': idCrachaTemporario,
        'operador': operador,
        'clienteNome': clienteNome,
        'cc': cc,
      });
    }

    batch.update(_itensRef(osId).doc(itemId), {
      'status': 'aguardando_estanqueidade',
      'recarga': {
        'data': FieldValue.serverTimestamp(),
        'tipo': tipoRegistro,
        'lote': loteFinal,
        'peso': pesoFinalRegistrado,
        'statusConcluido': true,
      },
    });

    final equipRef = _db.collection('equipamentos').doc(equipamentoId);
    final Map<String, dynamic> updateEquip = {
      'ultimaRecarga': dataAtual,
      'lotePo': loteFinal,
      'substituirPo': false,
    };
    if (isPo && substituirPo) {
      updateEquip['origemSelo'] = 'NOSSA';
      updateEquip['ultimaTrocaPo'] = dataAtual;
    }
    batch.update(equipRef, updateEquip);

    // recarga -= 1, estanqueidade += 1
    final delta = _deltaContadores(statusAtualItem, 'aguardando_estanqueidade');
    if (delta.isNotEmpty) {
      batch.set(_contadoresRef(empresaId), delta, SetOptions(merge: true));
    }

    await batch.commit();
  }

  @override
  Future<void> salvarManutencaoValvula({
    required String itemId,
    required String osId,
    required String equipamentoId,
    required String operador,
    required String pesoVazio,
    required String pesoCheioMeta,
    required String proximaEstacao,
    required String statusAtualItem,
    required String empresaId,
  }) async {
    final batch = _db.batch();

    batch.update(_db.collection('equipamentos').doc(equipamentoId), {
      'valvula_pesoVazio': pesoVazio,
      'valvula_pesoCheioMeta': pesoCheioMeta,
      'valvula_data': DateTime.now().toIso8601String(),
      'valvula_responsavel': operador,
    });

    batch.update(_itensRef(osId).doc(itemId), {
      'status': 'aguardando_$proximaEstacao',
      'manutencao_valvula': {
        'data': FieldValue.serverTimestamp(),
        'operador': operador,
        'pesoVazio': pesoVazio,
        'pesoCheioMeta': pesoCheioMeta,
      },
    });

    final delta = _deltaContadores(statusAtualItem, 'aguardando_$proximaEstacao');
    if (delta.isNotEmpty) {
      batch.set(_contadoresRef(empresaId), delta, SetOptions(merge: true));
    }

    await batch.commit();
  }

  // ─── Peças trocadas ───────────────────────────────────────────────────────

  @override
  Future<void> registrarPecasTrocadas({
    required String itemId,
    required String osId,
    required String empresaId,
    required Map<int, String> pecas,
  }) async {
    if (pecas.isEmpty) return;
    await _itensRef(osId).doc(itemId).update({
      'pecasTrocadas': FieldValue.arrayUnion(pecas.keys.toList()),
    });
  }

  // ─── Print job ────────────────────────────────────────────────────────────

  @override
  Future<void> criarPrintJob({
    required List<String> itensIds,
    required String osId,
    required bool imprimirGarantia,
    required bool imprimirNR23,
    required String impressora,
  }) async {
    await _db.collection('print_jobs').add({
      'itensIds': itensIds,
      'osId': osId,
      'imprimirGarantia': imprimirGarantia,
      'imprimirNR23': imprimirNR23,
      'printerName': impressora,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Crachás ──────────────────────────────────────────────────────────────

  @override
  Future<bool> verificarCrachaEmUso(String idCracha, String empresaId) async {
    final snap = await _db
        .collection('crachas')
        .where('empresaId', isEqualTo: empresaId)
        .where('idCracha', isEqualTo: idCracha)
        .where('status', isEqualTo: 'emUso')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  @override
  Future<Map<String, dynamic>?> buscarInfoCracha(
      String idCracha, String empresaId) async {
    final snap = await _db
        .collection('crachas')
        .where('empresaId', isEqualTo: empresaId)
        .where('idCracha', isEqualTo: idCracha)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return {'id': doc.id, ...doc.data()};
  }
}