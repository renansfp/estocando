// CÓDIGO COMPLETO E FINAL - COM AS FUNÇÕES DE EXCLUIR E ATUALIZAR

import 'package:cloud_firestore/cloud_firestore.dart';

class MovimentacaoService {

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ESTA É A FUNÇÃO QUE JÁ TINHAMOS CRIADO ANTES
  Future<void> excluirMovimentacaoComEstorno(Map<String, dynamic> movimentacaoData, String movimentacaoId) async {
    final movimentacaoRef = _firestore.collection('movimentacoes').doc(movimentacaoId);
    final produtoRef = _firestore.collection('produtos').doc(movimentacaoData['produtoId']);

    await _firestore.runTransaction((transaction) async {
      final produtoSnapshot = await transaction.get(produtoRef);
      if (!produtoSnapshot.exists) {
        throw Exception("Produto associado à movimentação não foi encontrado!");
      }

      final double estoqueAtual = (produtoSnapshot.data()!['quantidadeAtual'] as num).toDouble();
      final double quantidadeMovimentada = (movimentacaoData['quantidade'] as num).toDouble();
      double novaQuantidade;

      if (movimentacaoData['tipo'] == 'entrada') {
        novaQuantidade = estoqueAtual - quantidadeMovimentada;
      } else {
        novaQuantidade = estoqueAtual + quantidadeMovimentada;
      }

      if (novaQuantidade < 0) {
        throw Exception("Esta exclusão resultaria em estoque negativo.");
      }

      transaction.update(produtoRef, {'quantidadeAtual': novaQuantidade});
      transaction.delete(movimentacaoRef);
    });
  }

  // ---> MUDANÇA (EDIÇÃO): Adicionamos este novo método completo para a lógica de atualização.
  Future<void> atualizarMovimentacao({
    required QueryDocumentSnapshot movimentacaoAntiga,
    required Map<String, dynamic> dadosNovos,
  }) async {
    final dadosAntigos = movimentacaoAntiga.data() as Map<String, dynamic>;
    final produtoId = dadosAntigos['produtoId'];

    final produtoRef = _firestore.collection('produtos').doc(produtoId);
    final movimentacaoRef = _firestore.collection('movimentacoes').doc(movimentacaoAntiga.id);

    // A transação garante que o estoque e a movimentação sejam atualizados juntos.
    return _firestore.runTransaction((transaction) async {
      final produtoSnapshot = await transaction.get(produtoRef);
      if (!produtoSnapshot.exists) {
        throw Exception("Produto não encontrado! A atualização foi cancelada.");
      }

      final double estoqueAtual = (produtoSnapshot.data()!['quantidadeAtual'] as num).toDouble();
      final double quantidadeAntiga = (dadosAntigos['quantidade'] as num).toDouble();
      final String tipoAntigo = dadosAntigos['tipo'];

      final double quantidadeNova = (dadosNovos['quantidade'] as num).toDouble();
      final String tipoNovo = dadosNovos['tipo'];

      // 1. Estorna a quantidade antiga para neutralizar o efeito da movimentação original.
      double estoqueAposEstorno;
      if (tipoAntigo == 'entrada') {
        estoqueAposEstorno = estoqueAtual - quantidadeAntiga;
      } else { // era 'saida'
        estoqueAposEstorno = estoqueAtual + quantidadeAntiga;
      }

      // 2. Aplica a nova quantidade ao estoque já corrigido.
      double estoqueFinal;
      if (tipoNovo == 'entrada') {
        estoqueFinal = estoqueAposEstorno + quantidadeNova;
      } else { // é 'saida'
        estoqueFinal = estoqueAposEstorno - quantidadeNova;
      }

      // Validação de segurança para impedir estoque negativo.
      if (estoqueFinal < 0) {
        throw Exception("Esta alteração resultaria em estoque negativo. Verifique a quantidade.");
      }

      // 3. Executa as atualizações no banco de dados DENTRO da transação.
      transaction.update(produtoRef, {'quantidadeAtual': estoqueFinal});
      transaction.update(movimentacaoRef, dadosNovos);
    });
  }
}