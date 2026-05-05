import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/produto_provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/models/movimentacao.dart';
import 'package:protecin_producao/telas/estoque/tela_movimentacao.dart';
import 'tela_cadastro_produto.dart';

enum FiltroProdutos { ativos, inativos, todos, pontoDePedido }
enum AcoesProduto { editar, solicitarCompra, excluir }

class TelaListaProdutos extends StatefulWidget {
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
  final List<String> _gruposDeProduto = const ['CONSUMO', "EPI'S", 'MATERIA PRIMA', 'REVENDA'];
  String? _grupoFiltroSelecionado;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    if (widget.termoBuscaInicial != null && widget.termoBuscaInicial!.isNotEmpty) {
      setState(() {
        _isSearching = true;
        _searchController.text = widget.termoBuscaInicial!;
      });
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() {});
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
    if (valor == valor.truncate()) return valor.truncate().toString();
    return NumberFormat('#,##0.###', 'pt_BR').format(valor);
  }

  // Aplica filtros e ordenação em memória — mesma lógica do original
  List<Map<String, dynamic>> _aplicarFiltros(List<Map<String, dynamic>> todos) {
    var produtos = todos.where((p) {
      // Filtro de status
      if (_filtroAtual == FiltroProdutos.ativos ||
          _filtroAtual == FiltroProdutos.pontoDePedido) {
        if (p['ativo'] != true) return false;
      } else if (_filtroAtual == FiltroProdutos.inativos) {
        if (p['ativo'] == true) return false;
      }
      // Filtro de grupo
      if (_grupoFiltroSelecionado != null && p['grupo'] != _grupoFiltroSelecionado) return false;
      // Filtro de ponto de pedido
      if (_filtroAtual == FiltroProdutos.pontoDePedido) {
        final double qtd = (p['quantidadeAtual'] ?? 0.0).toDouble();
        final double min = (p['estoqueMinimo'] ?? 0.0).toDouble();
        if (!(qtd <= min && min > 0)) return false;
      }
      return true;
    }).toList();

    final String queryBusca = _searchController.text.toLowerCase().trim();
    if (queryBusca.isNotEmpty) {
      produtos = produtos.where((p) {
        final nome = (p['nome'] ?? '').toLowerCase();
        final codigo = (p['codigo'] ?? '').toLowerCase();
        return nome.contains(queryBusca) || codigo.contains(queryBusca);
      }).toList();

      produtos.sort((a, b) {
        final nomeA = (a['nome'] ?? '').toLowerCase();
        final codigoA = (a['codigo'] ?? '').toLowerCase();
        final nomeB = (b['nome'] ?? '').toLowerCase();
        final codigoB = (b['codigo'] ?? '').toLowerCase();

        int getScore(String nome, String codigo) {
          if (codigo == queryBusca) return 1;
          if (codigo.startsWith(queryBusca)) return 2;
          if (nome.startsWith(queryBusca)) return 3;
          if (nome.contains(queryBusca)) return 4;
          if (codigo.contains(queryBusca)) return 5;
          return 6;
        }

        final scoreA = getScore(nomeA, codigoA);
        final scoreB = getScore(nomeB, codigoB);
        return scoreA != scoreB ? scoreA.compareTo(scoreB) : nomeA.compareTo(nomeB);
      });
    } else {
      produtos.sort((a, b) {
        final qtdA = (a['quantidadeAtual'] ?? 0.0).toDouble();
        final minA = (a['estoqueMinimo'] ?? 0.0).toDouble();
        final qtdB = (b['quantidadeAtual'] ?? 0.0).toDouble();
        final minB = (b['estoqueMinimo'] ?? 0.0).toDouble();
        final nomeA = a['nome'] ?? '';
        final nomeB = b['nome'] ?? '';

        int getPrioridade(double qtd, double min) {
          if (qtd <= 0) return 1;
          if (qtd <= min && min > 0) return 2;
          return 3;
        }

        final prioA = getPrioridade(qtdA, minA);
        final prioB = getPrioridade(qtdB, minB);
        return prioA != prioB
            ? prioA.compareTo(prioB)
            : nomeA.toLowerCase().compareTo(nomeB.toLowerCase());
      });
    }

    return produtos;
  }

  @override
  Widget build(BuildContext context) {
    // Pega dados do usuário via provider — sem Firestore direto
    final usuario = context.watch<UsuarioProvider>().usuario;
    final permissao = usuario?.permissao ?? 'producao';
    final empresaId = usuario?.empresaId ?? '';

    return Scaffold(
      appBar: _buildAppBar(),
      body: empresaId.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Map<String, dynamic>>>(
        stream: context.read<ProdutoProvider>().streamProdutos(empresaId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Erro ao carregar os produtos.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final produtos = _aplicarFiltros(snapshot.data!);

          if (produtos.isEmpty) {
            final queryBusca = _searchController.text.trim();
            String msg = queryBusca.isNotEmpty
                ? 'Nenhum produto encontrado para "$queryBusca"'
                : _filtroAtual == FiltroProdutos.pontoDePedido
                ? 'Nenhum produto em ponto de pedido.'
                : 'Nenhum produto para exibir.';
            return Center(
                child: Text(msg,
                    style: const TextStyle(fontSize: 18, color: Colors.grey)));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80.0),
            itemCount: produtos.length,
            itemBuilder: (context, index) =>
                _buildCardProduto(context, produtos[index], permissao),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar() {
    String titulo = 'Lista de Produtos';
    if (_filtroAtual == FiltroProdutos.pontoDePedido) titulo = 'Ponto de Pedido';
    else if (_filtroAtual == FiltroProdutos.ativos) titulo = 'Produtos (Ativos)';
    else if (_filtroAtual == FiltroProdutos.inativos) titulo = 'Produtos (Inativos)';
    else if (_filtroAtual == FiltroProdutos.todos) titulo = 'Produtos (Todos)';

    if (!_isSearching) {
      return AppBar(
        title: Text(titulo),
        actions: [
          IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _isSearching = true)),
          PopupMenuButton<String>(
            icon: Icon(Icons.category,
                color: _grupoFiltroSelecionado != null ? Colors.blue : Colors.white),
            tooltip: 'Filtrar por Grupo',
            onSelected: (result) =>
                setState(() => _grupoFiltroSelecionado = result == 'TODOS' ? null : result),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'TODOS', child: Text('Todos os Grupos')),
              const PopupMenuDivider(),
              ..._gruposDeProduto.map((g) => PopupMenuItem(value: g, child: Text(g))),
            ],
          ),
          PopupMenuButton<FiltroProdutos>(
            icon: const Icon(Icons.filter_list),
            onSelected: (result) => setState(() => _filtroAtual = result),
            itemBuilder: (context) => [
              const PopupMenuItem(value: FiltroProdutos.ativos, child: Text('Ver Ativos')),
              const PopupMenuItem(
                value: FiltroProdutos.pontoDePedido,
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Ponto de Pedido'),
                ]),
              ),
              const PopupMenuItem(value: FiltroProdutos.inativos, child: Text('Ver Inativos')),
              const PopupMenuItem(value: FiltroProdutos.todos, child: Text('Ver Todos')),
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
            if (widget.termoBuscaInicial != null) Navigator.of(context).pop();
          }),
        ),
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
              onPressed: () => setState(() => _searchController.clear())),
        ],
      );
    }
  }

  Widget _buildCardProduto(BuildContext context, Map<String, dynamic> produto, String permissao) {
    final double quantidade = (produto['quantidadeAtual'] ?? 0.0).toDouble();
    final double estoqueMinimo = (produto['estoqueMinimo'] ?? 0.0).toDouble();
    final String? numeroSC = produto['numeroSC'];
    final double valorUnitario = (produto['valor'] ?? 0.0).toDouble();
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    Color statusColor = Theme.of(context).colorScheme.primary.withAlpha(179);
    String statusText = 'Estoque OK';

    if (quantidade <= 0) {
      statusColor = Colors.red.shade700;
      statusText = 'Estoque Zerado';
    } else if (quantidade <= estoqueMinimo && estoqueMinimo > 0) {
      statusColor = Colors.orange.shade800;
      statusText = 'Abaixo do Mínimo';
    }

    final bool podeAlterar = permissao == 'admin' || permissao == 'almoxarife';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
          side: BorderSide(color: statusColor, width: 1),
          borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 12, right: 0),
            leading: CircleAvatar(
              backgroundColor: statusColor,
              child: Text(_formatarQuantidade(quantidade),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            title: Text('${produto['codigo'] ?? 'N/A'} - ${produto['nome'] ?? 'Sem nome'}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(statusText,
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                      if (estoqueMinimo > 0 || (produto['estoqueMaximo'] ?? 0.0) > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                              'Min: ${_formatarQuantidade(estoqueMinimo)} / Max: ${_formatarQuantidade((produto['estoqueMaximo'] ?? 0.0).toDouble())}',
                              style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ),
                      if (numeroSC != null && numeroSC.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Chip(
                            label: Text('SC: $numeroSC',
                                style: const TextStyle(color: Colors.white, fontSize: 10)),
                            backgroundColor: Colors.blue.shade700,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(formatoMoeda.format(valorUnitario),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
                const SizedBox(width: 8),
              ],
            ),
            trailing: podeAlterar
                ? PopupMenuButton<AcoesProduto>(
              icon: const Icon(Icons.more_vert),
              onSelected: (acao) {
                switch (acao) {
                  case AcoesProduto.editar:
                  // Passa Map em vez de QueryDocumentSnapshot
                    Navigator.push(context, MaterialPageRoute(
                        builder: (c) => TelaCadastroProduto(produtoParaEditar: produto)));
                    break;
                  case AcoesProduto.solicitarCompra:
                    _mostrarDialogoSC(context, produto);
                    break;
                  case AcoesProduto.excluir:
                    _mostrarDialogoDeConfirmacao(context, produto);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: AcoesProduto.editar, child: Text('Editar')),
                const PopupMenuItem(value: AcoesProduto.solicitarCompra, child: Text('Solicitar Compra (SC)')),
                const PopupMenuItem(value: AcoesProduto.excluir, child: Text('Excluir')),
              ],
            )
                : null,
          ),
          if (podeAlterar)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildActionButton(context, 'ENTRADA', Icons.add_circle_outline, Colors.green,
                          () => Navigator.push(context, MaterialPageRoute(
                          builder: (c) => TelaMovimentacao(
                            produtoPreSelecionado: produto,
                            tipoMovimentacaoInicial: TipoMovimentacao.entrada,
                          )))),
                  const SizedBox(width: 8),
                  _buildActionButton(context, 'SAÍDA', Icons.remove_circle_outline, Colors.red,
                          () => Navigator.push(context, MaterialPageRoute(
                          builder: (c) => TelaMovimentacao(
                            produtoPreSelecionado: produto,
                            tipoMovimentacaoInicial: TipoMovimentacao.saida,
                          )))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon, Color color, VoidCallback onPressed) {
    return TextButton.icon(
      icon: Icon(icon, color: color, size: 20),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      onPressed: onPressed,
      style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    );
  }

  void _mostrarDialogoSC(BuildContext context, Map<String, dynamic> produto) {
    final scController = TextEditingController(text: produto['numeroSC'] ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Solicitação de Compra'),
        content: TextField(
          controller: scController,
          decoration: const InputDecoration(labelText: 'Número da SC'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await context.read<ProdutoProvider>().atualizar(
                  produto['id'], {'numeroSC': scController.text.trim()});
              if (mounted) navigator.pop();
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoDeConfirmacao(BuildContext context, Map<String, dynamic> produto) {
    final nomeProduto = produto['nome'] ?? 'este produto';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja excluir "$nomeProduto"?\nEsta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await context.read<ProdutoProvider>().excluir(produto['id']);
              if (mounted) navigator.pop();
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}