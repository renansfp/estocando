// CÓDIGO COMPLETO E CORRIGIDO COM LÓGICA DE MULTI-EMPRESA

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ---> MUDANÇA 1: Importamos para pegar o usuário.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// (CurrencyInputFormatter continua igual)
class CurrencyInputFormatter extends TextInputFormatter {
  final int maxDigitsBeforeDecimal;
  final int maxDigitsAfterDecimal;

  CurrencyInputFormatter({this.maxDigitsBeforeDecimal = 7, this.maxDigitsAfterDecimal = 2});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (newText.isEmpty) return newValue.copyWith(text: '');
    double value = double.parse(newText) / 100;
    String integerPart = newText.substring(0, newText.length - 2);
    if (integerPart.length > maxDigitsBeforeDecimal) return oldValue;
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    String formattedText = formatter.format(value);
    return newValue.copyWith(text: formattedText, selection: TextSelection.collapsed(offset: formattedText.length));
  }
}

class TelaCadastroProduto extends StatefulWidget {
  final QueryDocumentSnapshot? produtoParaEditar;
  const TelaCadastroProduto({super.key, this.produtoParaEditar});
  @override
  State<TelaCadastroProduto> createState() => _TelaCadastroProdutoState();
}

class _TelaCadastroProdutoState extends State<TelaCadastroProduto> {
  final _formKey = GlobalKey<FormState>();

  // ---> MUDANÇA 2: Novas variáveis para guardar o empresaId e controlar o loading.
  String? _empresaId;
  bool _carregandoDadosIniciais = true;

  final List<String> _tiposDeProduto = const ['ACESSÓRIO', 'ELETRICO', 'EPI', 'EXTINTOR', 'FERRAMENTA', 'HIDRANTE', 'LOGISTICA', 'MANGUEIRA', 'MATERIAL ESCRITORIO', 'MATERIAL LIMPEZA', 'OBRA', 'PRODUÇÃO', 'SINALIZAÇÃO', 'SISTEMA ALARME', 'SISTEMA BOMBA', 'UNIFORME'];
  final List<String> _gruposDeProduto = const ['CONSUMO', "EPI'S", 'MATERIA PRIMA', 'REVENDA'];
  final List<String> _unidadesDeMedida = const ['BD', 'BR', 'CX', 'KG', 'LATA', 'LTS', 'MTS', 'PACOTE', 'PAR', 'PCT', 'PÇ'];

  final _codigoController = TextEditingController();
  final _nomeController = TextEditingController();
  final _estoqueMinimoController = TextEditingController();
  final _estoqueMaximoController = TextEditingController();
  final _valorController = TextEditingController();

  String? _tipoSelecionado;
  String? _grupoSelecionado;
  String? _unidadeSelecionada;

  bool _produtoAtivo = true;
  bool _isLoading = false;
  String _tituloAppBar = 'Cadastrar Novo Produto';
  String _textoBotaoSalvar = 'Salvar Produto';

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais(); // ---> MUDANÇA 3: Chamamos a nova função para buscar dados.

