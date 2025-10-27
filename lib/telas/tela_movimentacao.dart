// CÓDIGO 100% COMPLETO E CORRIGIDO (BLINDADO CONTRA DADOS ANTIGOS/NULOS)

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estocando/telas/tela_cadastro_parceiro.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/movimentacao.dart';

// Classe de formatação de moeda
class CurrencyInputFormatter extends TextInputFormatter {
  final int maxDigitsBeforeDecimal;
  CurrencyInputFormatter({this.maxDigitsBeforeDecimal = 7});
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (newText.isEmpty) return newValue.copyWith(text: '');
    if (newText.length > maxDigitsBeforeDecimal + 2) return oldValue;
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
  final TipoMovimentacao? tipoMovimentacaoInicial;
  final QueryDocumentSnapshot? movimentacaoParaEditar;

  const TelaMovimentacao({
    super.key,
    this.produtoPreSelecionado,
    this.tipoMovimentacaoInicial,
    this.movimentacaoParaEditar,
  });

  @override
  State<TelaMovimentacao> createState() => _TelaMovimentacaoState();
}

class _TelaMovimentacaoState extends State<TelaMovimentacao> {
  final _formKey = GlobalKey<FormState>();
  static Movimentacao? _ultimoLancamento;
  QueryDocumentSnapshot? _produtoDocSelecionado;
  QueryDocumentSnapshot? _parceiroDocSelecionado;
  late TipoMovimentacao _tipoMovimentacao;
  String? _subtipoSelecionado;
  String? _empresaId;
  List<QueryDocumentSnapshot> _listaDeProdutos = [];
  List<QueryDocumentSnapshot> _listaDeParceiros = [];
  bool _carregandoDados = true;
  bool _isSalvando = false;
  bool _isEditing = false;
  final List<String> _subtiposEntrada = const ['COMPRA', 'Devolução', 'Acerto de estoque'];
  final List<String> _subtiposSaida = const ['Venda (NF)', 'Venda (Pedido)', 'OS', 'Itau', 'Colaborador'];
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
  final _numeroPedidoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isEditing = widget.movimentacaoParaEditar != null;
    if (!_isEditing) {
      _tipoMovimentacao = widget.tipoMovimentacaoInicial ?? TipoMovimentacao.entrada;
      if (widget.produtoPreSelecionado != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _setProdutoSelecionado(widget.produtoPreSelecionado);
        });
      }
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
    _numeroPedidoController.dispose();
    super.dispose();
  }

  void _setProdutoSelecionadoSemSetState(QueryDocumentSnapshot? produtoDoc) {
    _produtoDocSelecionado = produtoDoc;
    if (produtoDoc != null) {
      final data = produtoDoc.data() as Map<String, dynamic>;
      _produtoAutocompleteController.text = "${data['codigo']} - ${data['nome']}";
      if (!_isEditing) {
        double valorInicial = (data['valor'] ?? 0.0).toDouble();
        _valorCompraController.text = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ').format(valorInicial);
      }
    } else {
      _produtoAutocompleteController.clear();
      _valorCompraController.clear();
    }
  }

  void _setProdutoSelecionado(QueryDocumentSnapshot? produtoDoc) {
    setState(() {
      _setProdutoSelecionadoSemSetState(produtoDoc);
    });
  }

  Future<void> _carregarDadosIniciais() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado.');
      final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (!userDoc.exists || (userDoc.data() as Map<String, dynamic>)['empresaId'] == null) throw Exception('ID da empresa não encontrado.');
      final empresaId = (userDoc.data() as Map<String, dynamic>)['empresaId'];

      final db = FirebaseFirestore.instance;
      final produtosFuture = db.collection('produtos').where('empresaId', isEqualTo: empresaId).where('ativo', isEqualTo: true).orderBy('nome').get();
      final parceirosFuture = db.collection('parceiros').where('empresaId', isEqualTo: empresaId).orderBy('nome').get();

      final results = await Future.wait([produtosFuture, parceirosFuture]);

      if (mounted) {
        _empresaId = empresaId;
        _listaDeProdutos = results[0].docs;
        _listaDeParceiros = results[1].docs;

        if (_isEditing) {
          _preencherFormularioParaEdicao();
        }

        setState(() {
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

  // ---> MUDANÇA (BLINDAGEM): Adicionado 'as ...? ?? ...' para evitar erros de null
  void _preencherFormularioParaEdicao() {
    try {
      final movData = widget.movimentacaoParaEditar!.data() as Map<String, dynamic>;

      final produtoOriginal = _listaDeProdutos.firstWhere((p) => p.id == movData['produtoId']);

      final nomeParceiro = movData['nomeCliente'] ?? movData['nomeFornecedor'];

      QueryDocumentSnapshot? parceiroOriginal;
      if (nomeParceiro != null) {
        try {
          parceiroOriginal = _listaDeParceiros.firstWhere((p) => (p.data() as Map<String, dynamic>)['nome'] == nomeParceiro);
        } catch (e) {
          parceiroOriginal = null;
        }
      }

      _setProdutoSelecionadoSemSetState(produtoOriginal);

      if (parceiroOriginal != null) {
        _parceiroDocSelecionado = parceiroOriginal;
        _parceiroAutocompleteController.text = nomeParceiro;
      } else if (nomeParceiro != null) {
        _parceiroAutocompleteController.text = nomeParceiro;
      }

      // BLINDAGEM: Se 'tipo' for nulo, assume 'saida'
      final String tipoStr = movData['tipo'] as String? ?? 'saida';
      _tipoMovimentacao = tipoStr == 'entrada' ? TipoMovimentacao.entrada : TipoMovimentacao.saida;

      _subtipoSelecionado = movData['subTipo']; // Se for nulo, o dropdown fica com o 'hint'

      // BLINDAGEM: Se 'quantidade' for nulo, assume 0
      _qtdController.text = (movData['quantidade'] as num? ?? 0).toString().replaceAll('.', ',');

      // BLINDAGEM: Verifica se 'valorUnitarioMovimentacao' existe antes de formatar
      final valorUnitario = movData['valorUnitarioMovimentacao'];
      if (movData['subTipo'] == 'COMPRA' && valorUnitario != null) {
        _valorCompraController.text = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ').format(valorUnitario);
      }

      _numeroNfController.text = movData['numeroNF'] ?? '';
      _devolvidoPorController.text = movData['nomeDevolucao'] ?? '';
      _motivoAcertoController.text = movData['motivoAcerto'] ?? '';
      _numeroOsController.text = movData['numeroOS'] ?? '';
      _agenciaController.text = movData['numeroAG'] ?? '';
      _colaboradorController.text = movData['nomeColaborador'] ?? '';
      _centroDeCustoController.text = movData['centroDeCusto'] ?? '';

    } catch (e) {
      _tipoMovimentacao = TipoMovimentacao.entrada;
      _subtipoSelecionado = null;
      _isEditing = false;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro: O produto original da movimentação está inativo ou foi excluído.'), backgroundColor: Colors.red));
        }
      });
    }
  }

  void _limparSelecoesDependentes() {
    setState(() {
      _subtipoSelecionado = null;
      _parceiroDocSelecionado = null;
      _parceiroAutocompleteController.clear();
    });
  }

  void _preencherComUltimosDados() {
    if (_ultimoLancamento == null) return;
    setState(() {
      _tipoMovimentacao = _ultimoLancamento!.tipo;
      _subtipoSelecionado = _ultimoLancamento!.subTipo;
      _centroDeCustoController.text = _ultimoLancamento!.centroDeCusto ?? '';
      _numeroNfController.text = _ultimoLancamento!.numeroNF ?? '';
      _numeroOsController.text = _ultimoLancamento!.numeroOS ?? '';
      _colaboradorController.text = _ultimoLancamento!.nomeColaborador ?? '';
      _numeroPedidoController.text = '';
      String nomeParceiro = _ultimoLancamento!.nomeCliente ?? _ultimoLancamento!.nomeFornecedor ?? '';
      if (nomeParceiro.isNotEmpty) {
        try {
          final parceiroEncontrado = _listaDeParceiros.firstWhere((doc) => (doc.data() as Map<String, dynamic>)['nome'] == nomeParceiro);
          _parceiroDocSelecionado = parceiroEncontrado;
          _parceiroAutocompleteController.text = nomeParceiro;
        } catch(e) {
          _parceiroDocSelecionado = null;
          _parceiroAutocompleteController.text = nomeParceiro;
        }
      } else {
        _parceiroDocSelecionado = null;
        _parceiroAutocompleteController.clear();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dados do último lançamento preenchidos!'), backgroundColor: Colors.blue));
  }

  void _salvarMovimentacao() async {
    if (_formKey.currentState!.validate()) {
      if (_produtoDocSelecionado == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro: Selecione um produto válido da lista.'), backgroundColor: Colors.red));
        return;
      }
      setState(() { _isSalvando = true; });

      // ---- LÓGICA DE CRIAÇÃO (NOVA MOVIMENTAÇÃO) ----
      if (!_isEditing) {
        final db = FirebaseFirestore.instance;
        final produtoRef = db.collection('produtos').doc(_produtoDocSelecionado!.id);
        final double quantidadeMovimentada = double.parse(_qtdController.text.replaceAll(',', '.'));
        final double valorDaCompra = double.tryParse(_valorCompraController.text.replaceAll(RegExp(r'[^0-9,]'), '').replaceAll(',', '.')) ?? 0.0;
        try {
          await db.runTransaction((transaction) async {
            final produtoSnapshot = await transaction.get(produtoRef);
            if (!produtoSnapshot.exists) throw Exception("Produto não encontrado!");
            final dadosProduto = produtoSnapshot.data() as Map<String, dynamic>;
            if (dadosProduto['empresaId'] != _empresaId) throw Exception('Este produto não pertence à sua empresa.');
            final estoqueAtual = (dadosProduto['quantidadeAtual'] ?? 0).toDouble();
            double novoEstoque;
            final Map<String, dynamic> updateData = {};
            if (_tipoMovimentacao == TipoMovimentacao.saida) {
              if (estoqueAtual < quantidadeMovimentada) throw Exception('Estoque insuficiente! Saldo: ${estoqueAtual.toStringAsFixed(3).replaceAll('.', ',')}');
              novoEstoque = estoqueAtual - quantidadeMovimentada;
            } else {
              novoEstoque = estoqueAtual + quantidadeMovimentada;
              if (dadosProduto.containsKey('numeroSC') && dadosProduto['numeroSC'] != null) updateData['numeroSC'] = null;
              if (_subtipoSelecionado == 'COMPRA') updateData['valor'] = valorDaCompra;
            }
            updateData['quantidadeAtual'] = novoEstoque;
            transaction.update(produtoRef, updateData);
            final dadosParceiro = _parceiroDocSelecionado?.data() as Map<String, dynamic>?;
            final tipoParceiro = dadosParceiro != null ? TipoParceiro.values.byName(dadosParceiro['tipo']) : null;

            // ---> MUDANÇA (CRIAÇÃO) <---
            final novaMovimentacao = Movimentacao(
              empresaId: _empresaId!,
              produtoId: _produtoDocSelecionado!.id,
              produtoCodigo: dadosProduto['codigo'],
              produtoNome: dadosProduto['nome'],
              tipo: _tipoMovimentacao,
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
              // Adicionado o campo que faltava
              numeroPedido: _numeroPedidoController.text.trim().isNotEmpty ? _numeroPedidoController.text.trim() : null,
            );
            if (mounted) _ultimoLancamento = novaMovimentacao;
            final movimentacaoRef = db.collection('movimentacoes').doc();
            transaction.set(movimentacaoRef, novaMovimentacao.toJson());
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Movimentação salva com sucesso!'), backgroundColor: Colors.green));
            Navigator.of(context).pop();
          }
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red));
        } finally {
          if (mounted) setState(() { _isSalvando = false; });
        }

        // ---- LÓGICA DE ATUALIZAÇÃO (EDIÇÃO) ----
      } else {
        final db = FirebaseFirestore.instance;
        final produtoRef = db.collection('produtos').doc(_produtoDocSelecionado!.id);
        final movOriginalRef = db.collection('movimentacoes').doc(widget.movimentacaoParaEditar!.id);

        final movOriginalData = widget.movimentacaoParaEditar!.data() as Map<String, dynamic>;
        final double qtdOriginal = (movOriginalData['quantidade'] as num? ?? 0.0).toDouble();
        final double qtdNova = double.parse(_qtdController.text.replaceAll(',', '.'));
        final double valorDaCompraNovo = double.tryParse(_valorCompraController.text.replaceAll(RegExp(r'[^0-9,]'), '').replaceAll(',', '.')) ?? 0.0;

        final double diferenca = qtdNova - qtdOriginal;
        final double ajusteDeEstoque = (_tipoMovimentacao == TipoMovimentacao.entrada) ? diferenca : -diferenca;

        DateTime dataOriginal;
        final dataValue = movOriginalData['data'];
        if (dataValue is Timestamp) {
          dataOriginal = dataValue.toDate();
        } else {
          dataOriginal = DateTime.now();
        }

        try {
          await db.runTransaction((transaction) async {
            final produtoSnapshot = await transaction.get(produtoRef);
            if (!produtoSnapshot.exists) throw Exception("Produto não encontrado!");
            final dadosProduto = produtoSnapshot.data() as Map<String, dynamic>;

            final estoqueAtual = (dadosProduto['quantidadeAtual'] ?? 0).toDouble();
            final double novoEstoque = estoqueAtual + ajusteDeEstoque;

            if (novoEstoque < 0) {
              throw Exception('Estoque insuficiente! Saldo atual: ${estoqueAtual.toStringAsFixed(3).replaceAll('.', ',')}. Ajuste: ${ajusteDeEstoque.toStringAsFixed(3).replaceAll('.', ',')}');
            }

            Map<String, dynamic> updateProdutoData = {'quantidadeAtual': novoEstoque};

            if (_subtipoSelecionado == 'COMPRA') {
              updateProdutoData['valor'] = valorDaCompraNovo;
            }
            transaction.update(produtoRef, updateProdutoData);

            final dadosParceiro = _parceiroDocSelecionado?.data() as Map<String, dynamic>?;
            final tipoParceiro = dadosParceiro != null ? TipoParceiro.values.byName(dadosParceiro['tipo']) : null;

            String? nomeParceiro = _parceiroAutocompleteController.text.trim();
            if (nomeParceiro.isEmpty) nomeParceiro = null;

            // ---> MUDANÇA (EDIÇÃO) <---
            final Movimentacao movimentacaoAtualizada = Movimentacao(
              empresaId: _empresaId!,
              produtoId: _produtoDocSelecionado!.id,
              produtoCodigo: dadosProduto['codigo'],
              produtoNome: dadosProduto['nome'],
              tipo: _tipoMovimentacao,
              quantidade: qtdNova,
              data: dataOriginal,
              subTipo: _subtipoSelecionado,
              valorUnitarioMovimentacao: (_tipoMovimentacao == TipoMovimentacao.entrada && _subtipoSelecionado == 'COMPRA')
                  ? valorDaCompraNovo
                  : (movOriginalData['valorUnitarioMovimentacao'] ?? dadosProduto['valor'] ?? 0.0),
              nomeCliente: tipoParceiro == TipoParceiro.cliente ? (dadosParceiro?['nome'] ?? nomeParceiro) : null,
              nomeFornecedor: tipoParceiro == TipoParceiro.fornecedor ? (dadosParceiro?['nome'] ?? nomeParceiro) : null,
              numeroNF: _numeroNfController.text.trim().isNotEmpty ? _numeroNfController.text.trim() : null,
              numeroOS: _numeroOsController.text.trim().isNotEmpty ? _numeroOsController.text.trim() : null,
              nomeDevolucao: _devolvidoPorController.text.trim().isNotEmpty ? _devolvidoPorController.text.trim() : null,
              motivoAcerto: _motivoAcertoController.text.trim().isNotEmpty ? _motivoAcertoController.text.trim() : null,
              numeroAG: _agenciaController.text.trim().isNotEmpty ? _agenciaController.text.trim() : null,
              nomeColaborador: _colaboradorController.text.trim().isNotEmpty ? _colaboradorController.text.trim() : null,
              centroDeCusto: _centroDeCustoController.text.trim().isNotEmpty ? _centroDeCustoController.text.trim() : null,
              // Adicionado o campo que faltava
              numeroPedido: _numeroPedidoController.text.trim().isNotEmpty ? _numeroPedidoController.text.trim() : null,
            );

            transaction.update(movOriginalRef, movimentacaoAtualizada.toJson());
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Movimentação atualizada com sucesso!'), backgroundColor: Colors.green));
            Navigator.of(context).pop();
          }
        } catch (e) {

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Erro ao atualizar. Verifique o "DEBUG CONSOLE" para detalhes.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 10),
              ),
            );
          }
        } finally {
          if (mounted) setState(() { _isSalvando = false; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar Movimentação' : 'Registrar Movimentação')),
      body: _carregandoDados
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_isEditing && _ultimoLancamento != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('Usar Últimos Dados'),
                      onPressed: _preencherComUltimosDados,
                    ),
                  ),
                AbsorbPointer(
                  absorbing: _isEditing,
                  child: _buildSelecaoProdutoAutocomplete(),
                ),
                const SizedBox(height: 20),

                AbsorbPointer(
                  absorbing: _isEditing,
                  child: Column(
                    children: [
                      _buildTipoMovimentacao(),
                      const SizedBox(height: 20),
                      _buildSubtipoDropdown(),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                _buildCamposCondicionais(),
                const SizedBox(height: 10),
                _buildCampoQuantidade(),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _isSalvando ? null : _salvarMovimentacao,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), textStyle: const TextStyle(fontSize: 18)),
                  child: _isSalvando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isEditing ? 'Atualizar Movimentação' : 'Salvar Movimentação'),
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
          enabled: !_isEditing,
          decoration: InputDecoration(
            labelText: _carregandoDados ? 'Carregando Produtos...' : 'Produto',
            border: const OutlineInputBorder(),
            filled: _isEditing,
            fillColor: Colors.grey[200],
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                if (_isEditing) return;
                textEditingController.clear();
                _setProdutoSelecionado(null);
              },
            ),
          ),
          validator: (value) {
            if (value != null && value.isNotEmpty && _produtoDocSelecionado == null) return 'Selecione um produto válido da lista.';
            if (value == null || value.isEmpty) return 'O produto é obrigatório.';
            return null;
          },
        );
      },
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (_isEditing) return const Iterable.empty();
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) return const Iterable<QueryDocumentSnapshot>.empty();
        final List<QueryDocumentSnapshot> suggestions = _listaDeProdutos.where((option) {
          final data = option.data() as Map<String, dynamic>;
          final nome = (data['nome'] ?? '').toLowerCase();
          final codigo = (data['codigo'] ?? '').toLowerCase();
          return nome.startsWith(query) || codigo.startsWith(query);
        }).toList();
        suggestions.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final codigoA = (dataA['codigo'] ?? '').toLowerCase();
          final nomeA = (dataA['nome'] ?? '').toLowerCase();
          final dataB = b.data() as Map<String, dynamic>;
          final codigoB = (dataB['codigo'] ?? '').toLowerCase();
          final String nomeB = (dataB['nome'] ?? '').toLowerCase();

          final bool aIsExactCode = codigoA == query;
          final bool bIsExactCode = codigoB == query;
          if (aIsExactCode && !bIsExactCode) return -1;
          if (!aIsExactCode && bIsExactCode) return 1;

          final bool aHasCodeMatch = codigoA.startsWith(query);
          final bool bHasCodeMatch = codigoB.startsWith(query);
          if (aHasCodeMatch && !bHasCodeMatch) return -1;
          if (!aHasCodeMatch && bHasCodeMatch) return 1;
          return nomeA.compareTo(nomeB);
        });
        return suggestions;
      },
      onSelected: (selection) {
        FocusScope.of(context).unfocus();
        _setProdutoSelecionado(selection);
      },
    );
  }

  Widget _buildTipoMovimentacao() {
    // Função de "onChanged" que será usada nos dois botões
    void onChanged(TipoMovimentacao? v) {
      if (_isEditing) return; // Não faz nada se estiver editando
      if (v != null) {
        setState(() {
          _tipoMovimentacao = v;
          _limparSelecoesDependentes();
        });
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Tipo de Movimentação:', style: TextStyle(fontSize: 16)),
      Row(children: [
        // --- Widget de ENTRADA Corrigido ---
        Expanded(
          child: ListTile(
            title: const Text('Entrada'),
            leading: Radio<TipoMovimentacao>(
              value: TipoMovimentacao.entrada,
              // ignore: deprecated_member_use
              groupValue: _tipoMovimentacao,
              // ignore: deprecated_member_use
              onChanged: onChanged, // Usa a função
            ),
            onTap: () => onChanged(TipoMovimentacao.entrada), // Permite clicar na linha toda
          ),
        ),
        // --- Widget de SAÍDA Corrigido ---
        Expanded(
          child: ListTile(
            title: const Text('Saída'),
            leading: Radio<TipoMovimentacao>(
              value: TipoMovimentacao.saida,
              // ignore: deprecated_member_use
              groupValue: _tipoMovimentacao,
              // ignore: deprecated_member_use
              onChanged: onChanged, // Usa a função
            ),
            onTap: () => onChanged(TipoMovimentacao.saida), // Permite clicar na linha toda
          ),
        ),
      ])
    ]);
  }
  Widget _buildSubtipoDropdown() {
    return DropdownButtonFormField<String>(
        initialValue: _subtipoSelecionado,
        hint: const Text('Destino / Motivo'),
        isExpanded: true,
        items: (_tipoMovimentacao == TipoMovimentacao.entrada ? _subtiposEntrada : _subtiposSaida)
            .map((String v) => DropdownMenuItem<String>(value: v, child: Text(v))).toList(),
        onChanged: _isEditing ? null : (v) => setState(() => _subtipoSelecionado = v),
        validator: (v) => v == null ? 'Selecione uma opção' : null,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          filled: _isEditing,
          fillColor: Colors.grey[200],
        )
    );
  }

  Widget _buildCampoQuantidade() {
    return TextFormField(
      controller: _qtdController,
      decoration: const InputDecoration(labelText: 'Quantidade', border: OutlineInputBorder()),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\,?\d{0,3}')), LengthLimitingTextInputFormatter(10)],
      validator: (t) {
        if (t == null || t.isEmpty) return 'Quantidade inválida';
        final valor = double.tryParse(t.replaceAll(',', '.')) ?? 0.0;
        if (valor <= 0) return 'A quantidade deve ser maior que zero';
        return null;
      },
    );
  }

  Widget _buildParceiroAutocomplete(TipoParceiro tipo) {
    final String label = tipo == TipoParceiro.cliente ? 'Cliente' : 'Fornecedor';
    final List<QueryDocumentSnapshot> listaFiltrada = _listaDeParceiros.where((doc) => (doc.data() as Map<String, dynamic>)['tipo'] == tipo.name).toList();

    String textoInicial = _parceiroAutocompleteController.text;

    return Autocomplete<QueryDocumentSnapshot>(
      displayStringForOption: (option) => (option.data() as Map<String, dynamic>)['nome'] ?? '',

      initialValue: TextEditingValue(text: textoInicial),

      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        textEditingController.addListener(() {
          _parceiroAutocompleteController.text = textEditingController.text;
        });

        if (_parceiroAutocompleteController.text.isNotEmpty && textEditingController.text.isEmpty) {
          textEditingController.text = _parceiroAutocompleteController.text;
        }

        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: _carregandoDados ? 'Carregando...' : label,
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaCadastroParceiro()))),
                IconButton(icon: const Icon(Icons.clear), onPressed: () {
                  textEditingController.clear();
                  setState(() {
                    _parceiroDocSelecionado = null;
                    _parceiroAutocompleteController.clear();
                  });
                }),
              ],
            ),
          ),
          validator: (value) {
            if (_subtipoSelecionado == 'COMPRA' || _subtipoSelecionado == 'Venda (NF)' || _subtipoSelecionado == 'Venda (Pedido)' || _subtipoSelecionado == 'OS') {
              if (_isEditing && value != null && value.isNotEmpty) {
                return null;
              }

              if (value != null && value.isNotEmpty && _parceiroDocSelecionado == null) return 'Selecione um $label válido da lista.';
              if (value == null || value.isEmpty) return 'O $label é obrigatório.';
            }
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
        _parceiroAutocompleteController.text = (selection.data() as Map<String, dynamic>)['nome'] ?? '';
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
      case 'COMPRA': return Column(children: [ const SizedBox(height: 10), _buildCampoValorCompra(), const SizedBox(height: 10), TextFormField(controller: _numeroNfController, decoration: const InputDecoration(labelText: 'Número da NF'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)]), const SizedBox(height: 10), _buildParceiroAutocomplete(TipoParceiro.fornecedor) ]);
      case 'Devolução': return TextFormField(controller: _devolvidoPorController, decoration: const InputDecoration(labelText: 'Nome de quem devolveu'));
      case 'Acerto de estoque': return TextFormField(controller: _motivoAcertoController, decoration: const InputDecoration(labelText: 'Motivo do acerto'));
      case 'Venda (NF)': return Column(children: [ TextFormField(controller: _numeroNfController, decoration: const InputDecoration(labelText: 'Número da NF'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)]), const SizedBox(height: 10), _buildParceiroAutocomplete(TipoParceiro.cliente), const SizedBox(height: 10), _buildCampoCentroDeCusto() ]);
      case 'Venda (Pedido)': return Column(children: [ TextFormField(controller: _numeroPedidoController, decoration: const InputDecoration(labelText: 'Número do Pedido'), keyboardType: TextInputType.text), const SizedBox(height: 10), _buildParceiroAutocomplete(TipoParceiro.cliente), const SizedBox(height: 10), _buildCampoCentroDeCusto() ]);
      case 'OS': return Column(children: [ TextFormField(controller: _numeroOsController, decoration: const InputDecoration(labelText: 'Número da OS'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)]), const SizedBox(height: 10), _buildParceiroAutocomplete(TipoParceiro.cliente), const SizedBox(height: 10), _buildCampoCentroDeCusto() ]);
      case 'Itau': return Column(children: [ TextFormField(controller: _agenciaController, decoration: const InputDecoration(labelText: 'Número da AG'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)]), const SizedBox(height: 10), _buildCampoCentroDeCusto() ]);
      case 'Colaborador': return Column(children: [ TextFormField( controller: _colaboradorController, decoration: const InputDecoration(labelText: 'Nome do Colaborador'), textCapitalization: TextCapitalization.characters, ), const SizedBox(height: 10), _buildCampoCentroDeCusto() ]);
      default: return const SizedBox.shrink();
    }
  }
}