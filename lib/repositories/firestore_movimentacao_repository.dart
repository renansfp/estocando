// lib/repositories/firestore_movimentacao_repository.dart

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/repositories/movimentacao_repository.dart';

class FirestoreMovimentacaoRepository implements MovimentacaoRepository {
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
  Stream<List<Map<String, dynamic>>> streamMovimentacoesFiltradas(
      String empresaId, {
        DateTime? dataInicio,
        DateTime? dataFim,
        String? tipo,
      }) {
    Query query = _db
        .collection('movimentacoes')
        .where('empresaId', isEqualTo: empresaId)
        .orderBy('data', descending: true);

    if (dataInicio != null) {
      query = query.where('data',
          isGreaterThanOrEqualTo: Timestamp.fromDate(dataInicio));
    }
    if (dataFim != null) {
      final fimDoDia =
      DateTime(dataFim.year, dataFim.month, dataFim.day, 23, 59, 59);
      query = query.where('data',
          isLessThanOrEqualTo: Timestamp.fromDate(fimDoDia));
    }
    if (tipo != null && tipo != 'todos') {
      query = query.where('tipo', isEqualTo: tipo);
    }

    return query.snapshots().map((snap) => snap.docs.map(_toMap).toList());
  }

  @override
  Stream<List<Map<String, dynamic>>> streamMovimentacoesPorEmpresa(
      String empresaId, {int limit = 50}) {
    return _db
        .collection('movimentacoes')
        .where('empresaId', isEqualTo: empresaId)
        .orderBy('data', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(_toMap).toList());
  }

