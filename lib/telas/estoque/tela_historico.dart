// lib/telas/estoque/tela_historico.dart
// TODO resolvido: carregamento de parceiros migrado para ParceiroProvider.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/movimentacao_provider.dart';
import 'package:protecin_producao/provider/parceiro_provider.dart';
import 'package:protecin_producao/provider/produto_provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';

class _ProdutoValor {
  final String nome;
  final double valor;
  _ProdutoValor({required this.nome, required this.valor});
}

class ProdutoComEstoqueHistorico {
  final String codigo;
  final String nome;
  final String? ncm;
  final double quantidade;
  final double custoUnitario;
  final double custoTotal;

  ProdutoComEstoqueHistorico({
    required this.codigo,
    required this.nome,
    this.ncm,
    required this.quantidade,
    required this.custoUnitario,
  }) : custoTotal = quantidade * custoUnitario;
}

class TelaRelatorios extends StatefulWidget {
  const TelaRelatorios({super.key});
  @override
  State<TelaRelatorios> createState() => _TelaRelatoriosState();
}

class _TelaRelatoriosState extends State<TelaRelatorios> {
  Future<Map<String, List<Map<String, dynamic>>>>? _dadosFuture;
  DateTime? _dataInicio;
  DateTime? _dataFim;
  Map<String, dynamic>? _parceiroSelecionado;
  DateTime? _dataHistoricaSelecionada;

