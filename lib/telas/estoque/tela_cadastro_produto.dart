import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/produto_provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';

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
    return newValue.copyWith(
        text: formattedText,
        selection: TextSelection.collapsed(offset: formattedText.length));
  }
}

class TelaCadastroProduto extends StatefulWidget {
  // Trocamos QueryDocumentSnapshot por Map
  final Map<String, dynamic>? produtoParaEditar;
  const TelaCadastroProduto({super.key, this.produtoParaEditar});

  @override
  State<TelaCadastroProduto> createState() => _TelaCadastroProdutoState();
}

class _TelaCadastroProdutoState extends State<TelaCadastroProduto> {
  final _formKey = GlobalKey<FormState>();

  final List<String> _tiposDeProduto = const ['ACESSÓRIO', 'ELETRICO', 'EPI', 'EXTINTOR', 'FERRAMENTA', 'HIDRANTE', 'LOGISTICA', 'MANGUEIRA', 'MATERIAL ESCRITORIO', 'MATERIAL LIMPEZA', 'OBRA', 'PRODUÇÃO', 'SINALIZAÇÃO', 'SISTEMA ALARME', 'SISTEMA BOMBA', 'UNIFORME'];
  final List<String> _gruposDeProduto = const ['CONSUMO', "EPI'S", 'MATERIA PRIMA', 'REVENDA'];
  final List<String> _unidadesDeMedida = const ['BD', 'BR', 'CX', 'KG', 'LATA', 'LTS', 'MTS', 'PACOTE', 'PAR', 'PCT', 'PÇ'];

  final _codigoController = TextEditingController();
  final _nomeController = TextEditingController();
  final _estoqueMinimoController = TextEditingController();
  final _estoqueMaximoController = TextEditingController();
  final _valorController = TextEditingController();
  final _ncmController = TextEditingController();

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
    if (widget.produtoParaEditar != null) {
      final dados = widget.produtoParaEditar!;
      _codigoController.text = dados['codigo'] ?? '';
      _nomeController.text = dados['nome'] ?? '';
      _estoqueMinimoController.text =
          (dados['estoqueMinimo'] ?? 0.0).toString().replaceAll('.', ',');
      _estoqueMaximoController.text =
          (dados['estoqueMaximo'] ?? 0.0).toString().replaceAll('.', ',');
      _valorController.text =
          (dados['valor'] ?? 0.0).toStringAsFixed(2).replaceAll('.', ',');
      _ncmController.text = dados['ncm'] ?? '';
      setState(() {
        _tipoSelecionado = dados['tipo'];
        _grupoSelecionado = dados['grupo'];
        _unidadeSelecionada = dados['unidade'];
        _produtoAtivo = dados['ativo'] ?? true;
        _tituloAppBar = 'Editar Produto';
        _textoBotaoSalvar = 'Atualizar';
      });
    }
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _nomeController.dispose();
    _estoqueMinimoController.dispose();
    _estoqueMaximoController.dispose();
    _ncmController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Pega empresaId do UsuarioProvider — sem Firestore direto
    final usuario = Provider.of<UsuarioProvider>(context, listen: false).usuario;
    if (usuario == null) {
      scaffoldMessenger.showSnackBar(const SnackBar(
          content: Text('Erro: usuário não identificado.'),
          backgroundColor: Colors.red));
      return;
    }

    if (!_formKey.currentState!.validate() || _isLoading) return;
    setState(() => _isLoading = true);

    try {
      final codigo = _codigoController.text.trim();
      final modoEdicao = widget.produtoParaEditar != null;
      final produtoProvider = context.read<ProdutoProvider>();

      // Verifica duplicidade via repository
      final duplicado = await produtoProvider.verificarCodigoDuplicado(
        usuario.empresaId,
        codigo,
        excludeId: modoEdicao ? widget.produtoParaEditar!['id'] : null,
      );

      if (duplicado) {
        scaffoldMessenger.showSnackBar(const SnackBar(
            content: Text('Erro: Este código de produto já existe na sua empresa.'),
            backgroundColor: Colors.red));
        return;
      }

      final Map<String, dynamic> dadosProduto = {
        'empresaId': usuario.empresaId,
        'codigo': codigo,
        'nome': _nomeController.text.trim(),
        'tipo': _tipoSelecionado,
        'grupo': _grupoSelecionado,
        'ncm': _grupoSelecionado == 'REVENDA' ? _ncmController.text.trim() : null,
        'unidade': _unidadeSelecionada,
        'estoqueMinimo': double.tryParse(
            _estoqueMinimoController.text.replaceAll(',', '.')) ?? 0.0,
        'estoqueMaximo': double.tryParse(
            _estoqueMaximoController.text.replaceAll(',', '.')) ?? 0.0,
        'valor': double.tryParse(_valorController.text
            .replaceAll(RegExp(r'[^0-9,]'), '')
            .replaceAll(',', '.')) ?? 0.0,
        'ativo': _produtoAtivo,
      };

      if (modoEdicao) {
        await produtoProvider.atualizar(
            widget.produtoParaEditar!['id'], dadosProduto);
        scaffoldMessenger.showSnackBar(const SnackBar(
            content: Text('Produto atualizado com sucesso!'),
            backgroundColor: Colors.blue));
      } else {
        dadosProduto['quantidadeAtual'] = 0.0;
        await produtoProvider.criar(dadosProduto);
        scaffoldMessenger.showSnackBar(const SnackBar(
            content: Text('Produto salvo com sucesso!'),
            backgroundColor: Colors.green));
      }

      if (mounted) navigator.pop();
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tituloAppBar)),
      body: SingleChildScrollView(
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
                  validator: (v) => (v == null || v.isEmpty) ? 'O código é obrigatório.' : null,
                  inputFormatters: [LengthLimitingTextInputFormatter(7)],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(labelText: 'Nome do Produto'),
                  validator: (v) => (v == null || v.isEmpty) ? 'O nome é obrigatório.' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _tipoSelecionado,
                  hint: const Text('Tipo'),
                  items: _tiposDeProduto.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _tipoSelecionado = v),
                  validator: (v) => v == null ? 'Selecione um tipo' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _grupoSelecionado,
                  hint: const Text('Grupo'),
                  items: _gruposDeProduto.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setState(() => _grupoSelecionado = v),
                  validator: (v) => v == null ? 'Selecione um grupo' : null,
                ),
                if (_grupoSelecionado == 'REVENDA') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _ncmController,
                    decoration: const InputDecoration(labelText: 'NCM'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _unidadeSelecionada,
                  hint: const Text('Unidade'),
                  items: _unidadesDeMedida.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                  onChanged: (v) => setState(() => _unidadeSelecionada = v),
                  validator: (v) => v == null ? 'Selecione uma unidade' : null,
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
                  validator: (v) => (v == null || v.isEmpty) ? 'O valor é obrigatório.' : null,
                ),
                const SizedBox(height: 24),
                SwitchListTile(
                  title: const Text('Produto Ativo'),
                  subtitle: const Text('Produtos inativos não aparecerão na lista principal.'),
                  value: _produtoAtivo,
                  onChanged: (v) => setState(() => _produtoAtivo = v),
                  secondary: Icon(_produtoAtivo ? Icons.check_circle : Icons.cancel,
                      color: _produtoAtivo ? Colors.green : Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _salvar,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      textStyle: const TextStyle(fontSize: 18)),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_textoBotaoSalvar),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}