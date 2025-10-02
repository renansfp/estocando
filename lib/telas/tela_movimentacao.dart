// CÓDIGO 100% COMPLETO E FINAL DA TELA DE MOVIMENTAÇÃO (29/09/2025)

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estocando/telas/tela_cadastro_parceiro.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/movimentacao.dart';

// Classe de formatação de moeda (reutilizada do cadastro de produto)
class CurrencyInputFormatter extends TextInputFormatter {
  final int maxDigitsBeforeDecimal;

  CurrencyInputFormatter({this.maxDigitsBeforeDecimal = 7});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (newText.isEmpty) return newValue.copyWith(text: '');

    if (newText.length > maxDigitsBeforeDecimal + 2) {
      return oldValue;
    }

    double value = double.parse(newText) / 100;
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ');
    String formattedText = formatter.format(value);

    return newValue.copyWith(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

class TelaMovimentacao extends StatefulWidget {
  final QueryDocumentSnapshot? produtoPreSelecionado;
  const TelaMovimentacao({super.key, this.produtoPreSelecionado});

  @override
  State<TelaMovimentacao> createState() => _TelaMovimentacaoState();
}

class _TelaMovimentacaoState extends State<TelaMovimentacao> {
  final _formKey = GlobalKey<FormState>();

  QueryDocumentSnapshot? _produtoDocSelecionado;
  QueryDocumentSnapshot? _parceiroDocSelecionado;
  TipoMovimentacao _tipoMovimentacao = TipoMovimentacao.entrada;
  String? _subtipoSelecionado;

  List<QueryDocumentSnapshot> _listaDeProdutos = [];
  List<QueryDocumentSnapshot> _listaDeParceiros = [];
  bool _carregandoDados = true;
  bool _isSalvando = false;

  final List<String> _subtiposEntrada = const ['COMPRA', 'Devolução', 'Acerto de estoque'];
  final List<String> _subtiposSaida = const ['Venda', 'OS', 'Itau', 'Colaborador'];

  final _produtoAutocompleteController = TextEditingController();
  final _parceiroAutocompleteController = TextEditingController();
  final _qtdController = TextEditingController();
  final _valorCompraController = TextEditingController();
  final _numeroNfController = TextEditingController();
  final _devolvidoPorController = TextEditingController();
  final _motivoAcertoController = TextEditingController();
  final _numeroOsController = TextEditingController();
  final _agenciaController = TextEditingController();
  final _colaboradorController = TextEditingController();
  final _centroDeCustoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.produtoPreSelecionado != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _setProdutoSelecionado(widget.produtoPreSelecionado);
        }
      });
    }
    _carregarDadosIniciais();
  }

  @override
  void dispose() {
    _produtoAutocompleteController.dispose();
    _parceiroAutocompleteController.dispose();
    _qtdController.dispose();
    _valorCompraController.dispose();
    _numeroNfController.dispose();
    _devolvidoPorController.dispose();
    _motivoAcertoController.dispose();
    _numeroOsController.dispose();
    _agenciaController.dispose();
    _colaboradorController.dispose();
    _centroDeCustoController.dispose();
    super.dispose();
  }

  void _setProdutoSelecionado(QueryDocumentSnapshot? produtoDoc) {
    setState(() {
      _produtoDocSelecionado = produtoDoc;
      if (produtoDoc != null) {
        final data = produtoDoc.data() as Map<String, dynamic>;
        _produtoAutocompleteController.text = "${data['codigo']} - ${data['nome']}";

        double valorInicial = (data['valor'] ?? 0.0).toDouble();
        _valorCompraController.text = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ').format(valorInicial);

      } else {
        _produtoAutocompleteController.clear();
        _valorCompraController.clear();
      }
    });
  }

  Future<void> _carregarDadosIniciais() async {
    try {
      final db = FirebaseFirestore.instance;
      final produtosFuture = db.collection('produtos').where('ativo', isEqualTo: true).orderBy('nome').get();
      final parceirosFuture = db.collection('parceiros').orderBy('nome').get();
      final results = await Future.wait([produtosFuture, parceirosFuture]);
      if (mounted) {
        setState(() {
          _listaDeProdutos = results[0].docs;
          _listaDeParceiros = results[1].docs;
          _carregandoDados = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar dados: $e'), backgroundColor: Colors.red));
        setState(() { _carregandoDados = false; });
      }
    }
  }

  void _limparSelecoesDependentes() {
    setState(() {
      _subtipoSelecionado = null;
      _parceiroDocSelecionado = null;
      _parceiroAutocompleteController.clear();
    });
  }

  void _salvarMovimentacao() async {
    if (_formKey.currentState!.validate()) {
      if (_produtoDocSelecionado == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro: Selecione um produto válido da lista.'), backgroundColor: Colors.red));
        return;
      }
      setState(() { _isSalvando = true; });
      final db = FirebaseFirestore.instance;
      final produtoRef = db.collection('produtos').doc(_produtoDocSelecionado!.id);

      // O "PORQUÊ": A quantidade agora é lida como um double, trocando a vírgula do
      // usuário por um ponto para que o Dart entenda o número corretamente.
      final double quantidadeMovimentada = double.parse(_qtdController.text.replaceAll(',', '.'));
      final double valorDaCompra = double.tryParse(_valorCompraController.text.replaceAll(RegExp(r'[^0-9,]'), '').replaceAll(',', '.')) ?? 0.0;

      try {
        await db.runTransaction((transaction) async {
          final produtoSnapshot = await transaction.get(produtoRef);
          if (!produtoSnapshot.exists) { throw Exception("Produto não encontrado!"); }
          final dadosProduto = produtoSnapshot.data() as Map<String, dynamic>;

          // O "PORQUÊ": Garantimos que o estoque atual seja lido como um double,
          // não importa se no banco ele está salvo como inteiro ou decimal.
          final estoqueAtual = (dadosProduto['quantidadeAtual'] ?? 0).toDouble();
          double novoEstoque;
          final Map<String, dynamic> updateData = {};

          if (_tipoMovimentacao == TipoMovimentacao.saida) {
            // A comparação de estoque agora é feita com decimais.
            if (estoqueAtual < quantidadeMovimentada) {
              // A mensagem de erro agora formata o número para exibir corretamente.
              throw Exception('Estoque insuficiente! Saldo atual: ${estoqueAtual.toStringAsFixed(3).replaceAll('.', ',')}');
            }
            novoEstoque = estoqueAtual - quantidadeMovimentada;
          } else {
            novoEstoque = estoqueAtual + quantidadeMovimentada;
            if (dadosProduto.containsKey('numeroSC') && dadosProduto['numeroSC'] != null) {
              updateData['numeroSC'] = null;
            }
            if (_subtipoSelecionado == 'COMPRA') {
              updateData['valor'] = valorDaCompra;
            }
          }
          // O novo estoque é salvo como um double.
          updateData['quantidadeAtual'] = novoEstoque;
          transaction.update(produtoRef, updateData);
          final dadosParceiro = _parceiroDocSelecionado?.data() as Map<String, dynamic>?;
          final tipoParceiro = dadosParceiro != null ? TipoParceiro.values.byName(dadosParceiro['tipo']) : null;
          final novaMovimentacao = Movimentacao(
            produtoId: _produtoDocSelecionado!.id,
            produtoCodigo: dadosProduto['codigo'],
            produtoNome: dadosProduto['nome'],
            tipo: _tipoMovimentacao,
            // A quantidade da movimentação também é salva como double.
            quantidade: quantidadeMovimentada,
            data: DateTime.now(),
            subTipo: _subtipoSelecionado,
            valorUnitarioMovimentacao: (_tipoMovimentacao == TipoMovimentacao.entrada && _subtipoSelecionado == 'COMPRA') ? valorDaCompra : dadosProduto['valor'],
            nomeCliente: tipoParceiro == TipoParceiro.cliente ? dadosParceiro!['nome'] : null,
            nomeFornecedor: tipoParceiro == TipoParceiro.fornecedor ? dadosParceiro!['nome'] : null,
            numeroNF: _numeroNfController.text.trim().isNotEmpty ? _numeroNfController.text.trim() : null,
            numeroOS: _numeroOsController.text.trim().isNotEmpty ? _numeroOsController.text.trim() : null,
            nomeDevolucao: _devolvidoPorController.text.trim().isNotEmpty ? _devolvidoPorController.text.trim() : null,
            motivoAcerto: _motivoAcertoController.text.trim().isNotEmpty ? _motivoAcertoController.text.trim() : null,
            numeroAG: _agenciaController.text.trim().isNotEmpty ? _agenciaController.text.trim() : null,
            nomeColaborador: _colaboradorController.text.trim().isNotEmpty ? _colaboradorController.text.trim() : null,
            centroDeCusto: _centroDeCustoController.text.trim().isNotEmpty ? _centroDeCustoController.text.trim() : null,
          );
          final movimentacaoRef = db.collection('movimentacoes').doc();
          transaction.set(movimentacaoRef, novaMovimentacao.toJson());
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Movimentação salva com sucesso!'), backgroundColor: Colors.green));
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red));
      } finally {
        if(mounted) { setState(() { _isSalvando = false; }); }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Movimentação')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSelecaoProdutoAutocomplete(),
                const SizedBox(height: 20),
                _buildTipoMovimentacao(),
                const SizedBox(height: 20),
                _buildSubtipoDropdown(),
                const SizedBox(height: 10),
                _buildCamposCondicionais(),
                const SizedBox(height: 10),
                _buildCampoQuantidade(),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _salvarMovimentacao,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), textStyle: const TextStyle(fontSize: 18)),
                  child: _isSalvando ? const CircularProgressIndicator(color: Colors.white) : const Text('Salvar Movimentação'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelecaoProdutoAutocomplete() {
    return Autocomplete<QueryDocumentSnapshot>(
      displayStringForOption: (option) {
        final data = option.data() as Map<String, dynamic>;
        return '${data['codigo']} - ${data['nome']}';
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        if (_produtoAutocompleteController.text.isNotEmpty && textEditingController.text.isEmpty) {
          textEditingController.text = _produtoAutocompleteController.text;
        }

        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: _carregandoDados ? 'Carregando Produtos...' : 'Produto',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                textEditingController.clear();
                _setProdutoSelecionado(null);
              },
            ),
          ),
          validator: (value) {
            if (value != null && value.isNotEmpty && _produtoDocSelecionado == null) {
              return 'Selecione um produto válido da lista.';
            }
            if (value == null || value.isEmpty) {
              return 'O produto é obrigatório.';
            }
            return null;
          },
        );
      },
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) return const Iterable<QueryDocumentSnapshot>.empty();
        return _listaDeProdutos.where((option) {
          final data = option.data() as Map<String, dynamic>;
          final nome = (data['nome'] ?? '').toLowerCase();
          final codigo = (data['codigo'] ?? '').toLowerCase();
          return nome.contains(query) || codigo.contains(query);
        });
      },
      onSelected: (selection) {
        FocusScope.of(context).unfocus();
        _setProdutoSelecionado(selection);
      },
    );
  }

  Widget _buildTipoMovimentacao() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Tipo de Movimentação:', style: TextStyle(fontSize: 16)),
      Row(children: [
        Expanded(child: RadioListTile<TipoMovimentacao>(title: const Text('Entrada'), value: TipoMovimentacao.entrada, groupValue: _tipoMovimentacao, onChanged: (v) { if (v != null) setState(() { _tipoMovimentacao = v; _limparSelecoesDependentes(); }); },)),
        Expanded(child: RadioListTile<TipoMovimentacao>(title: const Text('Saída'), value: TipoMovimentacao.saida, groupValue: _tipoMovimentacao, onChanged: (v) { if (v != null) setState(() { _tipoMovimentacao = v; _limparSelecoesDependentes(); }); },)),
      ])
    ]);
  }

  Widget _buildSubtipoDropdown() {
    return DropdownButtonFormField<String>(value: _subtipoSelecionado, hint: const Text('Destino / Motivo'), isExpanded: true, items: (_tipoMovimentacao == TipoMovimentacao.entrada ? _subtiposEntrada : _subtiposSaida).map((String v) => DropdownMenuItem<String>(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => _subtipoSelecionado = v), validator: (v) => v == null ? 'Selecione uma opção' : null, decoration: const InputDecoration(border: OutlineInputBorder()));
  }

  Widget _buildCampoQuantidade() {
    // O "PORQUÊ": Este widget foi completamente atualizado para aceitar decimais.
    return TextFormField(
      controller: _qtdController,
      decoration: const InputDecoration(
          labelText: 'Quantidade', border: OutlineInputBorder()),
      // 1. Teclado para decimais
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        // 2. Filtro que permite números e UMA vírgula.
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\,?\d{0,3}')),
        LengthLimitingTextInputFormatter(10)
      ],
      validator: (t) {
        if (t == null || t.isEmpty) return 'Quantidade inválida';
        // 3. Validação que checa se o valor é um decimal maior que zero.
        final valor = double.tryParse(t.replaceAll(',', '.')) ?? 0.0;
        if (valor <= 0) return 'A quantidade deve ser maior que zero';
        return null;
      },
    );
  }

  Widget _buildParceiroAutocomplete(TipoParceiro tipo) {
    final String label = tipo == TipoParceiro.cliente ? 'Cliente' : 'Fornecedor';
    final List<QueryDocumentSnapshot> listaFiltrada = _listaDeParceiros.where((doc) => (doc.data() as Map<String, dynamic>)['tipo'] == tipo.name).toList();
    return Autocomplete<QueryDocumentSnapshot>(
      displayStringForOption: (option) => (option.data() as Map<String, dynamic>)['nome'] ?? '',
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: _carregandoDados ? 'Carregando...' : label,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                textEditingController.clear();
                setState(() { _parceiroDocSelecionado = null; });
              },
            ),
          ),
          validator: (value) {
            if (value != null && value.isNotEmpty && _parceiroDocSelecionado == null) return 'Selecione um $label válido da lista.';
            if (value == null || value.isEmpty) return 'O $label é obrigatório.';
            return null;
          },
        );
      },
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) return const Iterable<QueryDocumentSnapshot>.empty();
        return listaFiltrada.where((option) {
          final data = option.data() as Map<String, dynamic>;
          final nome = (data['nome'] ?? '').toLowerCase();
          final codigo = (data['codigo'] ?? '').toLowerCase();
          return nome.contains(query) || codigo.contains(query);
        });
      },
      onSelected: (selection) {
        FocusScope.of(context).unfocus();
        setState(() { _parceiroDocSelecionado = selection; });
      },
    );
  }

  Widget _buildCampoCentroDeCusto() {
    return TextFormField(controller: _centroDeCustoController, decoration: const InputDecoration(labelText: 'Centro de Custo'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)]);
  }

  Widget _buildCampoValorCompra() {
    return TextFormField(
      controller: _valorCompraController,
      decoration: const InputDecoration(labelText: 'Valor Unitário da Compra'),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [CurrencyInputFormatter(maxDigitsBeforeDecimal: 7)],
      validator: (v) {
        if (v == null || v.isEmpty) return 'O valor é obrigatório';
        final valor = double.tryParse(v.replaceAll(RegExp(r'[^0-9,]'), '').replaceAll(',', '.')) ?? 0.0;
        if (valor <= 0) return 'Valor deve ser maior que zero';
        return null;
      },
    );
  }

  Widget _buildCamposCondicionais() {
    if (_subtipoSelecionado == null) return const SizedBox.shrink();
    switch (_subtipoSelecionado) {
      case 'COMPRA':
        return Column(children: [
          const SizedBox(height: 10),
          _buildCampoValorCompra(),
          const SizedBox(height: 10),
          TextFormField(controller: _numeroNfController, decoration: const InputDecoration(labelText: 'Número da NF'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)]),
          const SizedBox(height: 10),
          _buildParceiroAutocomplete(TipoParceiro.fornecedor)
        ]);
      case 'Devolução':
        return TextFormField(controller: _devolvidoPorController, decoration: const InputDecoration(labelText: 'Nome de quem devolveu'));
      case 'Acerto de estoque':
        return TextFormField(controller: _motivoAcertoController, decoration: const InputDecoration(labelText: 'Motivo do acerto'));
      case 'Venda':
        return Column(children: [
          TextFormField(controller: _numeroNfController, decoration: const InputDecoration(labelText: 'Número da NF'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)]),
          const SizedBox(height: 10),
          _buildParceiroAutocomplete(TipoParceiro.cliente),
          const SizedBox(height: 10),
          _buildCampoCentroDeCusto()
        ]);
      case 'OS':
        return Column(children: [
          TextFormField(controller: _numeroOsController, decoration: const InputDecoration(labelText: 'Número da OS'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)]),
          const SizedBox(height: 10),
          _buildParceiroAutocomplete(TipoParceiro.cliente),
          const SizedBox(height: 10),
          _buildCampoCentroDeCusto()
        ]);
      case 'Itau':
        return Column(children: [
          TextFormField(controller: _agenciaController, decoration: const InputDecoration(labelText: 'Número da AG'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)]),
          const SizedBox(height: 10),
          _buildCampoCentroDeCusto()
        ]);
      case 'Colaborador':
        return Column(children: [
          TextFormField(controller: _colaboradorController, decoration: const InputDecoration(labelText: 'Nome do Colaborador')),
          const SizedBox(height: 10),
          _buildCampoCentroDeCusto()
        ]);
      default:
        return const SizedBox.shrink();
    }
  }
}
