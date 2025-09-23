// import '../models/produto.dart';
// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../models/movimentacao.dart';
// import '../models/parceiro.dart';
//
// List<Produto> listaDeProdutos = [];
// List<Movimentacao> historicoDeMovimentacoes = [];
// List<Parceiro> listaDeParceiros = []; // <-- ADICIONE ESTA LINHA
//
// void adicionarProduto(Produto produto) {
//   listaDeProdutos.add(produto);
//   salvarProdutos();
// }
//
// void removerProduto(Produto produto) {
//   listaDeProdutos.remove(produto);
//   salvarProdutos();
//   // Adicionamos um print para sabermos que a função foi chamada
//   print('Produto "${produto.nome}" removido da lista de dados.');
// }
//   // Função para SALVAR a lista de produtos no armazenamento
// // DENTRO DO ARQUIVO dados_estoque.dart
//
// Future<void> salvarProdutos() async {
//   print('[DEBUG] Iniciando salvarProdutos...');
//   try {
//     final prefs = await SharedPreferences.getInstance();
//     List<Map<String, dynamic>> listaDeMapas =
//     listaDeProdutos.map((produto) => produto.toJson()).toList();
//     String jsonString = jsonEncode(listaDeMapas);
//
//     // VAMOS VER O QUE ESTAMOS TENTANDO SALVAR
//     print('[DEBUG] JSON que será salvo: $jsonString');
//
//     await prefs.setString('lista_produtos', jsonString);
//     print('[SUCESSO] Produtos salvos!');
//   } catch (e) {
//     // SE ALGO DER ERRADO, VAMOS SABER
//     print('[ERRO AO SALVAR] Falha ao salvar produtos: $e');
//   }
// }
//
// Future<void> carregarProdutos() async {
//   print('[DEBUG] Iniciando carregarProdutos...');
//   try {
//     final prefs = await SharedPreferences.getInstance();
//     final String? jsonString = prefs.getString('lista_produtos');
//
//     print('[DEBUG] JSON lido do armazenamento: $jsonString');
//
//     if (jsonString != null && jsonString.isNotEmpty) {
//       List<dynamic> listaDeMapas = jsonDecode(jsonString);
//       listaDeProdutos =
//           listaDeMapas.map((mapa) => Produto.fromJson(mapa)).toList();
//       print('[SUCESSO] Produtos carregados! Itens na lista: ${listaDeProdutos.length}');
//     } else {
//       print('[INFO] Nenhum produto encontrado para carregar.');
//     }
//   } catch (e) {
//     // SE ALGO DER ERRADO NA LEITURA OU CONVERSÃO, VAMOS SABER
//     print('[ERRO AO CARREGAR] Falha ao carregar ou decodificar produtos: $e');
//   }
// }
// // (No final do arquivo dados_estoque.dart)
//
// void realizarMovimentacao(Movimentacao movimentacao) {
//   final produtoParaAtualizar = movimentacao.produto;
//
//   if (movimentacao.tipo == TipoMovimentacao.entrada) {
//     produtoParaAtualizar.quantidade += movimentacao.quantidade;
//
//     // Lógica de limpar a SC usando a variável correta
//     if (produtoParaAtualizar.numeroSC != null && produtoParaAtualizar.numeroSC!.isNotEmpty) {
//       produtoParaAtualizar.numeroSC = null;
//       print('[LOGIC] SC atendida e limpa para o produto ${produtoParaAtualizar.nome}');
//     }
//
//   } else {
//     produtoParaAtualizar.quantidade -= movimentacao.quantidade;
//   }
//
//   historicoDeMovimentacoes.add(movimentacao);
//
//   salvarProdutos();
//   salvarHistorico();
//   print('[ACTION] Movimentação realizada para ${produtoParaAtualizar.nome}. Novo estoque: ${produtoParaAtualizar.quantidade}');
// }
// Future<void> carregarHistorico() async {
//   print('[DEBUG] Iniciando carregarHistorico...');
//   try {
//     final prefs = await SharedPreferences.getInstance();
//     final String? jsonString = prefs.getString('historico_movimentacoes');
//
//     if (jsonString != null && jsonString.isNotEmpty) {
//       List<dynamic> listaDeMapas = jsonDecode(jsonString);
//       historicoDeMovimentacoes =
//           listaDeMapas.map((mapa) => Movimentacao.fromJson(mapa)).toList();
//       print('[SUCESSO] Histórico carregado! Itens no histórico: ${historicoDeMovimentacoes.length}');
//     } else {
//       print('[INFO] Nenhum histórico encontrado para carregar.');
//     }
//   } catch (e) {
//     print('[ERRO AO CARREGAR HISTÓRICO] Falha: $e');
//   }
// }
// // (Adicione estas funções no final de dados_estoque.dart)
//
// // (No final do arquivo dados_estoque.dart)
//
// Future<void> salvarHistorico() async {
//   print('[DEBUG] Iniciando salvarHistorico...');
//   try {
//     final prefs = await SharedPreferences.getInstance();
//     List<Map<String, dynamic>> listaDeMapas =
//     historicoDeMovimentacoes.map((mov) => mov.toJson()).toList();
//     String jsonString = jsonEncode(listaDeMapas);
//
//     // Salvamos o histórico com uma chave diferente da lista de produtos
//     await prefs.setString('historico_movimentacoes', jsonString);
//     print('[SUCESSO] Histórico salvo!');
//   } catch (e) {
//     print('[ERRO AO SALVAR HISTÓRICO] Falha: $e');
//   }
// }
//
// Future<void> salvarParceiros() async {
//   final prefs = await SharedPreferences.getInstance();
//   final listaJson = listaDeParceiros.map((p) => p.toJson()).toList();
//   await prefs.setString('parceiros_data', jsonEncode(listaJson));
//   print('[SAVE] Lista de parceiros salva!');
// }
//
// Future<void> carregarParceiros() async {
//   final prefs = await SharedPreferences.getInstance();
//   final dados = prefs.getString('parceiros_data');
//   if (dados != null) {
//     final listaJson = jsonDecode(dados) as List;
//     listaDeParceiros = listaJson.map((p) => Parceiro.fromJson(p)).toList();
//     print('[LOAD] ${listaDeParceiros.length} parceiros carregados!');
//   }
// }
// // (Adicione estas funções em dados_estoque.dart)
//
// void adicionarParceiro(Parceiro parceiro) {
//   listaDeParceiros.add(parceiro);
//   salvarParceiros();
//   print('[ACTION] Parceiro ${parceiro.nome} adicionado.');
// }
//
// void atualizarParceiro(Parceiro parceiroAtualizado) {
//   final index = listaDeParceiros.indexWhere((p) => p.id == parceiroAtualizado.id);
//   if (index != -1) {
//     listaDeParceiros[index] = parceiroAtualizado;
//     salvarParceiros();
//     print('[ACTION] Parceiro ${parceiroAtualizado.nome} atualizado.');
//   }
// }
//
// void removerParceiro(Parceiro parceiro) {
//   listaDeParceiros.removeWhere((p) => p.id == parceiro.id);
//   salvarParceiros();
//   print('[ACTION] Parceiro ${parceiro.nome} removido.');
// }