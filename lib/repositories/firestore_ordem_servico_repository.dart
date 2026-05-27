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
  Future<String> criarOS({
    required OrdemServico os,
    required List<ItemOS> itens,
    required Parceiro cliente,
    required String observacoes,
  }) async {
    // Proteção contra OS gigantesca que excederia o limite do Firestore.
    // Cada item gera 2 escritas (item_os + equipamento). Soma-se 2 fixas
    // (OS + contador) → limite seguro de 249 itens por OS.
    if (itens.length > 249) {
      throw Exception(
        'Uma OS não pode ter mais de 249 itens. '
            'Divida em duas OS se necessário.',
      );
    }

    final configRef = _db.collection('config').doc('contadores');

    // Pré-gera as referências dos itens fora da transação
    // (criar uma DocumentReference com doc() é uma operação local — não toca o banco).
    // Isso é necessário porque precisamos dos IDs antes de entrar na transação.
    final itenRefs = List.generate(
      itens.length,
          (_) => _db.collection('itens_os').doc(),
    );

    late String idFormatado;

    // runTransaction garante que a leitura + escrita do contador são atômicas.
    // Se dois usuários criarem uma OS ao mesmo tempo, o Firestore detecta
    // o conflito e retenta automaticamente — nunca dois processos pegam
    // o mesmo número.
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
      // ── Placar de pendentes por etapa — elimina queries de contagem ──────
      // Cada chave representa um status de item_os. Decrementado a cada
      // confirmarEtapa/confirmarTriagem/expedirItem. Quando chega a zero,
      // a OS avança automaticamente. Mantemos chaves antigas zeradas para
      // facilitar debug no Firebase Console.
      osMap['pendentes'] = {'aguardando_descarga': itens.length};
      transaction.set(osRef, osMap);

      // ── 3. Cria os itens e atualiza os equipamentos ───────────────────────
      for (int i = 0; i < itens.length; i++) {
        final item = itens[i];
        final itemRef = itenRefs[i];

        final itemJson = item.toJson();
        itemJson['osId'] = idFormatado;
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

      // ── 4. Atualiza o contador — última escrita da transação ──────────────
      transaction.set(
        configRef,
        {'ultima_os': proximoNumero},
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
    // Quando somentAbertas = true, filtra no Firestore por documentos onde
    // dataEncerramento ainda não foi gravado (campo ausente = OS em aberto).
    // Isso evita baixar OS finalizadas que podem ser a maioria do banco.
    // Usa isNull: true em vez de isNotEqualTo para preservar o orderBy
    // em dataEntrada sem a restrição de ordenação do Firestore.
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