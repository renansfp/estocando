// Salve este arquivo como: telas/tela_lista_produtos.dart
// (Este é o seu código da tela_home.dart, mas modificado com a BUSCA CORRIGIDA)

import 'dart:async';
import 'package:protecin_producao/models/movimentacao.dart';
import 'package:protecin_producao/telas/estoque/tela_movimentacao.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'tela_cadastro_produto.dart';

enum FiltroProdutos { ativos, inativos, todos, pontoDePedido }
enum AcoesProduto { editar, solicitarCompra, excluir }

// Renomeamos a classe
class TelaListaProdutos extends StatefulWidget {
  // Adicionamos este campo para receber a busca da Home
  final String? termoBuscaInicial;

  const TelaListaProdutos({super.key, this.termoBuscaInicial});
  @override
  State<TelaListaProdutos> createState() => _TelaListaProdutosState();
}

class _TelaListaProdutosState extends State<TelaListaProdutos> {
  bool _isSearching = false;
  final _searchController = TextEditingController();
  FiltroProdutos _filtroAtual = FiltroProdutos.ativos;
  Timer? _debounce;

  String? _permissaoUsuario; // 'admin', 'almoxarife', 'producao'
  String? _empresaId;
  bool _carregandoDadosIniciais = true;
  final List<String> _gruposDeProduto = const ['CONSUMO', "EPI'S", 'MATERIA PRIMA', 'REVENDA'];
  String? _grupoFiltroSelecionado;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _carregarDadosUsuario();

