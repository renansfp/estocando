// lib/repositories/firestore_item_os_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:protecin_producao/repositories/item_os_repository.dart';
import 'package:protecin_producao/utils/firestore_utils.dart';

class FirestoreItemOsRepository implements ItemOsRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Converte todos os Timestamp do Firestore para DateTime antes de entregar
  // para as telas. Assim nenhuma tela precisa importar cloud_firestore.

  Map<String, dynamic> _toMap(DocumentSnapshot doc) {
    final raw = <String, dynamic>{
      'id': doc.id,
      ...(doc.data() as Map<String, dynamic>? ?? {}),
    };
    return convertTimestamps(raw);
  }

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

  @override
  Stream<List<Map<String, dynamic>>> streamItensEmProducao(String empresaId) {
    return _db
        .collection('itens_os')
        .where('empresaId', isEqualTo: empresaId)
        .where('statusAtual', isEqualTo: 'emProducao')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList());
  }

  @override
  Stream<List<Map<String, dynamic>>> streamItensPorOsEStatus(
      String osId, String status, String empresaId) {
    return _db
        .collection('itens_os')
        .where('empresaId', isEqualTo: empresaId)
        .where('osId', isEqualTo: osId)
        .where('status', isEqualTo: status)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList());
  }

  @override
  Stream<List<Map<String, dynamic>>> streamItensAguardandoDescarga(
      String empresaId, List<String> filtrosAgente) {
    return _db
        .collection('itens_os')
        .where('empresaId', isEqualTo: empresaId)
        .where('status', isEqualTo: 'aguardando_descarga')
        .where('tipoAgente', whereIn: filtrosAgente)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList());
  }

  @override
  Future<Map<String, dynamic>?> buscarItemPorCracha(
      String osId, String cracha, String status, String empresaId) async {
    final query = await _db
        .collection('itens_os')
        .where('empresaId', isEqualTo: empresaId)
        .where('osId', isEqualTo: osId)
        .where('idCrachaTemporario', isEqualTo: cracha)
        .where('status', isEqualTo: status)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    return {'id': doc.id, ...doc.data()};
  }

  @override
  Future<void> confirmarEtapa({
    required String itemId,
    required Map<String, dynamic> dadosItem,
    required String osId,
    required String statusPendente,
    required String proximaEstacao,
    Map<String, dynamic>? dadosOsExtra,
  }) async {
    final itemRef = _db.collection('itens_os').doc(itemId);
    final osRef = _db.collection('ordens_servico').doc(osId);

    await _db.runTransaction((transaction) async {
      // 1. Lê a OS para consultar o placar de pendentes
      final osDoc = await transaction.get(osRef);
      final placar = Map<String, dynamic>.from(
        (osDoc.data() as Map<String, dynamic>?)?['pendentes'] ?? {},
      );

      // 2. Decrementa o contador da etapa atual; incrementa o da próxima
      final int anterior = (placar[statusPendente] as num?)?.toInt() ?? 0;
      final int novo = (anterior - 1).clamp(0, 99999);

      // 3. Atualiza o item
      transaction.update(itemRef, {
        'status': 'aguardando_$proximaEstacao',
        ...dadosItem,
      });

      // 4. Atualiza a OS: placar sempre; etapaAtual só quando o último saiu
      final Map<String, dynamic> osUpdate = {
        'pendentes.$statusPendente': novo,
        'pendentes.aguardando_$proximaEstacao': FieldValue.increment(1),
      };
      if (novo <= 0) {
        osUpdate['etapaAtual'] = proximaEstacao;
        if (dadosOsExtra != null) osUpdate.addAll(dadosOsExtra);
      }
      transaction.update(osRef, osUpdate);
    });
  }

  @override
  Future<void> liberarLotePremontagem({
    required String osId,
    required List<Map<String, dynamic>> itens,
    required String operador,
  }) async {
    final batch = _db.batch();
    String proximaDaOS = 'montagem';

    // Acumula quantos itens vão para cada próximo status
    final Map<String, int> novosContadores = {};

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

      batch.update(_db.collection('itens_os').doc(item['id']), {
        'status': 'aguardando_$proxima',
        'premontagem': {
          'data': FieldValue.serverTimestamp(),
          'operador': operador,
        },
      });
    }

    // Monta o update da OS: avança etapa + inicializa placar para cada
    // próximo status (itens podem seguir roteiros diferentes)
    final Map<String, dynamic> osUpdate = {'etapaAtual': proximaDaOS};
    novosContadores.forEach((status, count) {
      osUpdate['pendentes.$status'] = count;
    });

    batch.update(_db.collection('ordens_servico').doc(osId), osUpdate);
    await batch.commit();
  }

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

  @override
  Future<void> salvarManutencaoValvula({
    required String itemId,
    required String osId,
    required String equipamentoId,
    required String operador,
    required String pesoVazio,
    required String pesoCheioMeta,
    required String proximaEstacao,
  }) async {
    final batch = _db.batch();

    // Atualiza o equipamento com os dados de pesagem
    batch.update(_db.collection('equipamentos').doc(equipamentoId), {
      'valvula_pesoVazio': pesoVazio,
      'valvula_pesoCheioMeta': pesoCheioMeta,
      'valvula_data': DateTime.now().toIso8601String(),
      'valvula_responsavel': operador,
    });

    // Avança o item para a próxima etapa
    batch.update(_db.collection('itens_os').doc(itemId), {
      'status': 'aguardando_$proximaEstacao',
      'manutencao_valvula': {
        'data': FieldValue.serverTimestamp(),
        'operador': operador,
        'pesoVazio': pesoVazio,
        'pesoCheioMeta': pesoCheioMeta,
      },
    });

    await batch.commit();
  }

  @override
  Stream<List<Map<String, dynamic>>> streamItensPorOs(String osId) {
    return _db
        .collection('itens_os')
        .where('osId', isEqualTo: osId)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList());
  }

  @override
  Future<void> expedirItem({
    required String itemId,
    required String osId,
    required String idCracha,
    required String? equipId,
  }) async {
    final dataAtual =
        '${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}';

    final itemRef = _db.collection('itens_os').doc(itemId);
    final osRef = _db.collection('ordens_servico').doc(osId);

    // Busca o crachá fora da transação — leitura auxiliar sem risco de
    // inconsistência (o crachá não é modificado por outras transações
    // concorrentes neste fluxo).
    final queryCracha = await _db
        .collection('crachas')
        .where('idCracha', isEqualTo: idCracha)
        .limit(1)
        .get();

    await _db.runTransaction((transaction) async {
      // 1. Lê o placar da OS
      final osDoc = await transaction.get(osRef);
      final placar = Map<String, dynamic>.from(
        (osDoc.data() as Map<String, dynamic>?)?['pendentes'] ?? {},
      );

      const statusAtual = 'aguardando_expedicao';
      final int anterior = (placar[statusAtual] as num?)?.toInt() ?? 0;
      final int novo = (anterior - 1).clamp(0, 99999);

      // 2. Atualiza o item da OS
      transaction.update(itemRef, {
        'status': 'entregue',
        'statusAtual': 'finalizado',
        'dataExpedicao': FieldValue.serverTimestamp(),
      });

      // 3. Libera o equipamento
      if (equipId != null && equipId.isNotEmpty) {
        transaction.update(_db.collection('equipamentos').doc(equipId), {
          'status': 'ativo',
          'osIdAtual': FieldValue.delete(),
          'itemIdAtual': FieldValue.delete(),
          'ultimaRecarga': dataAtual,
        });
      }

      // 4. Libera o crachá
      if (queryCracha.docs.isNotEmpty) {
        transaction.update(queryCracha.docs.first.reference, {
          'status': 'disponivel',
          'itemOsIdAtual': FieldValue.delete(),
          'osIdAtual': FieldValue.delete(),
        });
      }

      // 5. Atualiza a OS: placar sempre; fecha se for o último
      final Map<String, dynamic> osUpdate = {
        'pendentes.$statusAtual': novo,
      };
      if (novo <= 0) {
        osUpdate['etapaAtual'] = 'finalizado';
        osUpdate['statusLote'] = 'entregue_ao_cliente';
        osUpdate['dataEncerramento'] = FieldValue.serverTimestamp();
      }
      transaction.update(osRef, osUpdate);
    });
  }

  @override
  Future<void> reprovarItem({
    required String itemId,
    required String statusDestino,
    required Map<String, dynamic> dadosFalha,
  }) async {
    await _db.collection('itens_os').doc(itemId).update({
      'status': statusDestino,
      ...dadosFalha,
    });
  }

  @override
  Future<Map<String, dynamic>?> buscarItemPorCrachaEOsId(
      String osId, String cracha, String empresaId) async {
    final query = await _db
        .collection('itens_os')
        .where('empresaId', isEqualTo: empresaId)
        .where('osId', isEqualTo: osId)
        .where('idCrachaTemporario', isEqualTo: cracha)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    return {'id': doc.id, ...doc.data()};
  }

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
  }) async {
    final batch = _db.batch();
    final dataAtual =
        '${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}';

    // 1. Se substituiu o pó: desconta estoque e cria movimentação
    // produtoId já vem da tela — sem query extra ao banco
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

    // 2. Atualiza o item_os
    final itemRef = _db.collection('itens_os').doc(itemId);
    batch.update(itemRef, {
      'status': 'aguardando_estanqueidade',
      'recarga': {
        'data': FieldValue.serverTimestamp(),
        'tipo': tipoRegistro,
        'lote': loteFinal,
        'peso': pesoFinalRegistrado,
        'statusConcluido': true,
      },
    });

    // 3. Atualiza o equipamento
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

    await batch.commit();
  }

  @override
  Future<void> reverterLote({
    required String osId,
    required String statusAtual,
    required String statusAnterior,
    required Map<String, dynamic> dadosOS,
  }) async {
    final snapshot = await _db
        .collection('itens_os')
        .where('osId', isEqualTo: osId)
        .where('status', isEqualTo: statusAtual)
        .get();

    final batch = _db.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'status': statusAnterior});
    }

    // Reseta o placar: zera a etapa atual e restaura a anterior
    // com a contagem real dos itens revertidos
    batch.update(
      _db.collection('ordens_servico').doc(osId),
      {
        ...dadosOS,
        'pendentes.$statusAtual': 0,
        'pendentes.$statusAnterior': snapshot.docs.length,
      },
    );

    await batch.commit();
  }

  // ─────────────────────────────────────────────────────────────────────────────
