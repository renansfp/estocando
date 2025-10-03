// CÓDIGO ATUALIZADO COM CORREÇÃO PARA NÚMEROS DECIMAIS (double)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estocando/telas/tela_cadastro_parceiro.dart'; // Você pode remover este import se não for usado.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class _ProdutoValor {
  final String nome;
  final double valor;
  _ProdutoValor({required this.nome, required this.valor});
}

class ProdutoComEstoqueHistorico {
  final String codigo;
  final String nome;
  // ---> MUDANÇA 1: A quantidade agora é 'double' para aceitar decimais.
  final double quantidade;
  final double custoUnitario;
  final double custoTotal;

  ProdutoComEstoqueHistorico({
    required this.codigo,
    required this.nome,
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
  late Future<Map<String, QuerySnapshot>> _dadosFuture;
  DateTime? _dataInicio;
  DateTime? _dataFim;
  QueryDocumentSnapshot? _parceiroSelecionadoParaAnalise;
  DateTime? _dataHistoricaSelecionada;

  final TextEditingController _clienteAutocompleteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dadosFuture = _carregarDadosDoFirebase();
  }

  @override
  void dispose() {
    _clienteAutocompleteController.dispose();
    super.dispose();
  }

  // ---> MUDANÇA 2: Ajustes cruciais na função de cálculo histórico para usar 'double'.
  List<ProdutoComEstoqueHistorico> _calcularEstoqueHistorico(List<QueryDocumentSnapshot> produtos, List<QueryDocumentSnapshot> movimentacoes, DateTime? dataAlvo) {
    if (dataAlvo == null) return [];

    // O mapa de quantidades agora armazena 'double'.
    final Map<String, double> quantidades = {
      for (var p in produtos) p.id: ((p.data() as Map<String, dynamic>)['quantidadeAtual'] ?? 0).toDouble()
    };

    final dataAlvoFimDoDia = DateTime(dataAlvo.year, dataAlvo.month, dataAlvo.day, 23, 59, 59);

    final movimentacoesFuturas = movimentacoes.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      try {
        final dataMov = DateTime.parse(data['data']);
        return dataMov.isAfter(dataAlvoFimDoDia);
      } catch (e) {
        return false;
      }
    });

    for (var movDoc in movimentacoesFuturas) {
      final movData = movDoc.data() as Map<String, dynamic>;
      final produtoId = movData['produtoId'];
      // A quantidade da movimentação agora é lida como 'double'.
      final double quantidade = (movData['quantidade'] ?? 0).toDouble();
      final tipo = movData['tipo'];

      if (quantidades.containsKey(produtoId)) {
        if (tipo == 'entrada') {
          quantidades[produtoId] = quantidades[produtoId]! - quantidade;
        } else {
          quantidades[produtoId] = quantidades[produtoId]! + quantidade;
        }
      }
    }

