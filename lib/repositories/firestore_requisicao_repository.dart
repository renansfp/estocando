// lib/repositories/firestore_requisicao_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/models/movimentacao.dart';
import 'package:protecin_producao/models/requisicao.dart';
import 'package:protecin_producao/repositories/requisicao_repository.dart';

class FirestoreRequisicaoRepository implements RequisicaoRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Map<String, dynamic> _toMap(DocumentSnapshot doc) => <String, dynamic>{
    'id': doc.id,
    ...(doc.data() as Map<String, dynamic>? ?? {}),
  };

  @override
  Stream<bool> streamTemPendentes(String empresaId) {
    return _db
        .collection('requisicoes')
        .where('empresaId', isEqualTo: empresaId)
        .where('status', isEqualTo: 'PENDENTE')
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isNotEmpty);
  }

  @override
  Stream<List<Map<String, dynamic>>> streamRequisicoesPendentes(
      String empresaId) {
    return _db
        .collection('requisicoes')
        .where('empresaId', isEqualTo: empresaId)
        .where('status', isEqualTo: 'PENDENTE')
        .orderBy('dataSolicitacao', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(_toMap).toList());
  }

  @override
  Future<void> atenderRequisicao({
    required Requisicao requisicao,
    required String atendidoPorId,
    required String atendidoPorNome,
  }) async {
    if (requisicao.id == null) {
      throw Exception('Requisição sem ID — não é possível atendê-la.');
    }

    await _db.runTransaction((transaction) async {
      // 1. Ler todos os produtos e validar estoque
      final Map<String, DocumentSnapshot> snaps = {};

      for (final item in requisicao.itens) {
        final ref = _db.collection('produtos').doc(item.produtoId);
        final snap = await transaction.get(ref);

        if (!snap.exists) {
          throw Exception(
              'Produto "${item.produtoNome}" não existe mais no estoque.');
        }

        snaps[item.produtoId] = snap;

        final estoqueAtual =
        ((snap.data() as Map)['quantidadeAtual'] as num? ?? 0).toDouble();
        if (estoqueAtual < item.quantidadeSolicitada) {
          throw Exception(
            'Estoque insuficiente para "${item.produtoNome}". '
                'Disponível: ${estoqueAtual.toStringAsFixed(2).replaceAll('.', ',')}',
          );
        }
      }

      // 2. Marcar a requisição como ATENDIDA
      transaction.update(
        _db.collection('requisicoes').doc(requisicao.id),
        {
          'status': 'ATENDIDO',
          'atendidoPorId': atendidoPorId,
          'atendidoPorNome': atendidoPorNome,
          'dataAtendimento': Timestamp.now(),
        },
      );

      // 3. Debitar estoque e criar movimentação por item
      for (final item in requisicao.itens) {
        final snap = snaps[item.produtoId]!;
        final dadosProduto = snap.data() as Map<String, dynamic>;
        final estoqueAtual =
        (dadosProduto['quantidadeAtual'] as num? ?? 0).toDouble();

        transaction.update(
          snap.reference,
          {'quantidadeAtual': estoqueAtual - item.quantidadeSolicitada},
        );

        final movimentacao = Movimentacao(
          empresaId: requisicao.empresaId,
          produtoId: item.produtoId,
          produtoCodigo: item.produtoCodigo,
          produtoNome: item.produtoNome,
          tipo: TipoMovimentacao.saida,
          quantidade: item.quantidadeSolicitada,
          data: DateTime.now(),
          subTipo: requisicao.subTipo,
          numeroOS: requisicao.numeroOS,
          nomeColaborador: requisicao.nomeColaborador,
          centroDeCusto: requisicao.centroDeCusto,
          numeroPedido: requisicao.numeroPedido,
          numeroNF: requisicao.numeroNF,
          numeroAG: requisicao.agencia,
          nomeCliente: requisicao.nomeCliente,
          nomeFornecedor: null,
          valorUnitarioMovimentacao:
          (dadosProduto['valor'] as num? ?? 0).toDouble(),
        );

        transaction.set(
          _db.collection('movimentacoes').doc(),
          movimentacao.toJson(),
        );
      }
    });
  }

  @override
  Future<void> reprovarRequisicao({
    required String requisicaoId,
    required String atendidoPorId,
    required String atendidoPorNome,
    String? motivo,
  }) async {
    await _db.collection('requisicoes').doc(requisicaoId).update({
      'status': 'CANCELADO',
      'motivoCancelamento': (motivo != null && motivo.trim().isNotEmpty)
          ? motivo.trim()
          : 'Motivo não informado',
      'atendidoPorId': atendidoPorId,
      'atendidoPorNome': atendidoPorNome,
      'dataAtendimento': Timestamp.now(),
    });
  }
  // ─────────────────────────────────────────────────────────────────────────────
// ADICIONAR ANTES DO } FINAL de FirestoreRequisicaoRepository
// lib/repositories/firestore_requisicao_repository.dart
// ─────────────────────────────────────────────────────────────────────────────

  @override
  Future<String> criar(Requisicao requisicao) async {
    final ref = await _db.collection('requisicoes').add(requisicao.toJson());
    return ref.id;
  }
}