// ADICIONAR ANTES DO } FINAL de FirestoreItemOsRepository
// lib/repositories/firestore_item_os_repository.dart
// ─────────────────────────────────────────────────────────────────────────────

  @override
  Future<void> condenarItem({
    required String itemId,
    required Map<String, dynamic> item,
    required String etapa,
    required String motivo,
  }) async {
    final batch = _db.batch();
    final String? osId = item['osId'] as String?;
    final String? statusAtual = item['status'] as String?;

    // 1. Atualiza o item da OS
    batch.update(_db.collection('itens_os').doc(itemId), {
      'status': 'condenado',
      'statusAtual': 'condenado',
      'motivoCondenacao': motivo,
      etapa: {
        'data': FieldValue.serverTimestamp(),
        'resultado': 'CONDENADO',
        'motivo': motivo,
      },
    });

    // 2. Baixa o equipamento (se existir)
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

    // 3. Decrementa o placar da OS para que o contador não fique
    //    inflado após a condenação — o item saiu da fila da etapa
    if (osId != null && osId.isNotEmpty && statusAtual != null) {
      batch.update(_db.collection('ordens_servico').doc(osId), {
        'pendentes.$statusAtual': FieldValue.increment(-1),
      });
    }

    await batch.commit();
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
  }) async {
    final itemRef = _db.collection('itens_os').doc(itemId);
    final osRef = _db.collection('ordens_servico').doc(osId);

    await _db.runTransaction((transaction) async {
      // 1. Lê o placar da OS
      final osDoc = await transaction.get(osRef);
      final placar = Map<String, dynamic>.from(
        (osDoc.data() as Map<String, dynamic>?)?['pendentes'] ?? {},
      );

      // 2. Decrementa limpeza; incrementa o próximo status deste item
      const statusAtual = 'aguardando_limpeza';
      final int anterior = (placar[statusAtual] as num?)?.toInt() ?? 0;
      final int novo = (anterior - 1).clamp(0, 99999);

      // 3. Atualiza o item
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

      // 4. Atualiza a OS
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
    });
  }

  @override
  Future<void> finalizarEnsaioTH({
    required String itemId,
    required String? equipamentoId,
    required bool aprovado,
    required String proximaEtapa,
    required Map<String, dynamic> dadosTH,
    Map<String, dynamic>? updatesEquipamento,
  }) async {
    final batch = _db.batch();

    // O repositório injeta o timestamp — a tela não precisa conhecer FieldValue.
    batch.update(_db.collection('itens_os').doc(itemId), {
      'status': aprovado ? 'aguardando_$proximaEtapa' : 'condenado',
      'dadosTH': {
        ...dadosTH,
        'data': FieldValue.serverTimestamp(),
      },
    });

    if (equipamentoId != null &&
        equipamentoId.isNotEmpty &&
        updatesEquipamento != null) {
      // Quando aprovado, apaga motivoCondenacao via FieldValue.delete().
      // Essa responsabilidade fica aqui — não na tela.
      final updatesFinais = aprovado
          ? {...updatesEquipamento, 'motivoCondenacao': FieldValue.delete()}
          : updatesEquipamento;
      batch.update(
        _db.collection('equipamentos').doc(equipamentoId),
        updatesFinais,
      );
    }

    await batch.commit();
  }

  @override
  Stream<List<Map<String, dynamic>>> streamItensDescarga(String empresaId) {
    return _db
        .collection('itens_os')
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


  @override
  Future<void> liberarLoteParaLimpeza({
    required String osId,
    required List<String> itemIds,
  }) async {
    final batch = _db.batch();
    for (final id in itemIds) {
      batch.update(_db.collection('itens_os').doc(id), {
        'status': 'aguardando_limpeza',
        'historico_descarga': FieldValue.serverTimestamp(),
      });
    }
    batch.update(_db.collection('ordens_servico').doc(osId), {
      'etapaAtual': 'limpeza',
      'statusLote': 'na_limpeza',
      // Inicializa o placar para a etapa de limpeza
      'pendentes.aguardando_limpeza': itemIds.length,
    });
    await batch.commit();
  }

  @override
  Future<void> reverterParaDescarga(String osId) async {
    final query = await _db
        .collection('itens_os')
        .where('osId', isEqualTo: osId)
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
    await batch.commit();
  }
  @override
  Future<void> confirmarDescargaItem(String itemOsId, String operador) async {
    await _db.collection('itens_os').doc(itemOsId).update({
      'status': 'descarga_concluida',
      'dataDescarga': FieldValue.serverTimestamp(),
      'realizadoPor': operador,
    });
  }

  @override
  Future<void> confirmarDescargaPorCracha(
      String osId, String idCracha, String operador) async {
    final query = await _db
        .collection('itens_os')
        .where('osId', isEqualTo: osId)
        .where('idCrachaTemporario', isEqualTo: idCracha)
        .where('status', isEqualTo: 'aguardando_descarga')
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Crachá não encontrado nesta OS ou já baixado.');
    }

    final itemRef = query.docs.first.reference;
    final osRef = _db.collection('ordens_servico').doc(osId);

    await _db.runTransaction((transaction) async {
      // 1. Lê o placar da OS
      final osDoc = await transaction.get(osRef);
      final placar = Map<String, dynamic>.from(
        (osDoc.data() as Map<String, dynamic>?)?['pendentes'] ?? {},
      );

      const statusAtual = 'aguardando_descarga';
      final int anterior = (placar[statusAtual] as num?)?.toInt() ?? 0;
      final int novo = (anterior - 1).clamp(0, 99999);

      // 2. Avança o item para limpeza
      transaction.update(itemRef, {
        'status': 'aguardando_limpeza',
        'dataDescarga': FieldValue.serverTimestamp(),
        'realizadoPor': operador,
      });

      // 3. Atualiza OS: decrementa descarga, incrementa limpeza
      //    Se for o último, avança a OS
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
    });
  }

  @override
  Stream<List<Map<String, dynamic>>> streamItensDescargaOsPorAgente(
      String osId, List<String> filtrosAgente) {
    Query<Map<String, dynamic>> query = _db
        .collection('itens_os')
        .where('osId', isEqualTo: osId)
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


  @override
  Future<List<Map<String, dynamic>>> buscarItensComDadosCompletos(String osId) async {
    final snap = await _db
        .collection('itens_os')
        .where('osId', isEqualTo: osId)
        .get();
    return snap.docs.map(_toMap).toList();
  }


  @override
  Future<bool> verificarCrachaEmUso(String idCracha, String empresaId) async {
    // Consulta a coleção 'crachas' — propósito exclusivo de rastrear
    // disponibilidade dos crachás físicos. Muito menor que 'itens_os'
    // (máx. 1500 docs vs potencialmente milhares) e logicamente correta.
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
  Future<void> registrarPecasTrocadas({
    required String itemId,
    required String osId,
    required String empresaId,
    required Map<int, String> pecas,
  }) async {
    if (pecas.isEmpty) return;

    await _db.collection('itens_os').doc(itemId).update({
      'pecasTrocadas': FieldValue.arrayUnion(pecas.keys.toList()),
    });
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

  @override
  Future<Map<String, dynamic>?> buscarItemPorId(String itemId) async {
    final doc = await _db.collection('itens_os').doc(itemId).get();
    if (!doc.exists) return null;
    return _toMap(doc);
  }
}