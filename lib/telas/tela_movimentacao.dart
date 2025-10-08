// CÓDIGO 100% COMPLETO E CORRIGIDO - TELA DE MOVIMENTAÇÃO

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estocando/telas/tela_cadastro_parceiro.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ---> MUDANÇA 1: Importamos para pegar o usuário logado (já estava ok).
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
  final TipoMovimentacao? tipoMovimentacaoInicial;

  const TelaMovimentacao({
    super.key,
    this.produtoPreSelecionado,
    this.tipoMovimentacaoInicial,
  });

  @override
  State<TelaMovimentacao> createState() => _TelaMovimentacaoState();
}

class _TelaMovimentacaoState extends State<TelaMovimentacao> {
  final _formKey = GlobalKey<FormState>();

  QueryDocumentSnapshot? _produtoDocSelecionado;
  QueryDocumentSnapshot? _parceiroDocSelecionado;
  late TipoMovimentacao _tipoMovimentacao;
  String? _subtipoSelecionado;

  // ---> MUDANÇA 2: Criamos uma variável para guardar o ID da empresa.
  // Esta variável vai "segurar" o Id da empresa para usarmos mais tarde.
  String? _empresaId;

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
    _tipoMovimentacao = widget.tipoMovimentacaoInicial ?? TipoMovimentacao.entrada;

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

  // ---> MUDANÇA 3: A função de carregar dados agora busca o 'empresaId' PRIMEIRO e depois filtra as listas.
  Future<void> _carregarDadosIniciais() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado.');
      }

      // 1. Buscamos o documento do usuário na coleção 'usuarios'.
      final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (!userDoc.exists || (userDoc.data() as Map<String, dynamic>)['empresaId'] == null) {
        throw Exception('ID da empresa não encontrado para este usuário.');
      }
      final empresaId = (userDoc.data() as Map<String, dynamic>)['empresaId'];

      // 2. Guardamos o ID da empresa na nossa variável de estado.
      // A partir daqui, a tela inteira sabe a qual empresa o usuário pertence.
      if (mounted) {
        setState(() {
          _empresaId = empresaId;
        });
      }

      final db = FirebaseFirestore.instance;
      // 3. AGORA, as buscas por produtos e parceiros são filtradas pelo 'empresaId'.
      // Isso é mais seguro e profissional!
      final produtosFuture = db.collection('produtos')
          .where('empresaId', isEqualTo: _empresaId) // <-- Filtro de segurança
          .where('ativo', isEqualTo: true)
          .orderBy('nome').get();

      final parceirosFuture = db.collection('parceiros')
          .where('empresaId', isEqualTo: _empresaId) // <-- Filtro de segurança
          .orderBy('nome').get();

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

  // CÓDIGO COM OS "ESPIÕES" (PRINTS) PARA DEBUG
  void _salvarMovimentacao() async {
    if (_formKey.currentState!.validate()) {
      print(">>>> PASSO 1: Formulário validado com sucesso. Botão Salvar pressionado.");

      if (_produtoDocSelecionado == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro: Selecione um produto válido da lista.'), backgroundColor: Colors.red));
        print(">>>> ERRO: Produto não selecionado da lista.");
        return;
      }
      setState(() { _isSalvando = true; });
      final db = FirebaseFirestore.instance;
      final produtoRef = db.collection('produtos').doc(_produtoDocSelecionado!.id);

      final double quantidadeMovimentada = double.parse(_qtdController.text.replaceAll(',', '.'));
      final double valorDaCompra = double.tryParse(_valorCompraController.text.replaceAll(RegExp(r'[^0-9,]'), '').replaceAll(',', '.')) ?? 0.0;

      try {
        print(">>>> PASSO 2: Tentando iniciar a transação com o banco de dados...");
        await db.runTransaction((transaction) async {
          print(">>>> PASSO 3: Transação iniciada. Lendo o documento do produto...");
          final produtoSnapshot = await transaction.get(produtoRef);

          if (!produtoSnapshot.exists) { throw Exception("Produto não encontrado!"); }
          print(">>>> PASSO 4: Documento do produto lido com sucesso.");
          final dadosProduto = produtoSnapshot.data() as Map<String, dynamic>;

          if (dadosProduto['empresaId'] != _empresaId) {
            print(">>>> ERRO DE SEGURANÇA: ID da empresa do produto (${dadosProduto['empresaId']}) é diferente do ID da empresa do usuário (${_empresaId}).");
            throw Exception('Este produto não pertence à sua empresa.');
          }

          final estoqueAtual = (dadosProduto['quantidadeAtual'] ?? 0).toDouble();
          double novoEstoque;
          final Map<String, dynamic> updateData = {};

          if (_tipoMovimentacao == TipoMovimentacao.saida) {
            if (estoqueAtual < quantidadeMovimentada) {
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

          print(">>>> PASSO 5: Lógica de estoque calculada. Criando o objeto da nova movimentação...");
          updateData['quantidadeAtual'] = novoEstoque;
          transaction.update(produtoRef, updateData);
          final dadosParceiro = _parceiroDocSelecionado?.data() as Map<String, dynamic>?;
          final tipoParceiro = dadosParceiro != null ? TipoParceiro.values.byName(dadosParceiro['tipo']) : null;

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
          );
          final movimentacaoRef = db.collection('movimentacoes').doc();

          print(">>>> PASSO 6: TUDO CERTO! Salvando a movimentação no banco de dados...");
          transaction.set(movimentacaoRef, novaMovimentacao.toJson());
        });
        if (mounted) {
          print(">>>> PASSO 7: SUCESSO! Transação concluída.");
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Movimentação salva com sucesso!'), backgroundColor: Colors.green));
          Navigator.of(context).pop();
        }
      } catch (e) {
        print("!!!! ERRO CAPTURADO PELA REDE DE SEGURANÇA !!!!");
        print(e.toString());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red));
        }
      } finally {
        if(mounted) { setState(() { _isSalvando = false; }); }
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Movimentação')),
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
                  onPressed: _isSalvando ? null : _salvarMovimentacao,
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
    return TextFormField(
      controller: _qtdController,
      decoration: const InputDecoration(
          labelText: 'Quantidade', border: OutlineInputBorder()),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\,?\d{0,3}')),
        LengthLimitingTextInputFormatter(10)
      ],
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
    return Autocomplete<QueryDocumentSnapshot>(
      displayStringForOption: (option) => (option.data() as Map<String, dynamic>)['nome'] ?? '',
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        _parceiroAutocompleteController.text = textEditingController.text;
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: _carregandoDados ? 'Carregando...' : label,
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaCadastroParceiro())),
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    textEditingController.clear();
                    setState(() { _parceiroDocSelecionado = null; });
                  },
                ),
              ],
            ),
          ),
          validator: (value) {
            if (_subtipoSelecionado == 'COMPRA' || _subtipoSelecionado == 'Venda' || _subtipoSelecionado == 'OS') {
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