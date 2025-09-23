// CÓDIGO COMPLETO E MODIFICADO PARA USAR FIREBASE

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TelaCadastroProduto extends StatefulWidget {
  final QueryDocumentSnapshot? produtoParaEditar;

  const TelaCadastroProduto({super.key, this.produtoParaEditar});

  @override
  State<TelaCadastroProduto> createState() => _TelaCadastroProdutoState();
}

class _TelaCadastroProdutoState extends State<TelaCadastroProduto> {
  final _formKey = GlobalKey<FormState>();

  final List<String> _tiposDeProduto = const [
    'ACESSÓRIO', 'ELETRICO', 'EPI', 'EXTINTOR',
    'FERRAMENTA', 'HIDRANTE', 'LOGISTICA', 'MANGUEIRA',
    'MATERIAL ESCRITORIO', 'MATERIAL LIMPEZA', 'OBRA',
    'PRODUÇÃO', 'SINALIZAÇÃO', 'SISTEMA ALARME', 'SISTEMA BOMBA',
    'UNIFORME'
  ];
  final List<String> _gruposDeProduto = const ['CONSUMO', "EPI'S", 'MATERIA PRIMA', 'REVENDA'];
  final List<String> _unidadesDeMedida = const ['BD', 'BR', 'CX', 'KG', 'LATA', 'LTS', 'MTS', 'PCT', 'PÇ'];

  final _codigoController = TextEditingController();
  final _nomeController = TextEditingController();
  final _estoqueMinimoController = TextEditingController();
  final _estoqueMaximoController = TextEditingController();
  final _valorController = TextEditingController();

  String? _tipoSelecionado;
  String? _grupoSelecionado;
  String? _unidadeSelecionada;

  // MODIFICAÇÃO 1: Nova variável de estado para o status do produto. Padrão é 'true' (ativo).
  bool _produtoAtivo = true;

  bool _isLoading = false;
  String _tituloAppBar = 'Cadastrar Novo Produto';
  String _textoBotaoSalvar = 'Salvar Produto';

  @override
  void initState() {
    super.initState();
    if (widget.produtoParaEditar != null) {
      final dados = widget.produtoParaEditar!.data() as Map<String, dynamic>;

      _codigoController.text = dados['codigo'] ?? '';
      _nomeController.text = dados['nome'] ?? '';
      _estoqueMinimoController.text = (dados['estoqueMinimo'] ?? 0).toString();
      _estoqueMaximoController.text = (dados['estoqueMaximo'] ?? 0).toString();
      _valorController.text = (dados['valor'] ?? 0.0).toString();

      setState(() {
        _tipoSelecionado = dados['tipo'];
        _grupoSelecionado = dados['grupo'];
        _unidadeSelecionada = dados['unidade'];

        // MODIFICAÇÃO 2: Carrega o status atual do produto. Se o campo não existir, assume 'true'.
        _produtoAtivo = dados['ativo'] ?? true;
      });

      _tituloAppBar = 'Editar Produto';
      _textoBotaoSalvar = 'Atualizar';
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
    if (_formKey.currentState!.validate() && !_isLoading) {
      setState(() {
        _isLoading = true;
      });

      try {
        final codigo = _codigoController.text.trim();
        final modoEdicao = widget.produtoParaEditar != null;

        final db = FirebaseFirestore.instance;
        final query = await db.collection('produtos').where('codigo', isEqualTo: codigo).get();

        if (query.docs.isNotEmpty) {
          if (!modoEdicao || (modoEdicao && query.docs.first.id != widget.produtoParaEditar!.id)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Erro: Este código de produto já existe.'), backgroundColor: Colors.red),
            );
            // MODIFICAÇÃO: Garantir que o loading pare em caso de erro
            setState(() => _isLoading = false);
            return;
          }
        }

        // MODIFICAÇÃO 4: Adicionado o campo 'ativo' e corrigido o bug de 'quantidadeAtual'
        final Map<String, dynamic> dadosProduto = {
          'codigo': codigo,
          'nome': _nomeController.text.trim(),
          'tipo': _tipoSelecionado,
          'grupo': _grupoSelecionado,
          'unidade': _unidadeSelecionada,
          'estoqueMinimo': int.tryParse(_estoqueMinimoController.text) ?? 0,
          'estoqueMaximo': int.tryParse(_estoqueMaximoController.text) ?? 0,
          'valor': double.tryParse(_valorController.text.replaceAll(',', '.')) ?? 0.0,
          'ativo': _produtoAtivo, // Nosso novo campo!
          'timestamp': FieldValue.serverTimestamp(),
        };

        if (modoEdicao) {
          // Atualiza um produto existente (não mexe na quantidadeAtual)
          await db.collection('produtos').doc(widget.produtoParaEditar!.id).update(dadosProduto);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produto atualizado com sucesso!'), backgroundColor: Colors.blue),
          );
        } else {
          // Adiciona um novo produto
          dadosProduto['quantidadeAtual'] = 0; // Quantidade inicial é 0 apenas para produtos NOVOS
          await db.collection('produtos').add(dadosProduto);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produto salvo com sucesso!'), backgroundColor: Colors.green),
          );
        }

        if (mounted) Navigator.of(context).pop();

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar no Firebase: $e'), backgroundColor: Colors.red),
        );
      } finally {
        if(mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
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
                  validator: (value) => (value == null || value.isEmpty) ? 'O código é obrigatório.' : null,
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
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _estoqueMaximoController,
                  decoration: const InputDecoration(labelText: 'Estoque Máximo'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _valorController,
                  decoration: const InputDecoration(labelText: 'Valor (R\$)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 24),

                // MODIFICAÇÃO 3: Novo widget Switch para ativar/desativar o produto
                SwitchListTile(
                  title: const Text('Produto Ativo'),
                  subtitle: const Text('Produtos inativos não aparecerão na lista principal ou em novas movimentações.'),
                  value: _produtoAtivo,
                  onChanged: (bool valor) {
                    setState(() {
                      _produtoAtivo = valor;
                    });
                  },
                  secondary: Icon(_produtoAtivo ? Icons.check_circle : Icons.cancel, color: _produtoAtivo ? Colors.green : Colors.grey),
                ),

                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _salvar,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_textoBotaoSalvar),
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