// lib/repositories/firestore_item_os_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/repositories/item_os_repository.dart';

class FirestoreItemOsRepository implements ItemOsRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
  Stream<Map<String, int>> streamContadoresDashboard(String empresaId) {
    return _db
        .collection('itens_os')
        .where('empresaId', isEqualTo: empresaId) // isola dados por empresa
        .where('statusAtual', isEqualTo: 'emProducao')
        .snapshots()
        .map(_calcularContadores);
  }

  // Recebe o snapshot do Firestore e devolve o mapa de contadores.
  // Antes essa lógica estava dentro do _iniciarOuvinteDashboard() na home_screen.
  Map<String, int> _calcularContadores(QuerySnapshot snapshot) {
    int desc = 0, limp = 0, lixa = 0, manut = 0, saque = 0, pint = 0;
    int rec = 0, estanque = 0, premont = 0, mont = 0, test = 0;
    int valvulaPo = 0, expedicao = 0;
    int dABC = 0, dBC = 0, dAgua = 0, dCO2 = 0;
    int rABC = 0, rBC = 0, rAgua = 0, rCO2 = 0;
    int eABC = 0, eBC = 0, eAgua = 0, eCO2 = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final String statusRaw =
          data['status']?.toString().toLowerCase().replaceAll('_', '') ?? '';
      final String agente =
          data['tipoAgente']?.toString().toUpperCase() ?? '';

      if (statusRaw == 'aguardandodescarga') {
        desc++;
        if (agente == 'ABC') dABC++;
        else if (agente == 'BC' || agente == 'PQS') dBC++;
        else if (agente == 'CO2') dCO2++;
        else if (['AP', 'ESP', 'AGUA'].contains(agente)) dAgua++;
      }
      if (statusRaw == 'aguardandolimpeza') limp++;
      if (statusRaw == 'aguardandolixa') lixa++;
      if (statusRaw == 'aguardandomanutencaovalvula') manut++;
      if (statusRaw == 'aguardandosaquevalvula') saque++;
      if (statusRaw == 'aguardandopintura') pint++;
      if (statusRaw.contains('aguardandorecarga')) {
        rec++;
        if (agente == 'ABC') rABC++;
        else if (agente == 'BC' || agente == 'PQS') rBC++;
        else if (['AP', 'ESP', 'AGUA'].contains(agente)) rAgua++;
        else if (agente == 'CO2') rCO2++;
      }
      if (statusRaw.contains('aguardandoestanqueidade')) {
        estanque++;
        if (agente == 'ABC') eABC++;
        else if (agente == 'BC' || agente == 'PQS') eBC++;
        else if (['AP', 'ESP', 'AGUA'].contains(agente)) eAgua++;
        else if (agente == 'CO2') eCO2++;
      }
      if (statusRaw == 'aguardandopremontagem') premont++;
      if (statusRaw == 'aguardandomontagem') mont++;
      if (statusRaw == 'aguardandoth') test++;
      if (statusRaw == 'aguardandomanutencaovalvulapo') valvulaPo++;
      if (statusRaw == 'aguardandoexpedicao') expedicao++;
    }

    return {
      'descarga': desc,
      'limpeza': limp,
      'lixa': lixa,
      'manutencao': manut,
      'saque': saque,
      'pintura': pint,
      'recarga': rec,
      'estanqueidade': estanque,
      'premontagem': premont,
      'montagem': mont,
      'teste': test,
      'valvulaPo': valvulaPo,
      'expedicao': expedicao,
      'descargaABC': dABC,
      'descargaBC': dBC,
      'descargaAgua': dAgua,
      'descargaCO2': dCO2,
      'recargaABC': rABC,
      'recargaBC': rBC,
      'recargaAgua': rAgua,
      'recargaCO2': rCO2,
      'estanqueABC': eABC,
      'estanqueBC': eBC,
      'estanqueAgua': eAgua,
      'estanqueCO2': eCO2,
    };
  }
  @override
  Stream<List<Map<String, dynamic>>> streamItensPorRoteiro(String etapa) {
    return _db
        .collection('itens_os')
        .where('roteiro', arrayContains: etapa)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList());
  }

  @override
  Stream<List<Map<String, dynamic>>> streamItensEmProducao() {
    return _db
        .collection('itens_os')
        .where('statusAtual', isEqualTo: 'emProducao')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList());
  }

  @override
  Stream<List<Map<String, dynamic>>> streamItensPorOsEStatus(
      String osId, String status) {
    return _db
        .collection('itens_os')
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
      String osId, String cracha, String status) async {
    final query = await _db
        .collection('itens_os')
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
    final batch = _db.batch();

    // 1. Atualiza o item: muda o status e grava os dados da etapa
    final itemRef = _db.collection('itens_os').doc(itemId);
    batch.update(itemRef, {
      'status': 'aguardando_$proximaEstacao',
      ...dadosItem,
    });

    // 2. Conta quantos itens ainda estão pendentes nessa etapa
    final pendentes = await _db
        .collection('itens_os')
        .where('osId', isEqualTo: osId)
        .where('status', isEqualTo: statusPendente)
        .get();

    // 3. Se esse for o último, avança a OS também
    if (pendentes.docs.length <= 1) {
      final osRef = _db.collection('ordens_servico').doc(osId);
      batch.update(osRef, {
        'etapaAtual': proximaEstacao,
        ...?dadosOsExtra, // campos extras como dataFimLixa, dataFimValvulaPo, etc.
      });
    }

    // 4. Executa tudo de uma vez — atômico
    await batch.commit();
  }

  @override
  Future<void> liberarLotePremontagem({
    required String osId,
    required List<Map<String, dynamic>> itens,
    required String operador,
  }) async {
    final batch = _db.batch();
    String proximaDaOS = 'montagem';

    for (int i = 0; i < itens.length; i++) {
      final item = itens[i];
      final List<String> roteiro = List<String>.from(item['roteiro'] ?? []);
      int indexAtual = roteiro.indexOf('pre_montagem');
      String proxima = (indexAtual != -1 && indexAtual < roteiro.length - 1)
          ? roteiro[indexAtual + 1]
          : 'montagem';

      // Guarda a proxima etapa do último item para atualizar a OS
      if (i == itens.length - 1) proximaDaOS = proxima;

      batch.update(_db.collection('itens_os').doc(item['id']), {
        'status': 'aguardando_$proxima',
        'premontagem': {
          'data': FieldValue.serverTimestamp(),
          'operador': operador,
        },
      });
    }

    // Avança a OS para a próxima etapa
    batch.update(_db.collection('ordens_servico').doc(osId), {
      'etapaAtual': proximaDaOS,
    });

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
    final batch = _db.batch();
    final dataAtual =
        '${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}';

    // A. Atualiza o item da OS
    final itemRef = _db.collection('itens_os').doc(itemId);
    batch.update(itemRef, {
      'status': 'entregue',
      'statusAtual': 'finalizado',
      'dataExpedicao': FieldValue.serverTimestamp(),
    });

    // B. Libera o equipamento
    if (equipId != null && equipId.isNotEmpty) {
      final equipRef = _db.collection('equipamentos').doc(equipId);
      batch.update(equipRef, {
        'status': 'ativo',
        'osIdAtual': FieldValue.delete(),
        'itemIdAtual': FieldValue.delete(),
        'ultimaRecarga': dataAtual,
      });
    }

    // C. Verifica se é o último item pendente
    final queryPendentes = await _db
        .collection('itens_os')
        .where('osId', isEqualTo: osId)
        .where('status', isEqualTo: 'aguardando_expedicao')
        .get();

    if (queryPendentes.docs.length <= 1) {
      final osRef = _db.collection('ordens_servico').doc(osId);
      batch.update(osRef, {
        'etapaAtual': 'finalizado',
        'statusLote': 'entregue_ao_cliente',
        'dataEncerramento': FieldValue.serverTimestamp(),
      });
    }

    // D. Libera o crachá
    final queryCracha = await _db
        .collection('crachas')
        .where('idCracha', isEqualTo: idCracha)
        .limit(1)
        .get();

    if (queryCracha.docs.isNotEmpty) {
      batch.update(queryCracha.docs.first.reference, {
        'status': 'disponivel',
        'itemOsIdAtual': FieldValue.delete(),
        'osIdAtual': FieldValue.delete(),
      });
    }

    await batch.commit();
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
      String osId, String cracha) async {
    final query = await _db
        .collection('itens_os')
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
    required String? codigoMestre,
    required String? clienteNome,
    required String cc,
  }) async {
    final batch = _db.batch();
    final dataAtual =
        '${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}';

    // 1. Se substituiu o pó: desconta estoque e cria movimentação
    if (isPo && substituirPo && loteSelecionadoId != null && codigoMestre != null) {
      final prodQuery = await _db
          .collection('produtos')
          .where('codigo', isEqualTo: codigoMestre)
          .limit(1)
          .get();
      if (prodQuery.docs.isEmpty) throw 'Produto mestre não encontrado!';
      final String produtoId = prodQuery.docs.first.id;

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
        'operador': 'producao_recarga',
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
    // Busca todos os itens da OS com o status atual
    final snapshot = await _db
        .collection('itens_os')
        .where('osId', isEqualTo: osId)
        .where('status', isEqualTo: statusAtual)
        .get();

    // Usa batch para atualizar tudo de uma vez — operação atômica
    final batch = _db.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'status': statusAnterior});
    }
    batch.update(
        _db.collection('ordens_servico').doc(osId), dadosOS);

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
  }) async {
    final batch = _db.batch();

    batch.update(_db.collection('itens_os').doc(itemId), {
      'status': proximoStatus,
      'statusAtual': 'emProducao',
      'roteiro': roteiro,
      'triagem': {
        'precisaPintura': precisaPintura,
        'testeVencido': testeVencido,
        'data': FieldValue.serverTimestamp(),
        'operador': 'app_triagem',
      },
    });

    // Se este for o último item na limpeza, avança a OS
    final queryPendentes = await _db
        .collection('itens_os')
        .where('osId', isEqualTo: osId)
        .where('status', isEqualTo: 'aguardando_limpeza')
        .get();

    if (queryPendentes.docs.length <= 1) {
      batch.update(_db.collection('ordens_servico').doc(osId), {
        'etapaAtual': proximaEstacao,
        'statusLote': 'em_producao',
        'dataFimLimpeza': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
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
    });
    await batch.commit();
  }
  @override
  Future<void> confirmarDescargaItem(String itemOsId) async {
    await _db.collection('itens_os').doc(itemOsId).update({
      'status': 'descarga_concluida',
      'dataDescarga': FieldValue.serverTimestamp(),
      'realizadoPor': 'operador_descarga',
    });
  }

  @override
  Future<void> confirmarDescargaPorCracha(
      String osId, String idCracha) async {
    final query = await _db
        .collection('itens_os')
        .where('osId', isEqualTo: osId)
        .where('idCrachaTemporario', isEqualTo: idCracha)
        .where('status', isEqualTo: 'aguardando_descarga')
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception(
          'Crachá não encontrado nesta OS ou já baixado.');
    }

    final batch = _db.batch();

    batch.update(query.docs.first.reference, {
      'status': 'aguardando_limpeza',
      'dataDescarga': FieldValue.serverTimestamp(),
      'realizadoPor': 'operador_descarga_auto',
    });

    // Se este for o último item pendente, avança a OS
    final queryPendentes = await _db
        .collection('itens_os')
        .where('osId', isEqualTo: osId)
        .where('status', isEqualTo: 'aguardando_descarga')
        .get();

    if (queryPendentes.docs.length <= 1) {
      batch.update(_db.collection('ordens_servico').doc(osId), {
        'etapaAtual': 'limpeza',
        'statusLote': 'na_limpeza',
        'dataFimDescarga': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
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
  Future<bool> verificarCrachaEmUso(String idCracha) async {
    final snap = await _db
        .collection('itens_os')
        .where('idCrachaTemporario', isEqualTo: idCracha)
        .where('statusAtual', isEqualTo: 'entregue')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }
}