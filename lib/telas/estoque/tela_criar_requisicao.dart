// lib/telas/estoque/tela_criar_requisicao.dart
// Migrada para Repository Pattern — sem acesso direto ao Firestore.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/models/requisicao.dart';
import 'package:protecin_producao/provider/ordem_servico_provider.dart';
import 'package:protecin_producao/provider/parceiro_provider.dart';
import 'package:protecin_producao/provider/produto_provider.dart';
import 'package:protecin_producao/provider/requisicao_provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';

class TelaCriarRequisicao extends StatefulWidget {
  final String? osPrePreenchida;
  final String? ccPrePreenchido;
  final String? subTipoPrePreenchido;

  const TelaCriarRequisicao({
    super.key,
    this.osPrePreenchida,
    this.ccPrePreenchido,
    this.subTipoPrePreenchido,
  });

  @override
  State<TelaCriarRequisicao> createState() => _TelaCriarRequisicaoState();
}

class _TelaCriarRequisicaoState extends State<TelaCriarRequisicao> {
  final _contextFormKey = GlobalKey<FormState>();
  final _itemFormKey = GlobalKey<FormState>();

  String? _empresaId;
  String? _usuarioId;
  String? _usuarioNome;

  List<Map<String, dynamic>> _listaDeProdutos = [];
  List<Map<String, dynamic>> _listaDeClientes = [];
  Map<String, dynamic>? _parceiroSelecionado;

  bool _carregandoDados = true;
  bool _isSalvando = false;

  final List<ItemRequisicao> _itensDaRequisicao = [];
  Map<String, dynamic>? _produtoSelecionado;

  String? _subtipoSelecionado;
  final List<String> _subtiposSaida = const [
    'OS',
    'Colaborador',
    'Venda (Pedido)',
    'Venda (NF)',
    'Itau'
  ];

