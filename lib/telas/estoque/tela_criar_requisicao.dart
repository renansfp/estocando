// lib/telas/tela_criar_requisicao.dart
// (VERSÃO v3.0 - INTEGRAÇÃO AUTOMÁTICA PRODUÇÃO/ALMOXARIFADO)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/models/requisicao.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TelaCriarRequisicao extends StatefulWidget {
  // --- PARÂMETROS PARA AUTOMAÇÃO (Vindo das Estações de Trabalho) ---
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
  User? _usuarioLogado;
  Map<String, dynamic>? _dadosUsuario;

  List<QueryDocumentSnapshot> _listaDeProdutos = [];
  List<QueryDocumentSnapshot> _listaDeParceiros = [];
  List<QueryDocumentSnapshot> _listaDeClientes = [];
  QueryDocumentSnapshot? _parceiroDocSelecionado;

  bool _carregandoDados = true;
  bool _isSalvando = false;

  final List<ItemRequisicao> _itensDaRequisicao = [];
  QueryDocumentSnapshot? _produtoSelecionadoParaAdicionar;

  String? _subtipoSelecionado;
  final List<String> _subtiposSaida = const ['OS', 'Colaborador', 'Venda (Pedido)', 'Venda (NF)', 'Itau'];

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
    // Carregamos os dados e depois aplicamos a automação
    _carregarDadosIniciais().then((_) {
      _aplicarPrePreenchimento();
    });
  }

  // --- LÓGICA DE AUTO-PREENCHIMENTO ---
  void _aplicarPrePreenchimento() {
    if (widget.osPrePreenchida != null || widget.ccPrePreenchido != null || widget.subTipoPrePreenchido != null) {
      setState(() {
        // 1. Define o Subtipo (Ex: 'OS')
        _subtipoSelecionado = widget.subTipoPrePreenchido ?? (widget.osPrePreenchida != null ? 'OS' : null);

        // 2. Preenche os controllers
        if (widget.osPrePreenchida != null) _numeroOsController.text = widget.osPrePreenchida!;
        if (widget.ccPrePreenchido != null) _centroDeCustoController.text = widget.ccPrePreenchido!;
      });

      // 3. Se tiver OS, dispara a busca de cliente automaticamente
      if (widget.osPrePreenchida != null) {
        _buscarDadosOS(widget.osPrePreenchida!);
      }
    }
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

  Future<void> _carregarDadosIniciais() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado.');
      _usuarioLogado = user;
      final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (!userDoc.exists || (userDoc.data() as Map<String, dynamic>)['empresaId'] == null) {
        throw Exception('ID da empresa não encontrados.');
      }
      _dadosUsuario = userDoc.data() as Map<String, dynamic>;
      _empresaId = _dadosUsuario!['empresaId'];

      final db = FirebaseFirestore.instance;
      final produtosFuture = db.collection('produtos').where('empresaId', isEqualTo: _empresaId).where('ativo', isEqualTo: true).orderBy('nome').get();
      final parceirosFuture = db.collection('parceiros').where('empresaId', isEqualTo: _empresaId).orderBy('nome').get();

      final results = await Future.wait([produtosFuture, parceirosFuture]);

      if (mounted) {
        setState(() {
          _listaDeProdutos = (results[0] as QuerySnapshot).docs;
          _listaDeParceiros = (results[1] as QuerySnapshot).docs;
          _listaDeClientes = _listaDeParceiros.where((doc) => (doc.data() as Map<String, dynamic>)['tipo'] == 'cliente').toList();
          _carregandoDados = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
        setState(() => _carregandoDados = false);
      }
    }
  }

  Future<void> _buscarDadosOS(String numeroOS) async {
    if (numeroOS.isEmpty) return;
    try {
      final query = await FirebaseFirestore.instance.collection('ordens_servico').where('empresaId', isEqualTo: _empresaId).where('numeroOS', isEqualTo: numeroOS).limit(1).get();

      QuerySnapshot res = query;
      if (query.docs.isEmpty && numeroOS.length < 5) {
        res = await FirebaseFirestore.instance.collection('ordens_servico').where('empresaId', isEqualTo: _empresaId).where('numeroOS', isEqualTo: numeroOS.padLeft(5, '0')).limit(1).get();
      }

      if (res.docs.isNotEmpty) {
        final dados = res.docs.first.data() as Map<String, dynamic>;
        final clienteNome = dados['clienteNome'];
        setState(() => _numeroOsController.text = dados['numeroOS'] ?? numeroOS);

        if (clienteNome != null) {
          try {
            _parceiroDocSelecionado = _listaDeClientes.firstWhere((p) => (p.data() as Map<String, dynamic>)['nome'] == clienteNome);
            _parceiroAutocompleteController.text = clienteNome;
          } catch (e) {
            setState(() {
              _parceiroDocSelecionado = null;
              _parceiroAutocompleteController.text = clienteNome;
            });
          }
        }
      }
    } catch (e) { print("Erro busca OS: $e"); }
  }

  // --- RESTANTE DOS MÉTODOS DE SALVAMENTO (Mantidos conforme sua lógica original) ---
  // _adicionarItemNaLista, _removerItemDaLista, _salvarRequisicao...
  // (Omitidos aqui por brevidade, mas devem permanecer no seu arquivo)

  void _adicionarItemNaLista() {
    if (_itemFormKey.currentState!.validate()) {
      QueryDocumentSnapshot? produto = _produtoSelecionadoParaAdicionar;

      if (produto == null) {
        final text = _produtoAutocompleteController.text.trim();
        try {
          produto = _listaDeProdutos.firstWhere((p) {
            final d = p.data() as Map<String, dynamic>;
            return '${d['codigo']} - ${d['nome']}'.toLowerCase() == text.toLowerCase();
          });
        } catch (e) { return; }
      }

      final dados = produto.data() as Map<String, dynamic>;
      final double qtd = double.parse(_qtdController.text.replaceAll(',', '.'));
      final idx = _itensDaRequisicao.indexWhere((i) => i.produtoId == produto!.id);

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
          _itensDaRequisicao.insert(0, ItemRequisicao(
            produtoId: produto!.id,
            produtoCodigo: dados['codigo'],
            produtoNome: dados['nome'],
            quantidadeSolicitada: qtd,
          ));
        }
        _produtoAutocompleteController.clear();
        _qtdController.clear();
        _produtoSelecionadoParaAdicionar = null;
      });
    }
  }
  void _removerItemDaLista(int index) {
    setState(() {
      _itensDaRequisicao.removeAt(index);
    });
  }
  Future<void> _salvarRequisicao() async {
    if (!_contextFormKey.currentState!.validate() || _itensDaRequisicao.isEmpty) return;
    setState(() => _isSalvando = true);
    try {
      String? nomeCli = _parceiroDocSelecionado != null
          ? (_parceiroDocSelecionado!.data() as Map<String, dynamic>)['nome']
          : _parceiroAutocompleteController.text;

      final nova = Requisicao(
        empresaId: _empresaId!,
        solicitanteId: _usuarioLogado!.uid,
        solicitanteNome: _dadosUsuario!['nome'] ?? 'N/D',
        dataSolicitacao: DateTime.now(),
        status: "PENDENTE",
        itens: _itensDaRequisicao,
        subTipo: _subtipoSelecionado!,
        numeroOS: _numeroOsController.text.trim(),
        centroDeCusto: _centroDeCustoController.text.trim(),
        nomeCliente: nomeCli,
        // ... outros campos (NF, Pedido, etc)
      );

      await FirebaseFirestore.instance.collection('requisicoes').add(nova.toJson());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
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
                  const Text('1. Destino / Motivo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 60)),
              child: _isSalvando ? const CircularProgressIndicator(color: Colors.white) : const Text('ENVIAR REQUISIÇÃO'),
            ),
          ),
        ],
      ),
    );
  }

  // (Mantenha seus Widgets auxiliares _buildSubtipoDropdown, _buildCamposCondicionais, etc. conforme seu original)
  // ...

  Widget _buildSubtipoDropdown() {
    return DropdownButtonFormField<String>(
      value: _subtipoSelecionado,
      hint: const Text('Destino / Motivo'),
      items: _subtiposSaida.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: (v) => setState(() => _subtipoSelecionado = v),
      validator: (v) => v == null ? 'Selecione' : null,
      decoration: const InputDecoration(border: OutlineInputBorder()),
    );
  }

  Widget _buildCamposCondicionais() {
    if (_subtipoSelecionado == null) return const SizedBox.shrink();
    return Column(
      children: [
        if (_subtipoSelecionado == 'OS')
          TextFormField(
            controller: _numeroOsController,
            decoration: InputDecoration(
              labelText: 'Número da OS',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: () => _buscarDadosOS(_numeroOsController.text)),
            ),
            onFieldSubmitted: (v) => _buscarDadosOS(v),
          ),
        const SizedBox(height: 16),
        if (_subtipoSelecionado == 'OS') _buildParceiroAutocomplete(),
        const SizedBox(height: 16),
        TextFormField(
          controller: _centroDeCustoController,
          decoration: const InputDecoration(labelText: 'Centro de Custo', border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildSelecaoProdutoAutocomplete() {
    return Autocomplete<QueryDocumentSnapshot>(
      displayStringForOption: (option) {
        final d = option.data() as Map<String, dynamic>;
        return '${d['codigo']} - ${d['nome']}';
      },
      optionsBuilder: (textValue) {
        if (textValue.text.isEmpty) return const Iterable.empty();
        return _listaDeProdutos.where((p) {
          final d = p.data() as Map<String, dynamic>;
          return d['nome'].toString().toLowerCase().contains(textValue.text.toLowerCase()) || d['codigo'].toString().contains(textValue.text);
        });
      },
      onSelected: (p) => _produtoSelecionadoParaAdicionar = p,
      fieldViewBuilder: (context, controller, focus, onSubmitted) {
        _produtoAutocompleteController.text = controller.text;
        return TextFormField(
          controller: controller,
          focusNode: focus,
          decoration: const InputDecoration(labelText: 'Produto', border: OutlineInputBorder()),
        );
      },
    );
  }

  Widget _buildCampoQuantidade() {
    return TextFormField(
      controller: _qtdController,
      decoration: const InputDecoration(labelText: 'Quantidade', border: OutlineInputBorder()),
      keyboardType: TextInputType.number,
    );
  }

  Widget _buildListaItensRequisicao() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _itensDaRequisicao.length,
      itemBuilder: (context, index) {
        final item = _itensDaRequisicao[index];
        return ListTile(
          title: Text(item.produtoNome),
          subtitle: Text('Qtd: ${item.quantidadeSolicitada}'),
          trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removerItemDaLista(index)),
        );
      },
    );
  }

  Widget _buildParceiroAutocomplete() {
    return Autocomplete<QueryDocumentSnapshot>(
      displayStringForOption: (option) => (option.data() as Map<String, dynamic>)['nome'] ?? '',
      optionsBuilder: (textValue) {
        if (textValue.text.isEmpty) return const Iterable.empty();
        return _listaDeClientes.where((c) => (c.data() as Map<String, dynamic>)['nome'].toString().toLowerCase().contains(textValue.text.toLowerCase()));
      },
      onSelected: (p) {
        setState(() => _parceiroDocSelecionado = p);
        _parceiroAutocompleteController.text = (p.data() as Map<String, dynamic>)['nome'];
      },
      fieldViewBuilder: (context, controller, focus, onSubmitted) {
        if (_parceiroAutocompleteController.text.isNotEmpty && controller.text.isEmpty) {
          controller.text = _parceiroAutocompleteController.text;
        }
        return TextFormField(controller: controller, focusNode: focus, decoration: const InputDecoration(labelText: 'Cliente', border: OutlineInputBorder()));
      },
    );
  }
}