  @override
  Stream<List<Map<String, dynamic>>> streamMovimentacoesPorProduto(
      String empresaId, String produtoId) {
    return _db
        .collection('movimentacoes')
        .where('empresaId', isEqualTo: empresaId)
        .where('produtoId', isEqualTo: produtoId)
        .orderBy('data', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_toMap).toList());
  }

  @override
  Stream<List<Map<String, dynamic>>> streamMovimentacoesPorLote(
      String empresaId, String loteId) {
    return _db
        .collection('movimentacoes')
        .where('empresaId', isEqualTo: empresaId)
        .where('loteId', isEqualTo: loteId)
        .orderBy('data', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_toMap).toList());
  }

  @override
  Future<List<Map<String, dynamic>>> buscarTodosPorEmpresa(
      String empresaId) async {
    final snap = await _db
        .collection('movimentacoes')
        .where('empresaId', isEqualTo: empresaId)
        .orderBy('data', descending: true)
        .get();
    return snap.docs.map(_toMap).toList();
  }

  @override
  Future<void> excluirComEstorno({
    required String movimentacaoId,
    required Map<String, dynamic> dadosMovimentacao,
    required String usuarioId,
    required String usuarioNome,
  }) async {
    final movRef = _db.collection('movimentacoes').doc(movimentacaoId);
    final produtoRef =
    _db.collection('produtos').doc(dadosMovimentacao['produtoId']);
    final agora = DateTime.now();

    await _db.runTransaction((transaction) async {
      final produtoSnap = await transaction.get(produtoRef);
      if (!produtoSnap.exists) {
        throw Exception('Produto associado à movimentação não foi encontrado!');
      }

      final double estoqueAtual =
      (produtoSnap.data()!['quantidadeAtual'] as num).toDouble();
      final double quantidade =
      (dadosMovimentacao['quantidade'] as num).toDouble();
      final String tipo = dadosMovimentacao['tipo'] as String;

      // Calcula o novo saldo revertendo o efeito original
      final double novaQuantidade =
      tipo == 'entrada' ? estoqueAtual - quantidade : estoqueAtual + quantidade;

      if (novaQuantidade < 0) {
        throw Exception('Este cancelamento resultaria em estoque negativo.');
      }

      // 1. Marca a movimentação original como cancelada (não apaga)
      transaction.update(movRef, {
        'cancelada': true,
        'canceladaPor': usuarioNome,
        'canceladaEm': Timestamp.fromDate(agora),
      });

      // 2. Cria registro de estorno para rastreabilidade
      final estornoRef = _db.collection('movimentacoes').doc();
      transaction.set(estornoRef, {
        'empresaId': dadosMovimentacao['empresaId'],
        'produtoId': dadosMovimentacao['produtoId'],
        'produtoNome': dadosMovimentacao['produtoNome'],
        'produtoCodigo': dadosMovimentacao['produtoCodigo'],
        'tipo': tipo == 'entrada' ? 'saida' : 'entrada',
        'subTipo': 'ESTORNO',
        'quantidade': quantidade,
        'data': Timestamp.fromDate(agora),
        'usuarioId': usuarioId,
        'usuarioNome': usuarioNome,
        'cancelada': false,
        'movimentacaoOrigemId': movimentacaoId,
      });

      // 3. Corrige o saldo do produto
      transaction.update(produtoRef, {'quantidadeAtual': novaQuantidade});
    });
  }

  // ─── Novos métodos ────────────────────────────────────────────────────────

  @override
  Future<void> importarMovimentacaoComEstoque({
    required String empresaId,
    required String codigoProduto,
    required String tipo,
    required double quantidade,
    required DateTime data,
    String? destino,
    double? valorUnitario,
    String? centroCusto,
  }) async {
    await _db.runTransaction((transaction) async {
      // Busca o produto pelo código dentro da empresa
      final produtoQuery = await _db
          .collection('produtos')
          .where('empresaId', isEqualTo: empresaId)
          .where('codigo', isEqualTo: codigoProduto)
          .limit(1)
          .get();

      if (produtoQuery.docs.isEmpty) {
        throw Exception(
            'Produto com código "$codigoProduto" não encontrado na empresa selecionada.');
      }

      final produtoRef = produtoQuery.docs.first.reference;
      final produtoSnap = await transaction.get(produtoRef);
      final produtoData = produtoSnap.data() as Map<String, dynamic>;

      final quantidadeAtual =
      (produtoData['quantidadeAtual'] as num? ?? 0).toDouble();
      final novaQuantidade = tipo == 'entrada'
          ? quantidadeAtual + quantidade
          : quantidadeAtual - quantidade;

      transaction.update(produtoRef, {'quantidadeAtual': novaQuantidade});

      transaction.set(_db.collection('movimentacoes').doc(), {
        'empresaId': empresaId,
        'produtoId': produtoRef.id,
        'produtoNome': produtoData['nome'] ?? 'N/D',
        'produtoCodigo': codigoProduto,
        'tipo': tipo,
        'subTipo': (destino != null && destino.isNotEmpty) ? destino : 'Importado',
        'quantidade': quantidade,
        'data': Timestamp.fromDate(data),
        'valorUnitarioMovimentacao': valorUnitario,
        'centroDeCusto': centroCusto,
        'usuarioEmail': 'importacao_csv',
      });
    });
  }

  @override
  Future<void> resetarDadosEmpresa(String empresaId) async {
    // Busca tudo primeiro, depois deleta/zera em chunks de 400
    // (limite seguro abaixo do teto de 500 docs/batch do Firestore)
    final movSnap = await _db
        .collection('movimentacoes')
        .where('empresaId', isEqualTo: empresaId)
        .get();

    final prodSnap = await _db
        .collection('produtos')
        .where('empresaId', isEqualTo: empresaId)
        .get();

    for (int i = 0; i < movSnap.docs.length; i += 400) {
      final batch = _db.batch();
      final chunk = movSnap.docs.sublist(i, min(i + 400, movSnap.docs.length));
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    for (int i = 0; i < prodSnap.docs.length; i += 400) {
      final batch = _db.batch();
      final chunk =
      prodSnap.docs.sublist(i, min(i + 400, prodSnap.docs.length));
      for (final doc in chunk) {
        batch.update(doc.reference, {'quantidadeAtual': 0});
      }
      await batch.commit();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
// ADICIONAR ANTES DO } FINAL de FirestoreMovimentacaoRepository
// lib/repositories/firestore_movimentacao_repository.dart
// ─────────────────────────────────────────────────────────────────────────────

  @override
  Future<void> salvarMovimentacao({
    required String empresaId,
    required String produtoId,
    required String tipo,
    required double quantidade,
    required double valorUnitario,
    required String? subTipo,
    // lote
    required bool exigeLote,
    String? loteNumero,
    DateTime? loteValidade,
    // contexto
    String? nomeCliente,
    String? nomeFornecedor,
    String? numeroNF,
    String? numeroOS,
    String? nomeDevolucao,
    String? motivoAcerto,
    String? numeroAG,
    String? nomeColaborador,
    String? centroDeCusto,
    String? numeroPedido,
    required String usuarioId,
    required String usuarioNome,
  }) async {
    final produtoRef = _db.collection('produtos').doc(produtoId);

    await _db.runTransaction((transaction) async {
      // 1. Ler produto e validar estoque
      final produtoSnap = await transaction.get(produtoRef);
      if (!produtoSnap.exists) throw Exception('Produto não encontrado!');

      final dadosProduto = produtoSnap.data() as Map<String, dynamic>;
      final double estoqueAtual =
      (dadosProduto['quantidadeAtual'] ?? 0).toDouble();

      double novoEstoque;
      if (tipo == 'saida') {
        if (estoqueAtual < quantidade) throw Exception('Estoque insuficiente!');
        novoEstoque = estoqueAtual - quantidade;
      } else {
        novoEstoque = estoqueAtual + quantidade;
      }

      // 2. Atualizar produto (e valor unitário se for COMPRA)
      final Map<String, dynamic> updateProduto = {
        'quantidadeAtual': novoEstoque,
      };
      if (tipo == 'entrada' && subTipo == 'COMPRA') {
        updateProduto['valor'] = valorUnitario;
      }
      transaction.update(produtoRef, updateProduto);

      // 3. Upsert do lote (se o produto exigir controle de lote)
      String? idLoteRegistrado;
      if (tipo == 'entrada' && exigeLote && loteNumero != null) {
        final lotesCollection = produtoRef.collection('lotes');

        // Query não-transactional para encontrar lote existente
        final loteQuery = await lotesCollection
            .where('numero', isEqualTo: loteNumero)
            .limit(1)
            .get();

        if (loteQuery.docs.isNotEmpty) {
          // Lote existente: incrementa a quantidade
          final loteDoc = loteQuery.docs.first;
          final qtdAtual = (loteDoc['quantidadeAtual'] ?? 0).toDouble();
          transaction.update(loteDoc.reference, {
            'quantidadeAtual': qtdAtual + quantidade,
            'ultimaEntrada': FieldValue.serverTimestamp(),
          });
          idLoteRegistrado = loteDoc.id;
        } else {
          // Lote novo: cria o documento
          final novoLoteRef = lotesCollection.doc();
          transaction.set(novoLoteRef, {
            'numero': loteNumero,
            'validade': loteValidade,
            'quantidadeInicial': quantidade,
            'quantidadeAtual': quantidade,
            'dataEntrada': FieldValue.serverTimestamp(),
            'ativo': true,
          });
          idLoteRegistrado = novoLoteRef.id;
        }
      }

      // 4. Criar movimentação
      final movRef = _db.collection('movimentacoes').doc();
      final movData = <String, dynamic>{
        'empresaId': empresaId,
        'produtoId': produtoId,
        'produtoCodigo': dadosProduto['codigo'],
        'produtoNome': dadosProduto['nome'],
        'tipo': tipo,
        'quantidade': quantidade,
        'data': Timestamp.now(),
        'subTipo': subTipo,
        'valorUnitarioMovimentacao':
        (tipo == 'entrada' && subTipo == 'COMPRA')
            ? valorUnitario
            : dadosProduto['valor'],
        'nomeCliente': nomeCliente,
        'nomeFornecedor': nomeFornecedor,
        'numeroNF': numeroNF,
        'numeroOS': numeroOS,
        'nomeDevolucao': nomeDevolucao,
        'motivoAcerto': motivoAcerto,
        'numeroAG': numeroAG,
        'nomeColaborador': nomeColaborador,
        'centroDeCusto': centroDeCusto,
        'numeroPedido': numeroPedido,
        'usuarioId': usuarioId,
        'usuarioNome': usuarioNome,
        'cancelada': false,
      };

      if (exigeLote && idLoteRegistrado != null) {
        movData['loteNumero'] = loteNumero;
        movData['loteId'] = idLoteRegistrado;
        movData['loteValidade'] = loteValidade?.toIso8601String();
      }

      transaction.set(movRef, movData);
    });
  }
}