  final _produtoAutocompleteController = TextEditingController();
  final _parceiroAutocompleteController = TextEditingController();
  final _qtdController = TextEditingController();
  final _numeroOsController = TextEditingController();
  final _colaboradorController = TextEditingController();
  final _centroDeCustoController = TextEditingController();
  final _numeroPedidoController = TextEditingController();
  final _numeroNfController = TextEditingController();
  final _agenciaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais().then((_) => _aplicarPrePreenchimento());
  }

  @override
  void dispose() {
    _produtoAutocompleteController.dispose();
    _parceiroAutocompleteController.dispose();
    _qtdController.dispose();
    _numeroOsController.dispose();
    _colaboradorController.dispose();
    _centroDeCustoController.dispose();
    _numeroPedidoController.dispose();
    _numeroNfController.dispose();
    _agenciaController.dispose();
    super.dispose();
  }

  void _aplicarPrePreenchimento() {
    if (widget.osPrePreenchida == null &&
        widget.ccPrePreenchido == null &&
        widget.subTipoPrePreenchido == null) {
      return;
    }

    setState(() {
      _subtipoSelecionado = widget.subTipoPrePreenchido ??
          (widget.osPrePreenchida != null ? 'OS' : null);
      if (widget.osPrePreenchida != null) {
        _numeroOsController.text = widget.osPrePreenchida!;
      }
      if (widget.ccPrePreenchido != null) {
        _centroDeCustoController.text = widget.ccPrePreenchido!;
      }
    });

    if (widget.osPrePreenchida != null) {
      _buscarDadosOS(widget.osPrePreenchida!);
    }
  }

  Future<void> _carregarDadosIniciais() async {
    try {
      final usuario =
          Provider.of<UsuarioProvider>(context, listen: false).usuario;
      if (usuario == null) throw Exception('Usuário não autenticado.');

      _empresaId = usuario.empresaId;
      _usuarioId = usuario.uid;
      _usuarioNome = usuario.nome;

      final produtoProvider = context.read<ProdutoProvider>();
      final parceiroProvider = context.read<ParceiroProvider>();

      final produtos = await produtoProvider.buscarTodosPorEmpresa(_empresaId!);
      final parceiros = await parceiroProvider.buscarTodosPorEmpresa(_empresaId!);

      if (mounted) {
        setState(() {
          _listaDeProdutos = produtos;
          _listaDeClientes = parceiros
              .where((p) => p['tipo'] == 'cliente')
              .toList();
          _carregandoDados = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao carregar dados: $e'),
              backgroundColor: Colors.red),
        );
        setState(() => _carregandoDados = false);
      }
    }
  }

  Future<void> _buscarDadosOS(String numeroOS) async {
    if (numeroOS.isEmpty || _empresaId == null) return;
    try {
      final osProvider = context.read<OrdemServicoProvider>();
      final dados = await osProvider.buscarPorNumero(_empresaId!, numeroOS);

      if (dados != null) {
        final clienteNome = dados['clienteNome'] as String?;
        if (mounted) {
          setState(() {
            _numeroOsController.text = dados['numeroOS'] ?? numeroOS;
          });
        }
        if (clienteNome != null && mounted) {
          try {
            final parceiro = _listaDeClientes
                .firstWhere((p) => p['nome'] == clienteNome);
            setState(() {
              _parceiroSelecionado = parceiro;
              _parceiroAutocompleteController.text = clienteNome;
            });
          } catch (_) {
            setState(() {
              _parceiroSelecionado = null;
              _parceiroAutocompleteController.text = clienteNome;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Erro busca OS: $e');
    }
  }

  void _adicionarItemNaLista() {
    if (!_itemFormKey.currentState!.validate()) return;

    final produto = _produtoSelecionado;
    if (produto == null) return;

    final double qtd =
    double.parse(_qtdController.text.replaceAll(',', '.'));
    final idx =
    _itensDaRequisicao.indexWhere((i) => i.produtoId == produto['id']);

    setState(() {
      if (idx != -1) {
        final atual = _itensDaRequisicao[idx];
        _itensDaRequisicao[idx] = ItemRequisicao(
          produtoId: atual.produtoId,
          produtoCodigo: atual.produtoCodigo,
          produtoNome: atual.produtoNome,
          quantidadeSolicitada: atual.quantidadeSolicitada + qtd,
        );
      } else {
        _itensDaRequisicao.insert(
          0,
          ItemRequisicao(
            produtoId: produto['id'] as String,
            produtoCodigo: produto['codigo'] as String? ?? '',
            produtoNome: produto['nome'] as String? ?? '',
            quantidadeSolicitada: qtd,
          ),
        );
      }
      _produtoAutocompleteController.clear();
      _qtdController.clear();
      _produtoSelecionado = null;
    });
  }

  void _removerItemDaLista(int index) {
    setState(() => _itensDaRequisicao.removeAt(index));
  }

  Future<void> _salvarRequisicao() async {
    if (!_contextFormKey.currentState!.validate() ||
        _itensDaRequisicao.isEmpty) {
      return;
    }

    setState(() => _isSalvando = true);
    try {
      final nomeCli = _parceiroSelecionado != null
          ? _parceiroSelecionado!['nome'] as String?
          : _parceiroAutocompleteController.text.trim().isEmpty
          ? null
          : _parceiroAutocompleteController.text.trim();

      final nova = Requisicao(
        empresaId: _empresaId!,
        solicitanteId: _usuarioId!,
        solicitanteNome: _usuarioNome ?? 'N/D',
        dataSolicitacao: DateTime.now(),
        status: 'PENDENTE',
        itens: _itensDaRequisicao,
        subTipo: _subtipoSelecionado!,
        numeroOS: _numeroOsController.text.trim().isEmpty
            ? null
            : _numeroOsController.text.trim(),
        centroDeCusto: _centroDeCustoController.text.trim().isEmpty
            ? null
            : _centroDeCustoController.text.trim(),
        nomeCliente: nomeCli,
        numeroPedido: _numeroPedidoController.text.trim().isEmpty
            ? null
            : _numeroPedidoController.text.trim(),
        numeroNF: _numeroNfController.text.trim().isEmpty
            ? null
            : _numeroNfController.text.trim(),
        agencia: _agenciaController.text.trim().isEmpty
            ? null
            : _agenciaController.text.trim(),
        nomeColaborador: _colaboradorController.text.trim().isEmpty
            ? null
            : _colaboradorController.text.trim(),
      );

      await context.read<RequisicaoProvider>().criar(nova);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Requisição enviada com sucesso!'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSalvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Requisição'),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
      ),
      body: _carregandoDados
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _contextFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. Destino / Motivo',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildSubtipoDropdown(),
                  const SizedBox(height: 10),
                  _buildCamposCondicionais(),
                ],
              ),
            ),
          ),
          const Divider(thickness: 2),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _itemFormKey,
              child: Column(
                children: [
                  _buildSelecaoProdutoAutocomplete(),
                  const SizedBox(height: 16),
                  _buildCampoQuantidade(),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _adicionarItemNaLista,
                    icon: const Icon(Icons.add),
                    label: const Text('ADICIONAR ITEM'),
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50)),
                  ),
                ],
              ),
            ),
          ),
          _buildListaItensRequisicao(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _isSalvando ? null : _salvarRequisicao,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 60)),
              child: _isSalvando
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('ENVIAR REQUISIÇÃO'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtipoDropdown() {
    return DropdownButtonFormField<String>(
      value: _subtipoSelecionado,
      hint: const Text('Destino / Motivo'),
      items: _subtiposSaida
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
      onChanged: (v) => setState(() => _subtipoSelecionado = v),
      validator: (v) => v == null ? 'Selecione' : null,
      decoration: const InputDecoration(border: OutlineInputBorder()),
    );
  }

  Widget _buildCamposCondicionais() {
    if (_subtipoSelecionado == null) return const SizedBox.shrink();
    return Column(
      children: [
        if (_subtipoSelecionado == 'OS') ...[
          TextFormField(
            controller: _numeroOsController,
            decoration: InputDecoration(
              labelText: 'Número da OS',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => _buscarDadosOS(_numeroOsController.text),
              ),
            ),
            onFieldSubmitted: _buscarDadosOS,
          ),
          const SizedBox(height: 16),
          _buildParceiroAutocomplete(),
        ],
        if (_subtipoSelecionado == 'Colaborador') ...[
          TextFormField(
            controller: _colaboradorController,
            decoration: const InputDecoration(
                labelText: 'Nome do Colaborador',
                border: OutlineInputBorder()),
            textCapitalization: TextCapitalization.characters,
          ),
        ],
        if (_subtipoSelecionado == 'Venda (Pedido)') ...[
          TextFormField(
            controller: _numeroPedidoController,
            decoration: const InputDecoration(
                labelText: 'Número do Pedido',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          _buildParceiroAutocomplete(),
        ],
        if (_subtipoSelecionado == 'Venda (NF)') ...[
          TextFormField(
            controller: _numeroNfController,
            decoration: const InputDecoration(
                labelText: 'Número da NF',
                border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          _buildParceiroAutocomplete(),
        ],
        if (_subtipoSelecionado == 'Itau') ...[
          TextFormField(
            controller: _agenciaController,
            decoration: const InputDecoration(
                labelText: 'Número da AG',
                border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
        ],
        const SizedBox(height: 16),
        TextFormField(
          controller: _centroDeCustoController,
          decoration: const InputDecoration(
              labelText: 'Centro de Custo',
              border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildSelecaoProdutoAutocomplete() {
    return Autocomplete<Map<String, dynamic>>(
      displayStringForOption: (option) =>
      '${option['codigo']} - ${option['nome']}',
      optionsBuilder: (textValue) {
        if (textValue.text.isEmpty) return const Iterable.empty();
        final query = textValue.text.toLowerCase();
        return _listaDeProdutos.where((p) =>
        (p['nome'] ?? '').toString().toLowerCase().contains(query) ||
            (p['codigo'] ?? '').toString().contains(query));
      },
      onSelected: (p) {
        setState(() => _produtoSelecionado = p);
        _produtoAutocompleteController.text =
        '${p['codigo']} - ${p['nome']}';
      },
      fieldViewBuilder: (context, controller, focus, onSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focus,
          decoration: const InputDecoration(
              labelText: 'Produto', border: OutlineInputBorder()),
          validator: (_) =>
          _produtoSelecionado == null ? 'Selecione um produto' : null,
        );
      },
    );
  }

  Widget _buildCampoQuantidade() {
    return TextFormField(
      controller: _qtdController,
      decoration: const InputDecoration(
          labelText: 'Quantidade', border: OutlineInputBorder()),
      keyboardType:
      const TextInputType.numberWithOptions(decimal: true),
      validator: (v) =>
      (v == null || v.trim().isEmpty) ? 'Informe a quantidade' : null,
    );
  }

  Widget _buildListaItensRequisicao() {
    if (_itensDaRequisicao.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Itens da Requisição:',
              style:
              TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _itensDaRequisicao.length,
          itemBuilder: (context, index) {
            final item = _itensDaRequisicao[index];
            return ListTile(
              title: Text(item.produtoNome),
              subtitle: Text('Cód: ${item.produtoCodigo}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Qtd: ${item.quantidadeSolicitada.toString().replaceAll('.', ',')}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removerItemDaLista(index),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildParceiroAutocomplete() {
    return Autocomplete<Map<String, dynamic>>(
      displayStringForOption: (option) => option['nome'] ?? '',
      optionsBuilder: (textValue) {
        if (textValue.text.isEmpty) return const Iterable.empty();
        final query = textValue.text.toLowerCase();
        return _listaDeClientes
            .where((p) => (p['nome'] ?? '').toLowerCase().contains(query));
      },
      onSelected: (p) {
        setState(() => _parceiroSelecionado = p);
        _parceiroAutocompleteController.text = p['nome'] ?? '';
      },
      fieldViewBuilder: (context, controller, focus, onSubmitted) {
        if (_parceiroAutocompleteController.text.isNotEmpty &&
            controller.text.isEmpty) {
          controller.text = _parceiroAutocompleteController.text;
        }
        return TextFormField(
          controller: controller,
          focusNode: focus,
          decoration: const InputDecoration(
              labelText: 'Cliente', border: OutlineInputBorder()),
          onChanged: (t) => _parceiroAutocompleteController.text = t,
        );
      },
    );
  }
}