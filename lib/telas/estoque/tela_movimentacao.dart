// Salve como: lib/telas/estoque/tela_movimentacao.dart
// (VERSÃO v3.1 - Correção de Lotes e Duplicidade)

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/telas/admin/tela_cadastro_parceiro.dart'; // Ajuste o caminho se necessário
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/movimentacao.dart';
import 'package:protecin_producao/models/parceiro.dart';

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

  // Controle de Lote
  bool _produtoExigeLote = false;
  final _loteFabricanteController = TextEditingController();
  final _validadeLoteController = TextEditingController();
  DateTime? _dataValidadeSelecionada;

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
    _loteFabricanteController.dispose();
    _validadeLoteController.dispose();
    super.dispose();
  }

  void _setProdutoSelecionadoSemSetState(QueryDocumentSnapshot? produtoDoc) {
    _produtoDocSelecionado = produtoDoc;
    if (produtoDoc != null) {
      final data = produtoDoc.data() as Map<String, dynamic>;
      _produtoAutocompleteController.text = "${data['codigo']} - ${data['nome']}";

      // Verifica se o produto exige controle de lote
      _produtoExigeLote = data['controlarLote'] == true;

      if (!_isEditing) {
        double valorInicial = (data['valor'] ?? 0.0).toDouble();
        _valorCompraController.text = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ').format(valorInicial);
      }
    } else {
      _produtoAutocompleteController.clear();
      _valorCompraController.clear();
      _produtoExigeLote = false;
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

  void _preencherFormularioParaEdicao() {
    try {
      final movData = widget.movimentacaoParaEditar!.data() as Map<String, dynamic>;
      final produtoOriginal = _listaDeProdutos.firstWhere((p) => p.id == movData['produtoId']);
      _setProdutoSelecionadoSemSetState(produtoOriginal);

      final nomeParceiro = movData['nomeCliente'] ?? movData['nomeFornecedor'];
      if (nomeParceiro != null) {
        _parceiroAutocompleteController.text = nomeParceiro;
      }

      final String tipoStr = movData['tipo'] as String? ?? 'saida';
      _tipoMovimentacao = tipoStr == 'entrada' ? TipoMovimentacao.entrada : TipoMovimentacao.saida;
      _subtipoSelecionado = movData['subTipo'];
      _qtdController.text = (movData['quantidade'] as num? ?? 0).toString().replaceAll('.', ',');

      _numeroNfController.text = movData['numeroNF'] ?? '';
      _numeroOsController.text = movData['numeroOS'] ?? '';
      // ... outros campos ...
    } catch (e) {
      _isEditing = false;
    }
  }

  void _limparSelecoesDependentes() {
    setState(() {
      _subtipoSelecionado = null;
      _parceiroDocSelecionado = null;
      _parceiroAutocompleteController.clear();
      _numeroOsController.clear();
    });
  }

  void _preencherComUltimosDados() {
    if (_ultimoLancamento == null) return;
    setState(() {
      _tipoMovimentacao = _ultimoLancamento!.tipo;
      _subtipoSelecionado = _ultimoLancamento!.subTipo;
      // ... (simplificado)
    });
  }

  // --- FUNÇÃO DE BUSCA MANUAL DA OS ---
  Future<void> _buscarDadosOS(String numeroOS) async {
    if (numeroOS.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buscando OS...'), duration: Duration(milliseconds: 500)));

    try {
      final query = await FirebaseFirestore.instance
          .collection('ordens_servico')
          .where('empresaId', isEqualTo: _empresaId)
          .where('numeroOS', isEqualTo: numeroOS)
          .limit(1)
          .get();

      QuerySnapshot queryAlternativa;
      if (query.docs.isEmpty && numeroOS.length < 5) {
        final numeroPad = numeroOS.padLeft(5, '0');
        queryAlternativa = await FirebaseFirestore.instance
            .collection('ordens_servico')
            .where('empresaId', isEqualTo: _empresaId)
            .where('numeroOS', isEqualTo: numeroPad)
            .limit(1)
            .get();
      } else {
        queryAlternativa = query;
      }
      final resultadoFinal = query.docs.isNotEmpty ? query : queryAlternativa;

      if (resultadoFinal.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OS não encontrada.')));
      } else {
        final dados = resultadoFinal.docs.first.data() as Map<String, dynamic>;
        final clienteNome = dados['clienteNome'];
        _numeroOsController.text = dados['numeroOS'] ?? numeroOS;

        if (clienteNome != null) {
          setState(() {
            _parceiroDocSelecionado = null;
            _parceiroAutocompleteController.text = clienteNome;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vinculado: $clienteNome'), backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  Future<void> _selecionarDataValidade() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() {
        _dataValidadeSelecionada = picked;
        _validadeLoteController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  void _salvarMovimentacao() async {
    if (_formKey.currentState!.validate()) {
      // Validação de Lote
      if (_tipoMovimentacao == TipoMovimentacao.entrada && _produtoExigeLote) {
        if (_loteFabricanteController.text.isEmpty || _dataValidadeSelecionada == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este produto exige Lote e Validade!'), backgroundColor: Colors.orange));
          return;
        }
      }

      setState(() { _isSalvando = true; });

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
            final estoqueAtual = (dadosProduto['quantidadeAtual'] ?? 0).toDouble();

            // 1. Atualiza Estoque Geral
            double novoEstoque;
            if (_tipoMovimentacao == TipoMovimentacao.saida) {
              if (estoqueAtual < quantidadeMovimentada) throw Exception('Estoque insuficiente!');
              novoEstoque = estoqueAtual - quantidadeMovimentada;
            } else {
              novoEstoque = estoqueAtual + quantidadeMovimentada;
            }

            Map<String, dynamic> updateData = {'quantidadeAtual': novoEstoque};
            if (_tipoMovimentacao == TipoMovimentacao.entrada && _subtipoSelecionado == 'COMPRA') {
              updateData['valor'] = valorDaCompra;
            }
            transaction.update(produtoRef, updateData);

            // 2. GESTÃO DE LOTES (Apenas para Entrada de Produto Controlado)
            String? idLoteRegistrado;
            if (_tipoMovimentacao == TipoMovimentacao.entrada && _produtoExigeLote) {
              final lotesCollection = produtoRef.collection('lotes');
              // Verifica se o lote já existe
              final loteQuery = await lotesCollection
                  .where('numero', isEqualTo: _loteFabricanteController.text.trim())
                  .limit(1)
                  .get();

              if (loteQuery.docs.isNotEmpty) {
                final loteDoc = loteQuery.docs.first;
                final qtdLoteAtual = (loteDoc['quantidadeAtual'] ?? 0).toDouble();
                transaction.update(loteDoc.reference, {
                  'quantidadeAtual': qtdLoteAtual + quantidadeMovimentada,
                  'ultimaEntrada': FieldValue.serverTimestamp()
                });
                idLoteRegistrado = loteDoc.id;
              } else {
                final novoLoteRef = lotesCollection.doc();
                transaction.set(novoLoteRef, {
                  'numero': _loteFabricanteController.text.trim(),
                  'validade': _dataValidadeSelecionada,
                  'quantidadeInicial': quantidadeMovimentada,
                  'quantidadeAtual': quantidadeMovimentada,
                  'dataEntrada': FieldValue.serverTimestamp(),
                  'ativo': true
                });
                idLoteRegistrado = novoLoteRef.id;
              }
            }

            // 3. Salva Movimentação
            final dadosParceiro = _parceiroDocSelecionado?.data() as Map<String, dynamic>?;
            final tipoParceiro = dadosParceiro != null ? TipoParceiro.values.byName(dadosParceiro['tipo']) : null;

            // CRIAÇÃO DO OBJETO (SEM PASSAR OS CAMPOS NOVOS NO CONSTRUTOR)
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
              numeroPedido: _numeroPedidoController.text.trim().isNotEmpty ? _numeroPedidoController.text.trim() : null,
            );

            final movRef = db.collection('movimentacoes').doc();

            // CONVERSÃO E INJEÇÃO DE CAMPOS EXTRAS
            final jsonMov = novaMovimentacao.toJson();
            if (_produtoExigeLote) {
              jsonMov['loteNumero'] = _loteFabricanteController.text;
              jsonMov['loteId'] = idLoteRegistrado;
              jsonMov['loteValidade'] = _dataValidadeSelecionada?.toIso8601String();
            }

            transaction.set(movRef, jsonMov);
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Movimentação salva com sucesso!'), backgroundColor: Colors.green));
            Navigator.of(context).pop();
          }
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}'), backgroundColor: Colors.red));
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
                AbsorbPointer(
                  absorbing: _isEditing,
                  child: _buildSelecaoProdutoAutocomplete(),
                ),

                // --- PAINEL DE LOTE ---
                if (_tipoMovimentacao == TipoMovimentacao.entrada && _produtoExigeLote)
                  Container(
                    margin: const EdgeInsets.only(top: 15),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        border: Border.all(color: Colors.amber),
                        borderRadius: BorderRadius.circular(8)
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [Icon(Icons.new_releases, color: Colors.amber), SizedBox(width: 8), Text("Controle de Rastreabilidade", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown))]),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _loteFabricanteController,
                                decoration: const InputDecoration(labelText: 'Nº Lote Fabricante', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _validadeLoteController,
                                readOnly: true,
                                decoration: const InputDecoration(labelText: 'Validade', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today), filled: true, fillColor: Colors.white),
                                onTap: _selecionarDataValidade,
                                validator: (v) => v!.isEmpty ? 'Obrigatória' : null,
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
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
                      : Text(_isEditing ? 'Atualizar' : 'Salvar Movimentação'),
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
      displayStringForOption: (option) => '${(option.data() as Map)['codigo']} - ${(option.data() as Map)['nome']}',
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        if (_produtoAutocompleteController.text.isNotEmpty && controller.text.isEmpty) {
          controller.text = _produtoAutocompleteController.text;
        }
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: !_isEditing,
          decoration: InputDecoration(
            labelText: _carregandoDados ? 'Carregando...' : 'Produto',
            border: const OutlineInputBorder(),
            filled: _isEditing,
            fillColor: Colors.grey[200],
            suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () { if(!_isEditing) { controller.clear(); _setProdutoSelecionado(null); } }),
          ),
        );
      },
      optionsBuilder: (textEditingValue) {
        if (_isEditing) return const Iterable.empty();
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) return const Iterable<QueryDocumentSnapshot>.empty();
        return _listaDeProdutos.where((option) {
          final data = option.data() as Map<String, dynamic>;
          return (data['nome'] ?? '').toLowerCase().contains(query) || (data['codigo'] ?? '').toLowerCase().startsWith(query);
        });
      },
      onSelected: (selection) {
        FocusScope.of(context).unfocus();
        _setProdutoSelecionado(selection);
      },
    );
  }

  Widget _buildTipoMovimentacao() {
    void onChanged(TipoMovimentacao? v) {
      if (_isEditing) return;
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
        Expanded(child: ListTile(title: const Text('Entrada'), leading: Radio<TipoMovimentacao>(value: TipoMovimentacao.entrada, groupValue: _tipoMovimentacao, onChanged: onChanged), onTap: () => onChanged(TipoMovimentacao.entrada))),
        Expanded(child: ListTile(title: const Text('Saída'), leading: Radio<TipoMovimentacao>(value: TipoMovimentacao.saida, groupValue: _tipoMovimentacao, onChanged: onChanged), onTap: () => onChanged(TipoMovimentacao.saida))),
      ])]);
  }

  Widget _buildSubtipoDropdown() {
    return DropdownButtonFormField<String>(
        value: _subtipoSelecionado,
        hint: const Text('Motivo'),
        items: (_tipoMovimentacao == TipoMovimentacao.entrada ? _subtiposEntrada : _subtiposSaida).map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: _isEditing ? null : (v) => setState(() => _subtipoSelecionado = v));
  }

  Widget _buildCampoQuantidade() {
    return TextFormField(controller: _qtdController, decoration: const InputDecoration(labelText: 'Quantidade', border: OutlineInputBorder()), keyboardType: const TextInputType.numberWithOptions(decimal: true));
  }

  Widget _buildParceiroAutocomplete(TipoParceiro tipo) {
    final String label = tipo == TipoParceiro.cliente ? 'Cliente' : 'Fornecedor';
    final List<QueryDocumentSnapshot> listaFiltrada = _listaDeParceiros.where((doc) => (doc.data() as Map<String, dynamic>)['tipo'] == tipo.name).toList();
    return Autocomplete<QueryDocumentSnapshot>(
      displayStringForOption: (option) => (option.data() as Map<String, dynamic>)['nome'] ?? '',
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        if (_parceiroAutocompleteController.text.isNotEmpty && textEditingController.text.isEmpty) textEditingController.text = _parceiroAutocompleteController.text;
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () { textEditingController.clear(); setState(() { _parceiroDocSelecionado = null; }); }),
          ),
          onChanged: (text) => _parceiroAutocompleteController.text = text,
        );
      },
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) return const Iterable<QueryDocumentSnapshot>.empty();
        return listaFiltrada.where((option) {
          final data = option.data() as Map<String, dynamic>;
          return (data['nome'] ?? '').toLowerCase().contains(query);
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
    return TextFormField(controller: _centroDeCustoController, decoration: const InputDecoration(labelText: 'Centro de Custo'), keyboardType: TextInputType.number);
  }

  Widget _buildCampoValorCompra() {
    return TextFormField(controller: _valorCompraController, decoration: const InputDecoration(labelText: 'Valor Unitário'), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [CurrencyInputFormatter()]);
  }

  Widget _buildCamposCondicionais() {
    if (_subtipoSelecionado == null) return const SizedBox.shrink();
    switch (_subtipoSelecionado) {
      case 'COMPRA': return Column(children: [ const SizedBox(height: 10), _buildCampoValorCompra(), const SizedBox(height: 10), TextFormField(controller: _numeroNfController, decoration: const InputDecoration(labelText: 'Número da NF'), keyboardType: TextInputType.number), const SizedBox(height: 10), _buildParceiroAutocomplete(TipoParceiro.fornecedor) ]);
      case 'Devolução': return TextFormField(controller: _devolvidoPorController, decoration: const InputDecoration(labelText: 'Nome de quem devolveu'));
      case 'Acerto de estoque': return TextFormField(controller: _motivoAcertoController, decoration: const InputDecoration(labelText: 'Motivo do acerto'));
      case 'Venda (NF)': return Column(children: [ TextFormField(controller: _numeroNfController, decoration: const InputDecoration(labelText: 'Número da NF'), keyboardType: TextInputType.number), const SizedBox(height: 10), _buildParceiroAutocomplete(TipoParceiro.cliente), const SizedBox(height: 10), _buildCampoCentroDeCusto() ]);
      case 'Venda (Pedido)': return Column(children: [ TextFormField(controller: _numeroPedidoController, decoration: const InputDecoration(labelText: 'Número do Pedido'), keyboardType: TextInputType.text), const SizedBox(height: 10), _buildParceiroAutocomplete(TipoParceiro.cliente), const SizedBox(height: 10), _buildCampoCentroDeCusto() ]);

      case 'OS':
        return Column(children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _numeroOsController,
                  decoration: InputDecoration(
                      labelText: 'Número da OS',
                      hintText: 'Ex: 1050',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search, color: Colors.blue),
                        onPressed: () => _buscarDadosOS(_numeroOsController.text),
                      )
                  ),
                  keyboardType: TextInputType.number,
                  onFieldSubmitted: (val) => _buscarDadosOS(val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildParceiroAutocomplete(TipoParceiro.cliente),
          const SizedBox(height: 10),
          _buildCampoCentroDeCusto()
        ]);

      case 'Itau': return Column(children: [ TextFormField(controller: _agenciaController, decoration: const InputDecoration(labelText: 'Número da AG'), keyboardType: TextInputType.number), const SizedBox(height: 10), _buildCampoCentroDeCusto() ]);
      case 'Colaborador': return Column(children: [ TextFormField( controller: _colaboradorController, decoration: const InputDecoration(labelText: 'Nome do Colaborador'), textCapitalization: TextCapitalization.characters, ), const SizedBox(height: 10), _buildCampoCentroDeCusto() ]);
      default: return const SizedBox.shrink();
    }
  }
}