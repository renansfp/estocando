// CÓDIGO FINAL E COMPLETO DA TELA DE MOVIMENTAÇÃO

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estocando/telas/tela_cadastro_parceiro.dart'; // Importamos o enum
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../models/movimentacao.dart';

class TelaMovimentacao extends StatefulWidget {
  const TelaMovimentacao({super.key});

  @override
  State<TelaMovimentacao> createState() => _TelaMovimentacaoState();
}

class _TelaMovimentacaoState extends State<TelaMovimentacao> {
  final _formKey = GlobalKey<FormState>();

  // --- VARIÁVEIS DE ESTADO ATUALIZADAS ---
  QueryDocumentSnapshot? _produtoDocSelecionado;
  QueryDocumentSnapshot? _parceiroDocSelecionado; // REATIVADO

  TipoMovimentacao _tipoMovimentacao = TipoMovimentacao.entrada;
  String? _subtipoSelecionado;

  List<QueryDocumentSnapshot> _listaDeProdutos = [];
  List<QueryDocumentSnapshot> _listaDeParceiros = []; // ADICIONADO
  bool _carregandoDados = true; // Unificamos o loading
  bool _isSalvando = false;

  final List<String> _subtiposEntrada = const ['COMPRA', 'Devolução', 'Acerto de estoque'];
  final List<String> _subtiposSaida = const ['Venda', 'OS', 'Itau', 'Colaborador'];