    if (widget.produtoParaEditar != null) {
      final dados = widget.produtoParaEditar!.data() as Map<String, dynamic>;
      _codigoController.text = dados['codigo'] ?? '';
      _nomeController.text = dados['nome'] ?? '';
      _estoqueMinimoController.text = (dados['estoqueMinimo'] ?? 0.0).toString().replaceAll('.', ',');
      _estoqueMaximoController.text = (dados['estoqueMaximo'] ?? 0.0).toString().replaceAll('.', ',');
      _valorController.text = (dados['valor'] ?? 0.0).toStringAsFixed(2).replaceAll('.', ',');
      setState(() {
        _tipoSelecionado = dados['tipo'];
        _grupoSelecionado = dados['grupo'];
        _unidadeSelecionada = dados['unidade'];
        _produtoAtivo = dados['ativo'] ?? true;
      });
      _tituloAppBar = 'Editar Produto';
      _textoBotaoSalvar = 'Atualizar';
    }
  }

  // ---> MUDANÇA 4: Nova função para buscar o empresaId do usuário logado.
  Future<void> _carregarDadosIniciais() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (mounted && userDoc.exists) {
        setState(() {
          _empresaId = (userDoc.data() as Map<String, dynamic>)['empresaId'];
          _carregandoDadosIniciais = false;
        });
      }
    } else {
      // Se não houver usuário, impede o prosseguimento.
      setState(() {
        _carregandoDadosIniciais = false;
      });
    }
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _nomeController.dispose();
    _estoqueMinimoController.dispose();
    _estoqueMaximoController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  void _salvar() async {
    // Verificação de segurança: impede o salvamento se o empresaId não foi carregado.
    if (_empresaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro: Não foi possível identificar a empresa. Tente novamente.'), backgroundColor: Colors.red));
      return;
    }

    if (_formKey.currentState!.validate() && !_isLoading) {
      setState(() { _isLoading = true; });
      try {
        final codigo = _codigoController.text.trim();
        final modoEdicao = widget.produtoParaEditar != null;
        final db = FirebaseFirestore.instance;

        // ---> MUDANÇA 5: A verificação de código duplicado agora é segura.
        // Ela só busca por códigos dentro da MESMA empresa.
        final query = await db.collection('produtos')
            .where('empresaId', isEqualTo: _empresaId)
            .where('codigo', isEqualTo: codigo)
            .get();

        if (query.docs.isNotEmpty) {
          if (!modoEdicao || (modoEdicao && query.docs.first.id != widget.produtoParaEditar!.id)) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro: Este código de produto já existe na sua empresa.'), backgroundColor: Colors.red));
            setState(() => _isLoading = false);
            return;
          }
        }

        final Map<String, dynamic> dadosProduto = {
          // ---> MUDANÇA 6: "Carimbamos" o produto com o empresaId.
          'empresaId': _empresaId,
          'codigo': codigo,
          'nome': _nomeController.text.trim(),
          'tipo': _tipoSelecionado,
          'grupo': _grupoSelecionado,
          'unidade': _unidadeSelecionada,
          'estoqueMinimo': double.tryParse(_estoqueMinimoController.text.replaceAll(',', '.')) ?? 0.0,
          'estoqueMaximo': double.tryParse(_estoqueMaximoController.text.replaceAll(',', '.')) ?? 0.0,
          'valor': double.tryParse(_valorController.text.replaceAll(RegExp(r'[^0-9,]'), '').replaceAll(',', '.')) ?? 0.0,
          'ativo': _produtoAtivo,
          'timestamp': FieldValue.serverTimestamp(),
        };

        if (modoEdicao) {
          await db.collection('produtos').doc(widget.produtoParaEditar!.id).update(dadosProduto);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produto atualizado com sucesso!'), backgroundColor: Colors.blue));
        } else {
          dadosProduto['quantidadeAtual'] = 0.0;
          await db.collection('produtos').add(dadosProduto);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produto salvo com sucesso!'), backgroundColor: Colors.green));
        }
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar no Firebase: $e'), backgroundColor: Colors.red));
      } finally {
        if (mounted) {
          setState(() { _isLoading = false; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tituloAppBar)),
      // ---> MUDANÇA 7: Mostra um loading enquanto busca o empresaId.
      body: _carregandoDadosIniciais
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _codigoController,
                  decoration: const InputDecoration(labelText: 'Código'),
                  validator: (value) => (value == null || value.isEmpty) ? 'O código é obrigatório.' : null,
                  inputFormatters: [LengthLimitingTextInputFormatter(7)],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(labelText: 'Nome do Produto'),
                  validator: (value) => (value == null || value.isEmpty) ? 'O nome é obrigatório.' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _tipoSelecionado,
                  hint: const Text('Tipo'),
                  items: _tiposDeProduto.map((String tipo) => DropdownMenuItem<String>(value: tipo, child: Text(tipo))).toList(),
                  onChanged: (String? novoValor) => setState(() => _tipoSelecionado = novoValor),
                  validator: (value) => value == null ? 'Selecione um tipo' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _grupoSelecionado,
                  hint: const Text('Grupo'),
                  items: _gruposDeProduto.map((String grupo) => DropdownMenuItem<String>(value: grupo, child: Text(grupo))).toList(),
                  onChanged: (String? novoValor) => setState(() => _grupoSelecionado = novoValor),
                  validator: (value) => value == null ? 'Selecione um grupo' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _unidadeSelecionada,
                  hint: const Text('Unidade'),
                  items: _unidadesDeMedida.map((String unidade) => DropdownMenuItem<String>(value: unidade, child: Text(unidade))).toList(),
                  onChanged: (String? novoValor) => setState(() => _unidadeSelecionada = novoValor),
                  validator: (value) => value == null ? 'Selecione uma unidade' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _estoqueMinimoController,
                  decoration: const InputDecoration(labelText: 'Estoque Mínimo'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\,?\d{0,3}')), LengthLimitingTextInputFormatter(10)],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _estoqueMaximoController,
                  decoration: const InputDecoration(labelText: 'Estoque Máximo'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\,?\d{0,3}')), LengthLimitingTextInputFormatter(10)],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _valorController,
                  decoration: const InputDecoration(labelText: 'Valor'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [CurrencyInputFormatter(maxDigitsBeforeDecimal: 7)],
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'O valor é obrigatório.';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SwitchListTile(
                  title: const Text('Produto Ativo'),
                  subtitle: const Text('Produtos inativos não aparecerão na lista principal ou em novas movimentações.'),
                  value: _produtoAtivo,
                  onChanged: (bool valor) {
                    setState(() { _produtoAtivo = valor; });
                  },
                  secondary: Icon(_produtoAtivo ? Icons.check_circle : Icons.cancel, color: _produtoAtivo ? Colors.green : Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _salvar,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(_textoBotaoSalvar),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}