    final List<ProdutoComEstoqueHistorico> produtosHistoricos = [];
    for (var p in produtos) {
      final pData = p.data() as Map<String, dynamic>;
      final double quantidadeHistorica = quantidades[p.id] ?? 0.0;

      if (quantidadeHistorica > 0.0001) { // Usamos uma pequena margem para evitar problemas de arredondamento de double
        produtosHistoricos.add(
          ProdutoComEstoqueHistorico(
            codigo: pData['codigo'] ?? 'N/A',
            nome: pData['nome'] ?? 'N/A',
            quantidade: quantidadeHistorica,
            custoUnitario: (pData['valor'] ?? 0.0).toDouble(),
          ),
        );
      }
    }
    return produtosHistoricos;
  }

  // ---> MUDANÇA 3: Pequeno ajuste na função de revenda para usar 'double'.
  Map<String, dynamic> _calcularEstoqueRevenda(List<QueryDocumentSnapshot> produtos, List<ProdutoComEstoqueHistorico>? listaProdutosHistoricos) {
    final idsProdutosRevenda = produtos.where((doc) => (doc.data() as Map<String, dynamic>)['grupo'] == 'REVENDA').map((doc) => doc.id).toSet();
    List<ProdutoComEstoqueHistorico> itensRevenda;
    if (listaProdutosHistoricos != null) {
      final produtosMap = {for (var p in produtos) (p.data() as Map<String,dynamic>)['codigo'] : p.id};
      itensRevenda = listaProdutosHistoricos.where((p) {
        final produtoId = produtosMap[p.codigo];
        return produtoId != null && idsProdutosRevenda.contains(produtoId);
      }).toList();
    } else {
      itensRevenda = produtos.where((p) => idsProdutosRevenda.contains(p.id) && ((p.data() as Map<String, dynamic>)['quantidadeAtual'] ?? 0).toDouble() > 0).map((p) {
        final pData = p.data() as Map<String, dynamic>;
        return ProdutoComEstoqueHistorico(
          codigo: pData['codigo'] ?? 'N/A',
          nome: pData['nome'] ?? 'N/A',
          quantidade: (pData['quantidadeAtual'] ?? 0).toDouble(),
          custoUnitario: (pData['valor'] ?? 0.0).toDouble(),
        );
      }).toList();
    }
    final double valorTotalRevenda = itensRevenda.fold(0.0, (total, item) => total + item.custoTotal);
    return {'valorTotalRevenda': valorTotalRevenda, 'itensRevenda': itensRevenda};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard de Relatórios')),
      body: FutureBuilder<Map<String, QuerySnapshot>>(
        future: _dadosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar dados: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum dado encontrado.'));
          }

          final produtos = snapshot.data!['produtos']!.docs;
          final movimentacoes = snapshot.data!['movimentacoes']!.docs;
          final parceiros = snapshot.data!['parceiros']!.docs;

          final List<QueryDocumentSnapshot> clientes = parceiros.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['tipo'] == 'cliente';
          }).toList();

          final List<ProdutoComEstoqueHistorico> produtosHistoricos = _calcularEstoqueHistorico(produtos, movimentacoes, _dataHistoricaSelecionada);
          final double valorTotalHistorico = produtosHistoricos.fold(0.0, (previousValue, produto) => previousValue + produto.custoTotal);
          final Map<String, double> valoresProdutos = { for (var p in produtos) p.id: (p.data() as Map<String, dynamic>)['valor'] ?? 0.0 };
          final formatadorMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
          final valorTotal = _calcularValorTotalEstoque(produtos);
          final qtdPontoPedido = _contarProdutosPontoDePedido(produtos);
          final gastosPorCC = _calcularGastoPorCentroDeCusto(movimentacoes, valoresProdutos, _dataInicio, _dataFim);
          final curvaABC = _calcularCurvaABC(movimentacoes, valoresProdutos);
          final consumoPorCliente = _calcularConsumoPorCliente(movimentacoes, produtos);
          final relatorioRevenda = _calcularEstoqueRevenda(produtos, _dataHistoricaSelecionada != null ? produtosHistoricos : null);
          final totalSaidasItau = _calcularSaidasItau(movimentacoes, valoresProdutos, _dataInicio, _dataFim);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCardRelatorio(
                  titulo: 'Valor Total em Estoque',
                  cor: Colors.blue,
                  conteudo: Column(
                    children: [
                      if (_dataHistoricaSelecionada != null) ...[
                        Text('Em ${DateFormat('dd/MM/yyyy').format(_dataHistoricaSelecionada!)}', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                        const SizedBox(height: 8),
                        Text(formatadorMoeda.format(valorTotalHistorico), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      ] else ...[
                        Text('Hoje', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                        const SizedBox(height: 8),
                        Text(formatadorMoeda.format(valorTotal), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      ],
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: const Text('Ver Data Passada'),
                            onPressed: () async {
                              final dataSelecionada = await showDatePicker(context: context, initialDate: DateTime.now().subtract(const Duration(days: 1)), firstDate: DateTime(2020), lastDate: DateTime.now().subtract(const Duration(days: 1)));
                              if (dataSelecionada != null) {
                                setState(() { _dataHistoricaSelecionada = dataSelecionada; });
                              }
                            },
                          ),
                          if (_dataHistoricaSelecionada != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.red),
                              onPressed: () { setState(() { _dataHistoricaSelecionada = null; }); },
                              tooltip: 'Limpar filtro de data',
                            )
                          ]
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildCardRelatorio(
                  titulo: 'Produtos em Ponto de Pedido',
                  cor: qtdPontoPedido > 0 ? Colors.orange : Colors.green,
                  conteudo: Text('$qtdPontoPedido', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                ),
                const SizedBox(height: 16),
                _buildCardRelatorio(
                  titulo: 'Gasto por Centro de Custo',
                  cor: Colors.red,
                  conteudo: Column(
                    children: [
                      _buildSeletorDePeriodo(),
                      const Divider(height: 30),
                      if (_dataInicio == null || _dataFim == null)
                        const Text('Selecione um período para a análise.')
                      else if (gastosPorCC.isEmpty)
                        const Text('Nenhuma saída com centro de custo encontrada no período.')
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...gastosPorCC.entries.map((entry) =>
                                Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('CC ${entry.key}:', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          Text(formatadorMoeda.format(entry.value), style: const TextStyle(fontSize: 16))
                                        ]
                                    )
                                )
                            ).toList(),
                            const Divider(height: 20, thickness: 1.5),
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total no Período:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(
                                    formatadorMoeda.format(gastosPorCC.values.fold(0.0, (a, b) => a + b)),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildCardRelatorio(
                  titulo: 'Saídas para Itaú (Consumo Interno)',
                  cor: Colors.amber.shade800,
                  conteudo: Column(
                    children: [
                      _buildSeletorDePeriodo(),
                      const Divider(height: 30),
                      if (_dataInicio == null || _dataFim == null)
                        const Text('Selecione um período para a análise.')
                      else if (totalSaidasItau == 0)
                        const Text('Nenhuma saída para o Itaú encontrada no período.')
                      else
                        Text(
                          formatadorMoeda.format(totalSaidasItau),
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildCardRelatorio(
                  titulo: 'Curva ABC de Produtos (Baseado em Saídas)',
                  cor: Colors.purple,
                  conteudo: Column(
                    children: [
                      _buildSeletorDePeriodo(),
                      const Divider(height: 30),
                      if (_dataInicio == null || _dataFim == null)
                        const Text('Selecione um período para a análise.')
                      else if (curvaABC.isEmpty || (curvaABC['A']!.isEmpty && curvaABC['B']!.isEmpty && curvaABC['C']!.isEmpty))
                        const Text('Nenhuma saída encontrada no período.')
                      else
                        _buildConteudoCurvaABC(curvaABC),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildCardRelatorio(
                  titulo: 'Análise de Consumo por Cliente',
                  cor: Colors.cyan,
                  conteudo: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Autocomplete<QueryDocumentSnapshot>(
                        displayStringForOption: (option) {
                          final data = option.data() as Map<String, dynamic>;
                          return data['nome'] ?? 'Nome não encontrado';
                        },
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
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
                                    setState(() {
                                      _parceiroSelecionadoParaAnalise = null;
                                    });
                                  },
                                )
                            ),
                          );
                        },
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          final query = textEditingValue.text.toLowerCase();
                          if (query.isEmpty) {
                            return const Iterable<QueryDocumentSnapshot>.empty();
                          }
                          return clientes.where((option) {
                            final data = option.data() as Map<String, dynamic>;
                            final nome = (data['nome'] ?? '').toLowerCase();
                            return nome.contains(query);
                          });
                        },
                        onSelected: (selection) {
                          FocusScope.of(context).unfocus();
                          setState(() {
                            _parceiroSelecionadoParaAnalise = selection;
                          });
                        },
                      ),
                      const Divider(height: 30),
                      if (_parceiroSelecionadoParaAnalise == null)
                        const Center(child: Text('Selecione um cliente para ver o consumo.'))
                      else if (consumoPorCliente.isEmpty)
                        const Center(child: Text('Nenhum consumo por OS/Venda encontrado para este cliente.'))
                      else
                        ...consumoPorCliente.entries.map((entryOS) => ExpansionTile(
                          title: Text('OS/NF: ${entryOS.key}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          children: entryOS.value.entries.map((entryProduto) => ListTile(
                            dense: true,
                            title: Text(entryProduto.key),
                            trailing: Text('${entryProduto.value.toStringAsFixed(3).replaceAll('.', ',')} un'),
                          )).toList(),
                        )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildCardRelatorio(
                  titulo: 'Estoque de Revenda',
                  cor: Colors.green,
                  conteudo: Column(
                    children: [
                      if (_dataHistoricaSelecionada != null)
                        Text('Valor em ${DateFormat('dd/MM/yyyy').format(_dataHistoricaSelecionada!)}', style: TextStyle(fontSize: 16, color: Colors.grey.shade700))
                      else
                        Text('Valor Atual', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                      const SizedBox(height: 8),
                      Text(
                        formatadorMoeda.format(relatorioRevenda['valorTotalRevenda']),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      const Divider(height: 24),
                      if ((relatorioRevenda['itensRevenda'] as List).isNotEmpty)
                        ExpansionTile(
                          title: const Text('Ver Itens Detalhados'),
                          children: [
                            _buildTabelaEstoqueDetalhado(relatorioRevenda['itensRevenda'] as List<ProdutoComEstoqueHistorico>)
                          ],
                        )
                      else
                        const Text('Nenhum item de revenda em estoque para esta data.'),
                    ],
                  ),
                ),
                if (_dataHistoricaSelecionada != null) ...[
                  const SizedBox(height: 16),
                  _buildCardRelatorio(
                    titulo: 'Detalhes do Estoque na Data',
                    cor: Colors.brown,
                    conteudo: _buildTabelaEstoqueDetalhado(produtosHistoricos),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, QuerySnapshot>> _carregarDadosDoFirebase() async {
    final db = FirebaseFirestore.instance;
    final produtosFuture = db.collection('produtos').get();
    final movimentacoesFuture = db.collection('movimentacoes').get();
    final parceirosFuture = db.collection('parceiros').get();
    final results = await Future.wait([produtosFuture, movimentacoesFuture, parceirosFuture]);
    return { 'produtos': results[0], 'movimentacoes': results[1], 'parceiros': results[2] };
  }

  double _calcularValorTotalEstoque(List<QueryDocumentSnapshot> produtos) {
    return produtos.fold(0.0, (total, doc) {
      final data = doc.data() as Map<String, dynamic>;
      return total + (((data['quantidadeAtual'] ?? 0).toDouble()) * ((data['valor'] ?? 0.0).toDouble()));
    });
  }

  int _contarProdutosPontoDePedido(List<QueryDocumentSnapshot> produtos) {
    return produtos.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final double quantidadeAtual = (data['quantidadeAtual'] ?? 0).toDouble();
      final double estoqueMinimo = (data['estoqueMinimo'] ?? 0).toDouble();
      return quantidadeAtual <= estoqueMinimo && estoqueMinimo > 0;
    }).length;
  }

  Map<String, double> _calcularGastoPorCentroDeCusto(List<QueryDocumentSnapshot> movimentacoes, Map<String, double> valoresProdutos, DateTime? dataInicio, DateTime? dataFim) {
    if (dataInicio == null || dataFim == null) return {};
    final gastosPorCC = <String, double>{};
    final fimDoDia = DateTime(dataFim.year, dataFim.month, dataFim.day, 23, 59, 59);
    final saidas = movimentacoes.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      try {
        final dataMov = DateTime.parse(data['data']);
        final dentroDoPeriodo = !dataMov.isBefore(dataInicio) && dataMov.isBefore(fimDoDia);
        return data['tipo'] == 'saida' && data['centroDeCusto'] != null && data['centroDeCusto']!.isNotEmpty && dentroDoPeriodo;
      } catch (e) { return false; }
    });
    for (var movDoc in saidas) {
      final movData = movDoc.data() as Map<String, dynamic>;
      final cc = movData['centroDeCusto']!;
      final produtoId = movData['produtoId'];
      final double quantidade = (movData['quantidade'] ?? 0).toDouble();
      final valorProduto = valoresProdutos[produtoId] ?? 0.0;
      gastosPorCC.update(cc, (v) => v + (quantidade * valorProduto), ifAbsent: () => quantidade * valorProduto);
    }
    return gastosPorCC;
  }

  Map<String, List<_ProdutoValor>> _calcularCurvaABC(List<QueryDocumentSnapshot> movimentacoes, Map<String, double> valoresProdutos) {
    if (_dataInicio == null || _dataFim == null) return {'A': [], 'B': [], 'C': []};
    final Map<String, double> valorPorProduto = {};
    final fim = DateTime(_dataFim!.year, _dataFim!.month, _dataFim!.day, 23, 59, 59);
    final saidas = movimentacoes.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      try {
        final dataMov = DateTime.parse(data['data']);
        return data['tipo'] == 'saida' && !dataMov.isBefore(_dataInicio!) && dataMov.isBefore(fim);
      } catch (e) { return false; }
    });
    if (saidas.isEmpty) return {'A': [], 'B': [], 'C': []};
    for (var movDoc in saidas) {
      final movData = movDoc.data() as Map<String, dynamic>;
      final produtoId = movData['produtoId'];
      final produtoNome = movData['produtoNome'] ?? 'Produto desconhecido';
      final double quantidade = (movData['quantidade'] ?? 0).toDouble();
      final valorUnitario = valoresProdutos[produtoId] ?? 0.0;
      valorPorProduto.update(produtoNome, (v) => v + (quantidade * valorUnitario), ifAbsent: () => (quantidade * valorUnitario));
    }
    final listaOrdenada = valorPorProduto.entries.map((e) => _ProdutoValor(nome: e.key, valor: e.value)).toList();
    listaOrdenada.sort((a, b) => b.valor.compareTo(a.valor));
    final valorTotalSaidas = valorPorProduto.values.fold(0.0, (a, b) => a + b);
    if (valorTotalSaidas == 0) return {'A': [], 'B': [], 'C': []};
    final Map<String, List<_ProdutoValor>> curvaABC = {'A': [], 'B': [], 'C': []};
    double valorAcumulado = 0;
    for (var item in listaOrdenada) {
      valorAcumulado += item.valor;
      double porcentagemAcumulada = (valorAcumulado / valorTotalSaidas) * 100;
      if (porcentagemAcumulada <= 80) { curvaABC['A']!.add(item); }
      else if (porcentagemAcumulada <= 95) { curvaABC['B']!.add(item); }
      else { curvaABC['C']!.add(item); }
    }
    return curvaABC;
  }

  Map<String, Map<String, double>> _calcularConsumoPorCliente(List<QueryDocumentSnapshot> movimentacoes, List<QueryDocumentSnapshot> produtos) {
    if (_parceiroSelecionadoParaAnalise == null) return {};
    final dadosParceiro = _parceiroSelecionadoParaAnalise!.data() as Map<String, dynamic>;
    final nomeParceiroSelecionado = dadosParceiro['nome'];
    final consumoPorOS = <String, Map<String, double>>{};
    final movsFiltrados = movimentacoes.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return (data['subTipo'] == 'OS' || data['subTipo'] == 'Venda') && data['nomeCliente'] == nomeParceiroSelecionado;
    });
    for (var movDoc in movsFiltrados) {
      final movData = movDoc.data() as Map<String, dynamic>;
      final os = movData['numeroOS'] ?? movData['numeroNF'] ?? 'Não Identificado';
      final produto = movData['produtoNome'] ?? 'N/A';
      final double quantidade = (movData['quantidade'] ?? 0).toDouble();
      consumoPorOS.putIfAbsent(os, () => {});
      consumoPorOS[os]!.update(produto, (v) => v + quantidade, ifAbsent: () => quantidade);
    }
    return consumoPorOS;
  }

  double _calcularSaidasItau(List<QueryDocumentSnapshot> movimentacoes, Map<String, double> valoresProdutos, DateTime? dataInicio, DateTime? dataFim) {
    if (dataInicio == null || dataFim == null) return 0.0;
    double valorTotalItau = 0.0;
    final fimDoDia = DateTime(dataFim.year, dataFim.month, dataFim.day, 23, 59, 59);
    final saidasItau = movimentacoes.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      try {
        final dataMov = DateTime.parse(data['data']);
        final dentroDoPeriodo = !dataMov.isBefore(dataInicio) && dataMov.isBefore(fimDoDia);
        return data['tipo'] == 'saida' && data['subTipo'] == 'Itau' && dentroDoPeriodo;
      } catch(e) { return false; }
    });
    for (var movDoc in saidasItau) {
      final movData = movDoc.data() as Map<String, dynamic>;
      final produtoId = movData['produtoId'];
      final double quantidade = (movData['quantidade'] ?? 0).toDouble();
      final valorProduto = valoresProdutos[produtoId] ?? 0.0;
      valorTotalItau += (quantidade * valorProduto);
    }
    return valorTotalItau;
  }

  Widget _buildTabelaEstoqueDetalhado(List<ProdutoComEstoqueHistorico> produtos) {
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    if (produtos.isEmpty) {
      return const Center(child: Text('Nenhum produto em estoque na data selecionada.'));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        columns: const [
          DataColumn(label: Text('Código', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Produto', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Qtd.', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text('Custo Unit.', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text('Custo Total', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
        ],
        rows: produtos.map((produto) {
          return DataRow(
            cells: [
              DataCell(Text(produto.codigo)),
              DataCell(Text(produto.nome)),
              DataCell(Text(produto.quantidade.toStringAsFixed(3).replaceAll('.', ','))),
              DataCell(Text(formatoMoeda.format(produto.custoUnitario))),
              DataCell(Text(formatoMoeda.format(produto.custoTotal))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCardRelatorio({required String titulo, required Widget conteudo, required Color cor}) {
    return Card(elevation: 4, shape: RoundedRectangleBorder(side: BorderSide(color: cor.withAlpha(150), width: 1.5), borderRadius: BorderRadius.circular(10)), child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(titulo, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cor)), const Divider(height: 20, thickness: 1), Center(child: conteudo)])));
  }

  Widget _buildConteudoCurvaABC(Map<String, List<_ProdutoValor>> curvaABC) {
    final formatadorMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_buildSecaoABC('CLASSE A (80% do Valor)', curvaABC['A']!, formatadorMoeda), _buildSecaoABC('CLASSE B (15% do Valor)', curvaABC['B']!, formatadorMoeda), _buildSecaoABC('CLASSE C (5% do Valor)', curvaABC['C']!, formatadorMoeda)]);
  }

  Widget _buildSecaoABC(String titulo, List<_ProdutoValor> produtos, NumberFormat formatador) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple))), if (produtos.isEmpty) const Padding(padding: EdgeInsets.only(left: 8.0, bottom: 8.0), child: Text('-', style: TextStyle(fontStyle: FontStyle.italic))) else ...produtos.map((p) => ListTile(dense: true, title: Text(p.nome), trailing: Text(formatador.format(p.valor)))), const Divider()]);
  }

  Widget _buildSeletorDePeriodo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(_dataInicio == null ? 'Data Início' : DateFormat('dd/MM/yyyy').format(_dataInicio!)),
          onPressed: () => _selecionarData(context, isDataInicio: true),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(_dataFim == null ? 'Data Fim' : DateFormat('dd/MM/yyyy').format(_dataFim!)),
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
  Future<void> _selecionarData(BuildContext context, {required bool isDataInicio}) async {
    final dataSelecionada = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (dataSelecionada != null) {
      setState(() { if (isDataInicio) { _dataInicio = dataSelecionada; } else { _dataFim = dataSelecionada; } });
    }
  }

  void _limparFiltroDePeriodo() {
    setState(() {
      _dataInicio = null;
      _dataFim = null;
    });
  }
}