  final _qtdController = TextEditingController();
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
    _carregarDadosIniciais();
  }

  // --- FUNÇÃO DE CARREGAMENTO ATUALIZADA ---
  Future<void> _carregarDadosIniciais() async {
    try {
      final db = FirebaseFirestore.instance;
      final produtosFuture = db.collection('produtos').orderBy('nome').get();
      final parceirosFuture = db.collection('parceiros').orderBy('nome').get(); // ADICIONADO

      final results = await Future.wait([produtosFuture, parceirosFuture]);

      if (mounted) {
        setState(() {
          _listaDeProdutos = results[0].docs;
          _listaDeParceiros = results[1].docs; // ADICIONADO
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

  @override
  void dispose() {
    //TODO (Adicionar controllers) ... seus controllers ...
    super.dispose();
  }

  void _limparSelecoesDependentes() {
    setState(() {
      _subtipoSelecionado = null;
      _parceiroDocSelecionado = null;
    });
  }

  // --- FUNÇÃO DE SALVAR ATUALIZADA ---
  void _salvarMovimentacao() async {
    if (_formKey.currentState!.validate() && !_isSalvando) {
      setState(() { _isSalvando = true; });

      final db = FirebaseFirestore.instance;
      final produtoRef = db.collection('produtos').doc(_produtoDocSelecionado!.id);
      final int quantidadeMovimentada = int.parse(_qtdController.text);

      try {
        await db.runTransaction((transaction) async {
          final produtoSnapshot = await transaction.get(produtoRef);
          if (!produtoSnapshot.exists) { throw Exception("Produto não encontrado!"); }

          final dadosProduto = produtoSnapshot.data() as Map<String, dynamic>;
          final estoqueAtual = dadosProduto['quantidadeAtual'] as int;
          int novoEstoque;

          // Mapa para agrupar todas as atualizações no documento do produto
          final Map<String, dynamic> updateData = {};

          if (_tipoMovimentacao == TipoMovimentacao.saida) {
            if (estoqueAtual < quantidadeMovimentada) { throw Exception('Estoque insuficiente! Saldo atual: $estoqueAtual'); }
            novoEstoque = estoqueAtual - quantidadeMovimentada;
            updateData['quantidadeAtual'] = novoEstoque;
          } else {
            novoEstoque = estoqueAtual + quantidadeMovimentada;
            updateData['quantidadeAtual'] = novoEstoque;

            // --- INÍCIO DA CORREÇÃO ---
            // Se for uma entrada, verifica se existe uma SC e a limpa.
            if (dadosProduto.containsKey('numeroSC') && dadosProduto['numeroSC'] != null) {
              updateData['numeroSC'] = null;
            }
            // --- FIM DA CORREÇÃO ---
          }

          // Executa a atualização com todos os dados necessários
          transaction.update(produtoRef, updateData);

          // ADICIONADO: Pega os dados do parceiro selecionado
          final dadosParceiro = _parceiroDocSelecionado?.data() as Map<String, dynamic>?;
          final tipoParceiro = dadosParceiro != null ? TipoParceiro.values.byName(dadosParceiro['tipo']) : null;

          final novaMovimentacao = Movimentacao(
            produtoId: _produtoDocSelecionado!.id,
            produtoCodigo: dadosProduto['codigo'],
            produtoNome: dadosProduto['nome'],
            tipo: _tipoMovimentacao,
            quantidade: quantidadeMovimentada,
            data: DateTime.now(),
            subTipo: _subtipoSelecionado,
            // Lógica para salvar nome do cliente/fornecedor REATIVADA
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
      appBar: AppBar(title: const Text('Registrar Movimentação'), backgroundColor: Colors.blueGrey),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSelecaoProduto(),
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, padding: const EdgeInsets.symmetric(vertical: 20), textStyle: const TextStyle(fontSize: 18)),
                  child: _isSalvando ? const CircularProgressIndicator(color: Colors.white) : const Text('Salvar Movimentação'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelecaoProduto() { /* ... sem alterações ... */
    return DropdownSearch<QueryDocumentSnapshot>(enabled: !_carregandoDados, popupProps: PopupProps.menu(showSearchBox: true, searchFieldProps: TextFieldProps(decoration: InputDecoration(labelText: 'Buscar produto por código ou nome', prefixIcon: Icon(Icons.search))), emptyBuilder: (context, searchEntry) => const Center(child: Text('Nenhum produto encontrado')), ), items: _listaDeProdutos, itemAsString: (QueryDocumentSnapshot doc) { final data = doc.data() as Map<String, dynamic>; return '${data['codigo']} - ${data['nome']}'; }, dropdownDecoratorProps: DropDownDecoratorProps(dropdownSearchDecoration: InputDecoration(labelText: _carregandoDados ? 'Carregando...' : 'Produto', border: const OutlineInputBorder(), ), ), onChanged: (QueryDocumentSnapshot? doc) => setState(() => _produtoDocSelecionado = doc), selectedItem: _produtoDocSelecionado, validator: (doc) => doc == null ? "É obrigatório selecionar um produto." : null, );
  }

  Widget _buildTipoMovimentacao() { /* ... sem alterações ... */
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ const Text('Tipo de Movimentação:', style: TextStyle(fontSize: 16)), Row(children: [ Expanded(child: RadioListTile<TipoMovimentacao>(title: const Text('Entrada'), value: TipoMovimentacao.entrada, groupValue: _tipoMovimentacao, onChanged: (value) { if (value != null) { setState(() { _tipoMovimentacao = value; _limparSelecoesDependentes(); }); } }, ), ), Expanded(child: RadioListTile<TipoMovimentacao>(title: const Text('Saída'), value: TipoMovimentacao.saida, groupValue: _tipoMovimentacao, onChanged: (value) { if (value != null) { setState(() { _tipoMovimentacao = value; _limparSelecoesDependentes(); }); } },),), ], ), ],);
  }

  Widget _buildSubtipoDropdown() { /* ... sem alterações ... */
    List<String> itens = _tipoMovimentacao == TipoMovimentacao.entrada ? _subtiposEntrada : _subtiposSaida; return DropdownButtonFormField<String>(value: _subtipoSelecionado, hint: const Text('Destino / Motivo'), isExpanded: true, items: itens.map((String valor) => DropdownMenuItem<String>(value: valor, child: Text(valor))).toList(), onChanged: (v) => setState(() => _subtipoSelecionado = v), validator: (v) => v == null ? 'Selecione uma opção' : null, decoration: const InputDecoration(border: OutlineInputBorder()),);
  }

  Widget _buildCampoQuantidade() { /* ... sem alterações ... */
    return TextFormField(controller: _qtdController, decoration: const InputDecoration(labelText: 'Quantidade', border: OutlineInputBorder()), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], validator: (t) => (t == null || t.isEmpty || int.parse(t) <= 0) ? 'Quantidade inválida' : null);
  }

  // WIDGET PARA SELECIONAR PARCEIRO (REATIVADO E AJUSTADO)
  Widget _buildDropdownParceiro(TipoParceiro tipo) {
    final String label = tipo == TipoParceiro.cliente ? 'Cliente' : 'Fornecedor';
    final List<QueryDocumentSnapshot> listaFiltrada = _listaDeParceiros.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['tipo'] == tipo.name;
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: DropdownSearch<QueryDocumentSnapshot>(
        enabled: !_carregandoDados,
        popupProps: PopupProps.menu(
          showSearchBox: true,
          searchFieldProps: TextFieldProps(decoration: InputDecoration(labelText: 'Buscar por nome ou CNPJ')),
          emptyBuilder: (context, search) => Center(child: Text('Nenhum $label encontrado.')),
        ),
        items: listaFiltrada,
        itemAsString: (QueryDocumentSnapshot doc) {
          final data = doc.data() as Map<String, dynamic>;
          final nome = data['nome'] ?? '';
          final cnpj = data['cnpj'] ?? '';
          return '$nome${cnpj.isNotEmpty ? " - $cnpj" : ""}';
        },
        dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
        onChanged: (QueryDocumentSnapshot? doc) => setState(() => _parceiroDocSelecionado = doc),
        selectedItem: _parceiroDocSelecionado,
        validator: (doc) => doc == null ? 'É obrigatório selecionar um $label.' : null,
      ),
    );
  }

  Widget _buildCampoCentroDeCusto() { /* ... sem alterações ... */
    return TextFormField(controller: _centroDeCustoController, decoration: const InputDecoration(labelText: 'Centro de Custo'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]);
  }

  // WIDGET DOS CAMPOS CONDICIONAIS (REATIVADO)
  Widget _buildCamposCondicionais() {
    if (_subtipoSelecionado == null) return const SizedBox.shrink();
    switch (_subtipoSelecionado) {
      case 'COMPRA':
        return Column(children: [TextFormField(controller: _numeroNfController, decoration: const InputDecoration(labelText: 'Número da NF')), _buildDropdownParceiro(TipoParceiro.fornecedor)]);
      case 'Devolução':
        return TextFormField(controller: _devolvidoPorController, decoration: const InputDecoration(labelText: 'Nome de quem devolveu'));
      case 'Acerto de estoque':
        return TextFormField(controller: _motivoAcertoController, decoration: const InputDecoration(labelText: 'Motivo do acerto'));
      case 'Venda':
        return Column(children: [TextFormField(controller: _numeroNfController, decoration: const InputDecoration(labelText: 'Número da NF')), _buildDropdownParceiro(TipoParceiro.cliente), const SizedBox(height: 10), _buildCampoCentroDeCusto()]);
      case 'OS':
        return Column(children: [TextFormField(controller: _numeroOsController, decoration: const InputDecoration(labelText: 'Número da OS')), _buildDropdownParceiro(TipoParceiro.cliente), const SizedBox(height: 10), _buildCampoCentroDeCusto()]);
      case 'Itau':
        return Column(children: [TextFormField(controller: _agenciaController, decoration: const InputDecoration(labelText: 'Número da AG')), const SizedBox(height: 10), _buildCampoCentroDeCusto()]);
      case 'Colaborador':
        return Column(children: [TextFormField(controller: _colaboradorController, decoration: const InputDecoration(labelText: 'Nome do Colaborador')), const SizedBox(height: 10), _buildCampoCentroDeCusto()]);
      default:
        return const SizedBox.shrink();
    }
  }
}