    // Lógica para ativar a busca se ela veio da Home
    if (widget.termoBuscaInicial != null &&
        widget.termoBuscaInicial!.isNotEmpty) {
      setState(() {
        _isSearching = true;
        _searchController.text = widget.termoBuscaInicial!;
      });
    }
  }

  Future<void> _carregarDadosUsuario() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userData =
      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();

      if (mounted && userData.exists) {
        final data = userData.data() as Map<String, dynamic>;
        setState(() {
          _permissaoUsuario = data['permissao'];
          _empresaId = data['empresaId'];
          if (_permissaoUsuario == null ||
              !['admin', 'almoxarife', 'producao']
                  .contains(_permissaoUsuario)) {
            _permissaoUsuario = 'producao';
          }
        });
      } else {
        if (mounted) setState(() => _permissaoUsuario = 'producao');
      }
    } else {
      if (mounted) setState(() => _permissaoUsuario = 'producao');
    }
    if (mounted) {
      setState(() {
        _carregandoDadosIniciais = false;
      });
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  String _formatarQuantidade(double valor) {
    if (valor == valor.truncate()) {
      return valor.truncate().toString();
    } else {
      return NumberFormat('#,##0.###', 'pt_BR').format(valor);
    }
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('produtos')
        .where('empresaId', isEqualTo: 'dummy_id');

    if (_empresaId != null) {
      query = FirebaseFirestore.instance
          .collection('produtos')
          .where('empresaId', isEqualTo: _empresaId);
    }

    if (_filtroAtual == FiltroProdutos.ativos ||
        _filtroAtual == FiltroProdutos.pontoDePedido) {
      query = query.where('ativo', isEqualTo: true);
    } else if (_filtroAtual == FiltroProdutos.inativos) {
      query = query.where('ativo', isEqualTo: false);
    }
    if (_grupoFiltroSelecionado != null) {
      query = query.where('grupo', isEqualTo: _grupoFiltroSelecionado);
    }
    query = query.orderBy('nome');

    return Scaffold(
      appBar: _buildAppBar(),
      // Drawer e FloatingActionButton foram removidos daqui
      body: _carregandoDadosIniciais
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError){
            return const Center(
                child: Text('Ocorreu um erro ao carregar os produtos.'));}
          if (snapshot.connectionState == ConnectionState.waiting){
            return const Center(child: CircularProgressIndicator());}
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty){
            return const Center(
                child: Text('Nenhum produto para exibir.',
                    style: TextStyle(fontSize: 18, color: Colors.grey)));}

          List<QueryDocumentSnapshot> produtos = snapshot.data!.docs;

          if (_filtroAtual == FiltroProdutos.pontoDePedido) {
            produtos = produtos.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final double quantidade = (data['quantidadeAtual'] ?? 0.0).toDouble();
              final double estoqueMinimo = (data['estoqueMinimo'] ?? 0.0).toDouble();
              return quantidade <= estoqueMinimo && estoqueMinimo > 0;
            }).toList();
          }

          // ---> INÍCIO DA CORREÇÃO DO PONTO 1 (BUSCA) <---
          final String queryBusca =
          _searchController.text.toLowerCase().trim();
          if (queryBusca.isNotEmpty) {
            // 1. O .where() agora filtra tudo que "contenha" a busca
            produtos = produtos.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final nome = (data['nome'] ?? '').toLowerCase();
              final codigo = (data['codigo'] ?? '').toLowerCase();
              return nome.contains(queryBusca) || codigo.contains(queryBusca);
            }).toList();

            // 2. O .sort() organiza com a prioridade que você pediu
            produtos.sort((a, b) {
              final dataA = a.data() as Map<String, dynamic>;
              final dataB = b.data() as Map<String, dynamic>;
              final nomeA = (dataA['nome'] ?? '').toLowerCase();
              final codigoA = (dataA['codigo'] ?? '').toLowerCase();
              final nomeB = (dataB['nome'] ?? '').toLowerCase();
              final codigoB = (dataB['codigo'] ?? '').toLowerCase();

              // Função de pontuação melhorada
              int getMatchScore(String nome, String codigo) {
                if (codigo == queryBusca) return 1; // P1: Código exato
                if (codigo.startsWith(queryBusca)) return 2; // P2: Código começa com
                if (nome.startsWith(queryBusca)) return 3; // P3: Nome começa com
                if (nome.contains(queryBusca)) return 4; // P4: Nome contém
                if (codigo.contains(queryBusca)) return 5; // P5: Código contém
                return 6; // Outros
              }

              final scoreA = getMatchScore(nomeA, codigoA);
              final scoreB = getMatchScore(nomeB, codigoB);

              // Compara primeiro pela pontuação, depois por ordem alfabética
              return scoreA != scoreB ? scoreA.compareTo(scoreB) : nomeA.compareTo(nomeB);
            });
          } else {
            // Lógica de ordenação padrão (quando não há busca)
            produtos.sort((a, b) {
              final dataA = a.data() as Map<String, dynamic>;
              final dataB = b.data() as Map<String, dynamic>;
              final double quantidadeA = (dataA['quantidadeAtual'] ?? 0.0).toDouble();
              final double estoqueMinimoA = (dataA['estoqueMinimo'] ?? 0.0).toDouble();
              final String nomeA = dataA['nome'] ?? '';
              final double quantidadeB = (dataB['quantidadeAtual'] ?? 0.0).toDouble();
              final double estoqueMinimoB = (dataB['estoqueMinimo'] ?? 0.0).toDouble();
              final String nomeB = dataB['nome'] ?? '';
              int getPrioridade(double qtd, double min) { if (qtd <= 0) return 1; if (qtd <= min && min > 0) return 2; return 3; }
              final prioridadeA = getPrioridade(quantidadeA, estoqueMinimoA);
              final prioridadeB = getPrioridade(quantidadeB, estoqueMinimoB);
              return prioridadeA != prioridadeB ? prioridadeA.compareTo(prioridadeB) : nomeA.toLowerCase().compareTo(nomeB.toLowerCase());
            });
          }
          // ---> FIM DA CORREÇÃO DO PONTO 1 (BUSCA) <---


          if (produtos.isEmpty) {
            String msg = 'Nenhum produto encontrado para "$queryBusca"';
            if(queryBusca.isEmpty && _filtroAtual == FiltroProdutos.pontoDePedido) msg = 'Nenhum produto em ponto de pedido.';
            return Center(child: Text(msg, style: const TextStyle(fontSize: 18, color: Colors.grey)));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80.0),
            itemCount: produtos.length,
            itemBuilder: (context, index) => _buildCardProduto(
                context, produtos[index], _permissaoUsuario!),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar() {
    String titulo = 'Lista de Produtos'; // Título simplificado
    if (_filtroAtual == FiltroProdutos.pontoDePedido){
      titulo = 'Ponto de Pedido';}
    else if (_filtroAtual == FiltroProdutos.ativos){
      titulo = 'Produtos (Ativos)';}
    else if (_filtroAtual == FiltroProdutos.inativos){
      titulo = 'Produtos (Inativos)'; }
    else if (_filtroAtual == FiltroProdutos.todos){
      titulo = 'Produtos (Todos)';}

    if (!_isSearching) {
      return AppBar(
        title: Text(titulo),
        actions: [
          IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _isSearching = true)),
          PopupMenuButton<String>(
            icon: Icon(Icons.category, color: _grupoFiltroSelecionado != null ? Colors.blue : Colors.white),
            tooltip: 'Filtrar por Grupo',
            onSelected: (String? result) {
              setState(() {
                _grupoFiltroSelecionado = (result == 'TODOS') ? null : result;
              });
            },
            itemBuilder: (BuildContext context) {
              List<PopupMenuEntry<String>> items = [];
              items.add(
                const PopupMenuItem(
                  value: 'TODOS',
                  child: Text('Todos os Grupos'),
                ),
              );
              items.add(const PopupMenuDivider());
              items.addAll(
                _gruposDeProduto.map((String grupo) => PopupMenuItem<String>(
                  value: grupo,
                  child: Text(grupo),
                )),
              );
              return items;
            },
          ),
          PopupMenuButton<FiltroProdutos>(
            icon: const Icon(Icons.filter_list),
            onSelected: (FiltroProdutos result) =>
                setState(() => _filtroAtual = result),
            itemBuilder: (BuildContext context) =>
            <PopupMenuEntry<FiltroProdutos>>[
              const PopupMenuItem(
                  value: FiltroProdutos.ativos, child: Text('Ver Ativos')),
              const PopupMenuItem(
                  value: FiltroProdutos.pontoDePedido,
                  child: Row(children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Ponto de Pedido')
                  ])),
              const PopupMenuItem(
                  value: FiltroProdutos.inativos, child: Text('Ver Inativos')),
              const PopupMenuItem(
                  value: FiltroProdutos.todos, child: Text('Ver Todos')),
            ],
          ),
        ],
      );
    } else {
      return AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() {
              _isSearching = false;
              _searchController.clear();
              // Se fecharmos a busca que veio da Home, voltamos para a Home
              if (widget.termoBuscaInicial != null) {
                Navigator.of(context).pop();
              }
            })),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'Buscar por código ou nome...',
              hintStyle: TextStyle(color: Colors.white70),
              border: InputBorder.none),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _searchController.clear()))
        ],
      );
    }
  }

  // O _buildCardProduto permanece o mesmo
  Widget _buildCardProduto(BuildContext context, QueryDocumentSnapshot produtoDoc, String permissao) {
    final data = produtoDoc.data() as Map<String, dynamic>;
    final double quantidade = (data['quantidadeAtual'] ?? 0.0).toDouble();
    final double estoqueMinimo = (data['estoqueMinimo'] ?? 0.0).toDouble();
    final String? numeroSC = data['numeroSC'];
    final double valorUnitario = (data['valor'] ?? 0.0).toDouble();
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    Color statusColor = Theme.of(context).colorScheme.primary.withAlpha(179);
    String statusText = 'Estoque OK';
    Color textColor = Colors.white;

    if (quantidade <= 0) { statusColor = Colors.red.shade700; statusText = 'Estoque Zerado'; }
    else if (quantidade <= estoqueMinimo && estoqueMinimo > 0) { statusColor = Colors.orange.shade800; statusText = 'Abaixo do Mínimo'; }

    final bool podeAlterar = permissao == 'admin' || permissao == 'almoxarife';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(side: BorderSide(color: statusColor, width: 1), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 12, right: 0),
            leading: CircleAvatar(backgroundColor: statusColor, child: Text(_formatarQuantidade(quantidade), style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
            title: Text('${data['codigo'] ?? 'N/A'} - ${data['nome'] ?? 'Sem nome'}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                      if (estoqueMinimo > 0 || (data['estoqueMaximo'] ?? 0.0) > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('Min: ${_formatarQuantidade(estoqueMinimo)} / Max: ${_formatarQuantidade((data['estoqueMaximo'] ?? 0.0).toDouble())}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ),
                      if (numeroSC != null && numeroSC.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Chip(
                            label: Text('SC: $numeroSC', style: const TextStyle(color: Colors.white, fontSize: 10)),
                            backgroundColor: Colors.blue.shade700,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(formatoMoeda.format(valorUnitario), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
                const SizedBox(width: 8),
              ],
            ),
            trailing: podeAlterar ? PopupMenuButton<AcoesProduto>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Mais Opções',
              onSelected: (AcoesProduto acao) {
                switch (acao) {
                  case AcoesProduto.editar:
                    Navigator.push(context, MaterialPageRoute(builder: (c) => TelaCadastroProduto(produtoParaEditar: produtoDoc)));
                    break;
                  case AcoesProduto.solicitarCompra:
                    _mostrarDialogoSC(context, produtoDoc);
                    break;
                  case AcoesProduto.excluir:
                    _mostrarDialogoDeConfirmacao(context, produtoDoc);
                    break;
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<AcoesProduto>>[
                const PopupMenuItem(value: AcoesProduto.editar, child: Text('Editar')),
                const PopupMenuItem(value: AcoesProduto.solicitarCompra, child: Text('Solicitar Compra (SC)')),
                const PopupMenuItem(value: AcoesProduto.excluir, child: Text('Excluir')),
              ],
            ) : null,
          ),
          if (podeAlterar)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildActionButton(context, 'ENTRADA', Icons.add_circle_outline, Colors.green,
                          () => Navigator.push(context, MaterialPageRoute(builder: (c) => TelaMovimentacao(
                        produtoPreSelecionado: produtoDoc,
                        tipoMovimentacaoInicial: TipoMovimentacao.entrada,
                      )))
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(context, 'SAÍDA', Icons.remove_circle_outline, Colors.red,
                          () => Navigator.push(context, MaterialPageRoute(builder: (c) => TelaMovimentacao(
                        produtoPreSelecionado: produtoDoc,
                        tipoMovimentacaoInicial: TipoMovimentacao.saida,
                      )))
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // O _buildActionButton permanece o mesmo
  Widget _buildActionButton(BuildContext context, String label, IconData icon, Color color, VoidCallback onPressed) {
    return TextButton.icon(
      icon: Icon(icon, color: color, size: 20),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  // O _mostrarDialogoSC permanece o mesmo
  void _mostrarDialogoSC(BuildContext context, QueryDocumentSnapshot produtoDoc) {
    final scController = TextEditingController(text: (produtoDoc.data() as Map<String, dynamic>)['numeroSC'] ?? '');
    showDialog( context: context, builder: (context) { return AlertDialog( title: const Text('Solicitação de Compra'), content: TextField( controller: scController, keyboardType: TextInputType.text, decoration: const InputDecoration(labelText: 'Número da SC'), ), actions: [ TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop()), ElevatedButton( child: const Text('Salvar'), onPressed: () async { final navigator = Navigator.of(context); await FirebaseFirestore.instance.collection('produtos').doc(produtoDoc.id).update({'numeroSC': scController.text.trim()}); if(mounted) navigator.pop(); }, ), ], ); }, );
  }

  // O _mostrarDialogoDeConfirmacao permanece o mesmo
  void _mostrarDialogoDeConfirmacao(BuildContext context, QueryDocumentSnapshot produtoDoc) {
    final nomeProduto = (produtoDoc.data() as Map<String, dynamic>)['nome'] ?? 'este produto';
    showDialog( context: context, builder: (context) => AlertDialog( title: const Text('Confirmar Exclusão'), content: Text('Tem certeza que deseja excluir "$nomeProduto"?\nEsta ação não pode ser desfeita.'), actions: [ TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')), TextButton( child: const Text('Excluir', style: TextStyle(color: Colors.red)), onPressed: () async { final navigator = Navigator.of(context); await FirebaseFirestore.instance.collection('produtos').doc(produtoDoc.id).delete(); if(mounted) navigator.pop(); }, ), ], ), );
  }
} // FIM DA CLASSE