  final TextEditingController _clienteAutocompleteController =
  TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregarDados();
    });
  }

  @override
  void dispose() {
    _clienteAutocompleteController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    final usuario =
        Provider.of<UsuarioProvider>(context, listen: false).usuario;
    if (usuario == null) {
      if (mounted) {
        setState(() =>
        _dadosFuture = Future.error('Usuário não autenticado.'));
      }
      return;
    }
    final empresaId = usuario.empresaId;

    // Todos os três via providers — sem Firestore direto
    final produtosFuture =
    context.read<ProdutoProvider>().buscarTodosPorEmpresa(empresaId);
    final movimentacoesFuture =
    context.read<MovimentacaoProvider>().buscarTodosPorEmpresa(empresaId);
    final parceirosFuture =
    context.read<ParceiroProvider>().buscarTodosPorEmpresa(empresaId);

    setState(() {
      _dadosFuture =
          Future.wait([produtosFuture, movimentacoesFuture, parceirosFuture])
              .then((results) => {
            'produtos': results[0],
            'movimentacoes': results[1],
            'parceiros': results[2],
          });
    });
  }

  List<ProdutoComEstoqueHistorico> _calcularEstoqueHistorico(
      List<Map<String, dynamic>> produtos,
      List<Map<String, dynamic>> movimentacoes,
      DateTime? dataAlvo) {
    if (dataAlvo == null) return [];
    final Map<String, double> quantidades = {
      for (var p in produtos) p['id']: (p['quantidadeAtual'] ?? 0).toDouble()
    };
    final dataAlvoFimDoDia =
    DateTime(dataAlvo.year, dataAlvo.month, dataAlvo.day, 23, 59, 59);
    final movimentacoesFuturas = movimentacoes.where((mov) {
      try {
        final dataMov = mov['data'] as DateTime;
        return dataMov.isAfter(dataAlvoFimDoDia);
      } catch (e) {
        return false;
      }
    });
    for (var mov in movimentacoesFuturas) {
      final produtoId = mov['produtoId'];
      final double quantidade = (mov['quantidade'] ?? 0).toDouble();
      final tipo = mov['tipo'];
      if (quantidades.containsKey(produtoId)) {
        if (tipo == 'entrada') {
          quantidades[produtoId] = quantidades[produtoId]! - quantidade;
        } else {
          quantidades[produtoId] = quantidades[produtoId]! + quantidade;
        }
      }
    }
    final List<ProdutoComEstoqueHistorico> resultado = [];
    for (var p in produtos) {
      final double qtdHistorica = quantidades[p['id']] ?? 0.0;
      if (qtdHistorica > 0.0001) {
        resultado.add(ProdutoComEstoqueHistorico(
          codigo: p['codigo'] ?? 'N/A',
          nome: p['nome'] ?? 'N/A',
          ncm: p['ncm'],
          quantidade: qtdHistorica,
          custoUnitario: (p['valor'] ?? 0.0).toDouble(),
        ));
      }
    }
    return resultado;
  }

  Future<void> _selecionarData(BuildContext context,
      {required bool isDataInicio}) async {
    final dataSelecionada = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (dataSelecionada != null) {
      setState(() {
        if (isDataInicio) {
          _dataInicio = dataSelecionada;
        } else {
          _dataFim = dataSelecionada;
        }
      });
    }
  }

  void _limparFiltroDePeriodo() {
    setState(() {
      _dataInicio = null;
      _dataFim = null;
    });
  }

  double _calcularValorTotalEstoque(List<Map<String, dynamic>> produtos) {
    return produtos.fold(
        0.0,
            (total, p) =>
        total +
            ((p['quantidadeAtual'] ?? 0).toDouble() *
                (p['valor'] ?? 0.0).toDouble()));
  }

  int _contarProdutosPontoDePedido(List<Map<String, dynamic>> produtos) {
    return produtos.where((p) {
      final double qtd = (p['quantidadeAtual'] ?? 0).toDouble();
      final double min = (p['estoqueMinimo'] ?? 0).toDouble();
      return qtd <= min && min > 0;
    }).length;
  }

  Map<String, double> _calcularGastoPorCentroDeCusto(
      List<Map<String, dynamic>> movimentacoes,
      Map<String, double> valoresProdutos,
      DateTime? dataInicio,
      DateTime? dataFim) {
    if (dataInicio == null || dataFim == null) return {};
    final gastosPorCC = <String, double>{};
    final fimDoDia =
    DateTime(dataFim.year, dataFim.month, dataFim.day, 23, 59, 59);
    final saidas = movimentacoes.where((mov) {
      try {
        final dataMov = mov['data'] as DateTime;
        final dentroDoPeriodo =
            !dataMov.isBefore(dataInicio) && dataMov.isBefore(fimDoDia);
        final cc = mov['centroDeCusto'];
        return mov['tipo'] == 'saida' &&
            cc != null &&
            cc.toString().isNotEmpty &&
            dentroDoPeriodo;
      } catch (e) {
        return false;
      }
    });
    for (var mov in saidas) {
      final cc = mov['centroDeCusto'].toString();
      final produtoId = mov['produtoId'];
      final double quantidade = (mov['quantidade'] ?? 0).toDouble();
      final valorProduto = valoresProdutos[produtoId] ?? 0.0;
      gastosPorCC.update(cc, (v) => v + (quantidade * valorProduto),
          ifAbsent: () => quantidade * valorProduto);
    }
    return gastosPorCC;
  }

  Map<String, List<_ProdutoValor>> _calcularCurvaABC(
      List<Map<String, dynamic>> movimentacoes,
      Map<String, double> valoresProdutos) {
    if (_dataInicio == null || _dataFim == null) {
      return {'A': [], 'B': [], 'C': []};
    }
    final Map<String, double> valorPorProduto = {};
    final fim =
    DateTime(_dataFim!.year, _dataFim!.month, _dataFim!.day, 23, 59, 59);
    final saidas = movimentacoes.where((mov) {
      try {
        final dataMov = mov['data'] as DateTime;
        return mov['tipo'] == 'saida' &&
            !dataMov.isBefore(_dataInicio!) &&
            dataMov.isBefore(fim);
      } catch (e) {
        return false;
      }
    });
    if (saidas.isEmpty) return {'A': [], 'B': [], 'C': []};
    for (var mov in saidas) {
      final produtoId = mov['produtoId'];
      final produtoNome = mov['produtoNome'] ?? 'Produto desconhecido';
      final double quantidade = (mov['quantidade'] ?? 0).toDouble();
      final valorUnitario = valoresProdutos[produtoId] ?? 0.0;
      valorPorProduto.update(
          produtoNome, (v) => v + (quantidade * valorUnitario),
          ifAbsent: () => quantidade * valorUnitario);
    }
    final listaOrdenada = valorPorProduto.entries
        .map((e) => _ProdutoValor(nome: e.key, valor: e.value))
        .toList()
      ..sort((a, b) => b.valor.compareTo(a.valor));
    final valorTotalSaidas =
    valorPorProduto.values.fold(0.0, (a, b) => a + b);
    if (valorTotalSaidas == 0) return {'A': [], 'B': [], 'C': []};
    final Map<String, List<_ProdutoValor>> curvaABC = {
      'A': [],
      'B': [],
      'C': []
    };
    double valorAcumulado = 0;
    for (var item in listaOrdenada) {
      valorAcumulado += item.valor;
      double pct = (valorAcumulado / valorTotalSaidas) * 100;
      if (pct <= 80) {
        curvaABC['A']!.add(item);
      } else if (pct <= 95) {
        curvaABC['B']!.add(item);
      } else {
        curvaABC['C']!.add(item);
      }
    }
    return curvaABC;
  }

  Map<String, Map<String, double>> _calcularConsumoPorCliente(
      List<Map<String, dynamic>> movimentacoes) {
    if (_parceiroSelecionado == null) return {};
    final nomeParceiroSelecionado = _parceiroSelecionado!['nome'];
    final consumoPorOS = <String, Map<String, double>>{};
    final movsFiltrados = movimentacoes.where((mov) =>
    (mov['subTipo'] == 'OS' ||
        mov['subTipo'] == 'Venda' ||
        mov['subTipo'] == 'Venda (NF)' ||
        mov['subTipo'] == 'Venda (Pedido)') &&
        mov['nomeCliente'] == nomeParceiroSelecionado);
    for (var mov in movsFiltrados) {
      final os = mov['numeroOS'] ??
          mov['numeroNF'] ??
          mov['numeroPedido'] ??
          'Não Identificado';
      final produto = mov['produtoNome'] ?? 'N/A';
      final double quantidade = (mov['quantidade'] ?? 0).toDouble();
      consumoPorOS.putIfAbsent(os, () => {});
      consumoPorOS[os]!
          .update(produto, (v) => v + quantidade, ifAbsent: () => quantidade);
    }
    return consumoPorOS;
  }

  double _calcularSaidasItau(
      List<Map<String, dynamic>> movimentacoes,
      Map<String, double> valoresProdutos,
      DateTime? dataInicio,
      DateTime? dataFim) {
    if (dataInicio == null || dataFim == null) return 0.0;
    double valorTotalItau = 0.0;
    final fimDoDia =
    DateTime(dataFim.year, dataFim.month, dataFim.day, 23, 59, 59);
    final saidasItau = movimentacoes.where((mov) {
      try {
        final dataMov = mov['data'] as DateTime;
        return mov['tipo'] == 'saida' &&
            mov['subTipo'] == 'Itau' &&
            !dataMov.isBefore(dataInicio) &&
            dataMov.isBefore(fimDoDia);
      } catch (e) {
        return false;
      }
    });
    for (var mov in saidasItau) {
      final produtoId = mov['produtoId'];
      final double quantidade = (mov['quantidade'] ?? 0).toDouble();
      valorTotalItau += (quantidade * (valoresProdutos[produtoId] ?? 0.0));
    }
    return valorTotalItau;
  }

  Map<String, dynamic> _calcularEstoqueRevenda(
      List<Map<String, dynamic>> produtos,
      List<ProdutoComEstoqueHistorico>? listaProdutosHistoricos) {
    final idsProdutosRevenda = produtos
        .where((p) => p['grupo'] == 'REVENDA')
        .map((p) => p['id'] as String)
        .toSet();

    List<ProdutoComEstoqueHistorico> itensRevenda;
    if (listaProdutosHistoricos != null) {
      final produtosMap = {for (var p in produtos) p['codigo']: p['id']};
      itensRevenda = listaProdutosHistoricos.where((p) {
        final produtoId = produtosMap[p.codigo];
        return produtoId != null && idsProdutosRevenda.contains(produtoId);
      }).toList();
    } else {
      itensRevenda = produtos
          .where((p) =>
      idsProdutosRevenda.contains(p['id']) &&
          (p['quantidadeAtual'] ?? 0).toDouble() > 0)
          .map((p) => ProdutoComEstoqueHistorico(
        codigo: p['codigo'] ?? 'N/A',
        nome: p['nome'] ?? 'N/A',
        ncm: p['ncm'],
        quantidade: (p['quantidadeAtual'] ?? 0).toDouble(),
        custoUnitario: (p['valor'] ?? 0.0).toDouble(),
      ))
          .toList();
    }
    final double valorTotalRevenda =
    itensRevenda.fold(0.0, (total, item) => total + item.custoTotal);
    return {'valorTotalRevenda': valorTotalRevenda, 'itensRevenda': itensRevenda};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard de Relatórios')),
      body: _dadosFuture == null
          ? const Center(
          child: Text('Carregando informações do usuário...'))
          : FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: _dadosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text(
                    'Erro ao carregar dados: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(
                child: Text(
                    'Nenhum dado encontrado para sua empresa.'));
          }

          final produtos = snapshot.data!['produtos']!;
          final movimentacoes = snapshot.data!['movimentacoes']!;
          final parceiros = snapshot.data!['parceiros']!;

          final clientes =
          parceiros.where((p) => p['tipo'] == 'cliente').toList();
          final produtosHistoricos = _calcularEstoqueHistorico(
              produtos, movimentacoes, _dataHistoricaSelecionada);
          final double valorTotalHistorico = produtosHistoricos.fold(
              0.0, (pv, p) => pv + p.custoTotal);
          final Map<String, double> valoresProdutos = {
            for (var p in produtos)
              p['id'] as String: (p['valor'] ?? 0.0).toDouble()
          };
          final formatadorMoeda =
          NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
          final valorTotal = _calcularValorTotalEstoque(produtos);
          final qtdPontoPedido =
          _contarProdutosPontoDePedido(produtos);
          final gastosPorCC = _calcularGastoPorCentroDeCusto(
              movimentacoes, valoresProdutos, _dataInicio, _dataFim);
          final curvaABC =
          _calcularCurvaABC(movimentacoes, valoresProdutos);
          final consumoPorCliente =
          _calcularConsumoPorCliente(movimentacoes);
          final relatorioRevenda = _calcularEstoqueRevenda(
              produtos,
              _dataHistoricaSelecionada != null
                  ? produtosHistoricos
                  : null);
          final totalSaidasItau = _calcularSaidasItau(
              movimentacoes, valoresProdutos, _dataInicio, _dataFim);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCardRelatorio(
                  titulo: 'Valor Total em Estoque',
                  cor: Colors.blue,
                  conteudo: Column(children: [
                    if (_dataHistoricaSelecionada != null) ...[
                      Text(
                          'Em ${DateFormat('dd/MM/yyyy').format(_dataHistoricaSelecionada!)}',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade700)),
                      const SizedBox(height: 8),
                      Text(
                          formatadorMoeda
                              .format(valorTotalHistorico),
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey)),
                    ] else ...[
                      Text('Hoje',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade700)),
                      const SizedBox(height: 8),
                      Text(formatadorMoeda.format(valorTotal),
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey)),
                    ],
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.calendar_today,
                              size: 16),
                          label: const Text('Ver Data Passada'),
                          onPressed: () async {
                            final dataSelecionada =
                            await showDatePicker(
                                context: context,
                                initialDate: DateTime.now()
                                    .subtract(
                                    const Duration(days: 1)),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().subtract(
                                    const Duration(days: 1)));
                            if (dataSelecionada != null) {
                              setState(() =>
                              _dataHistoricaSelecionada =
                                  dataSelecionada);
                            }
                          },
                        ),
                        if (_dataHistoricaSelecionada != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.clear,
                                color: Colors.red),
                            onPressed: () => setState(
                                    () => _dataHistoricaSelecionada = null),
                            tooltip: 'Limpar filtro de data',
                          ),
                        ],
                      ],
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                _buildCardRelatorio(
                  titulo: 'Produtos em Ponto de Pedido',
                  cor: qtdPontoPedido > 0
                      ? Colors.orange
                      : Colors.green,
                  conteudo: Text('$qtdPontoPedido',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey)),
                ),
                const SizedBox(height: 16),
                _buildCardRelatorio(
                  titulo: 'Gasto por Centro de Custo',
                  cor: Colors.red,
                  conteudo: Column(children: [
                    _buildSeletorDePeriodo(),
                    const Divider(height: 30),
                    if (_dataInicio == null || _dataFim == null)
                      const Text(
                          'Selecione um período para a análise.')
                    else if (gastosPorCC.isEmpty)
                      const Text(
                          'Nenhuma saída com centro de custo encontrada no período.')
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...gastosPorCC.entries.map((e) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4.0),
                              child: Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('CC ${e.key}:',
                                        style: const TextStyle(
                                            fontWeight:
                                            FontWeight.bold)),
                                    Text(
                                        formatadorMoeda.format(e.value),
                                        style: const TextStyle(
                                            fontSize: 16))
                                  ]))),
                          const Divider(height: 20, thickness: 1.5),
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total no Período:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Text(
                                formatadorMoeda.format(gastosPorCC
                                    .values
                                    .fold(0.0, (a, b) => a + b)),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.red),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ]),
                ),
                const SizedBox(height: 16),
                _buildCardRelatorio(
                  titulo: 'Saídas para Itaú (Consumo Interno)',
                  cor: Colors.amber.shade800,
                  conteudo: Column(children: [
                    _buildSeletorDePeriodo(),
                    const Divider(height: 30),
                    if (_dataInicio == null || _dataFim == null)
                      const Text(
                          'Selecione um período para a análise.')
                    else if (totalSaidasItau == 0)
                      const Text(
                          'Nenhuma saída para o Itaú encontrada no período.')
                    else
                      Text(formatadorMoeda.format(totalSaidasItau),
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey)),
                  ]),
                ),
                const SizedBox(height: 16),
                _buildCardRelatorio(
                  titulo:
                  'Curva ABC de Produtos (Baseado em Saídas)',
                  cor: Colors.purple,
                  conteudo: Column(children: [
                    _buildSeletorDePeriodo(),
                    const Divider(height: 30),
                    if (_dataInicio == null || _dataFim == null)
                      const Text(
                          'Selecione um período para a análise.')
                    else if (curvaABC['A']!.isEmpty &&
                        curvaABC['B']!.isEmpty &&
                        curvaABC['C']!.isEmpty)
                      const Text(
                          'Nenhuma saída encontrada no período.')
                    else
                      _buildConteudoCurvaABC(curvaABC),
                  ]),
                ),
                const SizedBox(height: 16),
                _buildCardRelatorio(
                  titulo: 'Análise de Consumo por Cliente',
                  cor: Colors.cyan,
                  conteudo: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Autocomplete<Map<String, dynamic>>(
                        displayStringForOption: (option) =>
                        option['nome'] ?? '',
                        fieldViewBuilder: (context,
                            textEditingController,
                            focusNode,
                            onFieldSubmitted) {
                          return TextFormField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: 'Buscar Cliente por Nome',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  textEditingController.clear();
                                  FocusScope.of(context).unfocus();
                                  setState(() =>
                                  _parceiroSelecionado = null);
                                },
                              ),
                            ),
                          );
                        },
                        optionsBuilder: (textEditingValue) {
                          final query =
                          textEditingValue.text.toLowerCase();
                          if (query.isEmpty) {
                            return const Iterable<
                                Map<String, dynamic>>.empty();
                          }
                          return clientes.where((p) => (p['nome'] ?? '')
                              .toLowerCase()
                              .contains(query));
                        },
                        onSelected: (selection) {
                          FocusScope.of(context).unfocus();
                          setState(
                                  () => _parceiroSelecionado = selection);
                        },
                      ),
                      const Divider(height: 30),
                      if (_parceiroSelecionado == null)
                        const Center(
                            child: Text(
                                'Selecione um cliente para ver o consumo.'))
                      else if (consumoPorCliente.isEmpty)
                        const Center(
                            child: Text(
                                'Nenhum consumo por OS/Venda encontrado para este cliente.'))
                      else
                        ...consumoPorCliente.entries.map((entryOS) =>
                            ExpansionTile(
                              title: Text('OS/NF: ${entryOS.key}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              children: entryOS.value.entries
                                  .map((entryProduto) => ListTile(
                                dense: true,
                                title:
                                Text(entryProduto.key),
                                trailing: Text(
                                    '${entryProduto.value.toStringAsFixed(3).replaceAll('.', ',')} un'),
                              ))
                                  .toList(),
                            )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildCardRelatorio(
                  titulo: 'Estoque de Revenda',
                  cor: Colors.green,
                  conteudo: Column(children: [
                    Text(
                        _dataHistoricaSelecionada != null
                            ? 'Valor em ${DateFormat('dd/MM/yyyy').format(_dataHistoricaSelecionada!)}'
                            : 'Valor Atual',
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Text(
                        formatadorMoeda.format(
                            relatorioRevenda['valorTotalRevenda']),
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.green)),
                    const Divider(height: 24),
                    if ((relatorioRevenda['itensRevenda'] as List)
                        .isNotEmpty)
                      ExpansionTile(
                        title:
                        const Text('Ver Itens Detalhados'),
                        children: [
                          _buildTabelaEstoqueDetalhado(
                              relatorioRevenda['itensRevenda']
                              as List<ProdutoComEstoqueHistorico>)
                        ],
                      )
                    else
                      const Text(
                          'Nenhum item de revenda em estoque para esta data.'),
                    if ((relatorioRevenda['itensRevenda'] as List)
                        .isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.file_download),
                        label:
                        const Text('Exportar Itens de Revenda'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _exportarEstoqueRevenda(
                            relatorioRevenda['itensRevenda']
                            as List<ProdutoComEstoqueHistorico>),
                      ),
                    ],
                  ]),
                ),
                if (_dataHistoricaSelecionada != null) ...[
                  const SizedBox(height: 16),
                  _buildCardRelatorio(
                    titulo: 'Detalhes do Estoque na Data',
                    cor: Colors.brown,
                    conteudo: _buildTabelaEstoqueDetalhado(
                        produtosHistoricos),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabelaEstoqueDetalhado(
      List<ProdutoComEstoqueHistorico> produtos) {
    final formatoMoeda =
    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    if (produtos.isEmpty) {
      return const Center(
          child:
          Text('Nenhum produto em estoque na data selecionada.'));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        columns: const [
          DataColumn(
              label: Text('Código',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Produto',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('NCM',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Qtd.',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              numeric: true),
          DataColumn(
              label: Text('Custo Unit.',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              numeric: true),
          DataColumn(
              label: Text('Custo Total',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              numeric: true),
        ],
        rows: produtos
            .map((p) => DataRow(cells: [
          DataCell(Text(p.codigo)),
          DataCell(Text(p.nome)),
          DataCell(Text(p.ncm ?? '-')),
          DataCell(Text(p.quantidade
              .toStringAsFixed(3)
              .replaceAll('.', ','))),
          DataCell(Text(formatoMoeda.format(p.custoUnitario))),
          DataCell(Text(formatoMoeda.format(p.custoTotal))),
        ]))
            .toList(),
      ),
    );
  }

  Widget _buildCardRelatorio(
      {required String titulo,
        required Widget conteudo,
        required Color cor}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
          side: BorderSide(color: cor.withAlpha(150), width: 1.5),
          borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cor)),
          const Divider(height: 20, thickness: 1),
          Center(child: conteudo),
        ]),
      ),
    );
  }

  Widget _buildConteudoCurvaABC(
      Map<String, List<_ProdutoValor>> curvaABC) {
    final formatadorMoeda =
    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSecaoABC(
              'CLASSE A (80% do Valor)', curvaABC['A']!, formatadorMoeda),
          _buildSecaoABC(
              'CLASSE B (15% do Valor)', curvaABC['B']!, formatadorMoeda),
          _buildSecaoABC(
              'CLASSE C (5% do Valor)', curvaABC['C']!, formatadorMoeda),
        ]);
  }

  Widget _buildSecaoABC(String titulo, List<_ProdutoValor> produtos,
      NumberFormat formatador) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(titulo,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.purple)),
          ),
          if (produtos.isEmpty)
            const Padding(
                padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                child: Text('-',
                    style: TextStyle(fontStyle: FontStyle.italic)))
          else
            ...produtos.map((p) => ListTile(
                dense: true,
                title: Text(p.nome),
                trailing: Text(formatador.format(p.valor)))),
          const Divider(),
        ]);
  }

  Widget _buildSeletorDePeriodo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(_dataInicio == null
              ? 'Data Início'
              : DateFormat('dd/MM/yyyy').format(_dataInicio!)),
          onPressed: () => _selecionarData(context, isDataInicio: true),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(_dataFim == null
              ? 'Data Fim'
              : DateFormat('dd/MM/yyyy').format(_dataFim!)),
          onPressed: () => _selecionarData(context, isDataInicio: false),
        ),
        if (_dataInicio != null || _dataFim != null)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: IconButton(
              icon: const Icon(Icons.clear, color: Colors.red),
              onPressed: _limparFiltroDePeriodo,
              tooltip: 'Limpar filtro de período',
            ),
          ),
      ],
    );
  }

  Future<void> _exportarEstoqueRevenda(
      List<ProdutoComEstoqueHistorico> itensRevenda) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (itensRevenda.isEmpty) {
      scaffoldMessenger.showSnackBar(const SnackBar(
          content: Text('Nenhum item de revenda para exportar.'),
          backgroundColor: Colors.orange));
      return;
    }
    try {
      scaffoldMessenger.showSnackBar(const SnackBar(
          content: Text('Gerando Excel... Por favor, aguarde.'),
          backgroundColor: Colors.blue));
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Estoque Revenda'];
      sheetObject.appendRow(
          ['Código', 'Nome', 'NCM', 'Quantidade', 'Custo Unitário', 'Custo Total']
              .map((h) => TextCellValue(h))
              .toList());
      final formatadorMoeda =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
      for (var item in itensRevenda) {
        sheetObject.appendRow([
          TextCellValue(item.codigo),
          TextCellValue(item.nome),
          TextCellValue(item.ncm ?? '-'),
          DoubleCellValue(item.quantidade),
          TextCellValue(formatadorMoeda.format(item.custoUnitario)),
          TextCellValue(formatadorMoeda.format(item.custoTotal)),
        ]);
      }
      final timestamp =
      DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Estoque_Revenda_$timestamp.xlsx';
      var fileBytes = excel.save();
      if (kIsWeb) {
        if (fileBytes != null) {
          final blob = html.Blob([fileBytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          html.AnchorElement(href: url)
            ..setAttribute('download', fileName)
            ..click();
          html.Url.revokeObjectUrl(url);
        }
      } else {
        if (fileBytes != null) {
          final directory = await getTemporaryDirectory();
          final filePath = '${directory.path}/$fileName';
          File(filePath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(fileBytes);
          await Share.shareXFiles([XFile(filePath)],
              text: 'Relatório de Estoque de Revenda');
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(
            content: Text('Erro ao exportar: $e'),
            backgroundColor: Colors.red));
      }
    }
  }
}