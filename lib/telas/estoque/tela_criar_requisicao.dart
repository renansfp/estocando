// Salve como: lib/telas/tela_criar_requisicao.dart
// (VERSÃO ATUALIZADA - Com Busca de OS e Preenchimento Automático)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/models/requisicao.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TelaCriarRequisicao extends StatefulWidget {
  const TelaCriarRequisicao({super.key});

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
  final List<String> _subtiposSaida = const [ 'OS', 'Colaborador', 'Venda (Pedido)', 'Venda (NF)', 'Itau' ];

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
    _carregarDadosIniciais();
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
        throw Exception('ID da empresa ou dados do usuário não encontrados.');
      }
      final dadosUsuario = userDoc.data() as Map<String, dynamic>;
      final empresaId = dadosUsuario['empresaId'];

      final db = FirebaseFirestore.instance;
      final produtosFuture = db.collection('produtos')
          .where('empresaId', isEqualTo: empresaId)
          .where('ativo', isEqualTo: true)
          .orderBy('nome')
          .get();

      final parceirosFuture = db.collection('parceiros')
          .where('empresaId', isEqualTo: empresaId)
          .orderBy('nome')
          .get();

      final results = await Future.wait([produtosFuture, parceirosFuture]);
      final produtosSnapshot = results[0] as QuerySnapshot;
      final parceirosSnapshot = results[1] as QuerySnapshot;

      if (mounted) {
        setState(() {
          _empresaId = empresaId;
          _dadosUsuario = dadosUsuario;
          _listaDeProdutos = produtosSnapshot.docs;
          _listaDeParceiros = parceirosSnapshot.docs;

          _listaDeClientes = _listaDeParceiros.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['tipo'] == 'cliente';
          }).toList();

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

  // --- FUNÇÃO NOVA: BUSCAR DADOS DA OS ---
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OS não encontrada ou finalizada.')));
      } else {
        // Pega os dados com segurança de tipo
        final dados = resultadoFinal.docs.first.data() as Map<String, dynamic>;

        final clienteNome = dados['clienteNome'];

        // Atualiza o ID da OS na tela (caso tenha achado pelo zero à esquerda)
        _numeroOsController.text = dados['numeroOS'] ?? numeroOS;

        // Tenta selecionar o cliente automaticamente
        if (clienteNome != null) {
          try {
            final parceiro = _listaDeClientes.firstWhere(
                    (p) => (p.data() as Map<String, dynamic>)['nome'] == clienteNome
            );

            setState(() {
              _parceiroDocSelecionado = parceiro;
              _parceiroAutocompleteController.text = clienteNome;
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vinculado: $clienteNome'), backgroundColor: Colors.green));
          } catch (e) {
            // Se não achar o cadastro, preenche apenas o texto
            setState(() {
              _parceiroDocSelecionado = null;
              _parceiroAutocompleteController.text = clienteNome;
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cliente preenchido: $clienteNome'), backgroundColor: Colors.amber));
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao buscar OS: $e')));
    }
  }

  void _adicionarItemNaLista() {
    if (_itemFormKey.currentState!.validate()) {
      QueryDocumentSnapshot? produtoParaAdicionar = _produtoSelecionadoParaAdicionar;

      if (produtoParaAdicionar == null) {
        final currentText = _produtoAutocompleteController.text.trim();
        if (currentText.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um produto.'), backgroundColor: Colors.red));
          return;
        }
        try {
          produtoParaAdicionar = _listaDeProdutos.firstWhere((p) {
            final data = p.data() as Map<String, dynamic>;
            final displayString = '${data['codigo']} - ${data['nome']}';
            return displayString.toLowerCase() == currentText.toLowerCase();
          });
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produto não encontrado. Selecione da lista.'), backgroundColor: Colors.red));
          return;
        }
      }

      final dadosProduto = produtoParaAdicionar.data() as Map<String, dynamic>;
      final double quantidade = double.parse(_qtdController.text.replaceAll(',', '.'));
      final indexExistente = _itensDaRequisicao.indexWhere((item) => item.produtoId == produtoParaAdicionar!.id);

      if (indexExistente != -1) {
        final itemExistente = _itensDaRequisicao[indexExistente];
        setState(() {
          _itensDaRequisicao[indexExistente] = ItemRequisicao(
            produtoId: itemExistente.produtoId,
            produtoCodigo: itemExistente.produtoCodigo,
            produtoNome: itemExistente.produtoNome,
            quantidadeSolicitada: itemExistente.quantidadeSolicitada + quantidade,
          );
        });
      } else {
        final novoItem = ItemRequisicao(
          produtoId: produtoParaAdicionar.id,
          produtoCodigo: dadosProduto['codigo'],
          produtoNome: dadosProduto['nome'],
          quantidadeSolicitada: quantidade,
        );
        setState(() {
          _itensDaRequisicao.insert(0, novoItem);
        });
      }
      _produtoSelecionadoParaAdicionar = null;
      _produtoAutocompleteController.clear();
      _qtdController.clear();
      FocusScope.of(context).unfocus();
      setState(() {});
    }
  }

  void _removerItemDaLista(int index) {
    setState(() {
      _itensDaRequisicao.removeAt(index);
    });
  }

  Future<void> _salvarRequisicao() async {
    if (!_contextFormKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha os campos obrigatórios.'), backgroundColor: Colors.red));
      return;
    }
    if (_itensDaRequisicao.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adicione pelo menos um item.'), backgroundColor: Colors.red));
      return;
    }

    setState(() { _isSalvando = true; });
    final db = FirebaseFirestore.instance;
    String? erroEstoque;

    try {
      await db.runTransaction((transaction) async {
        for (final item in _itensDaRequisicao) {
          final produtoRef = db.collection('produtos').doc(item.produtoId);
          final produtoSnapshot = await transaction.get(produtoRef);
          if (!produtoSnapshot.exists) {
            erroEstoque = 'O produto ${item.produtoNome} não foi encontrado.';
            throw Exception(erroEstoque);
          }
          final dadosProduto = produtoSnapshot.data() as Map<String, dynamic>;
          final estoqueAtual = (dadosProduto['quantidadeAtual'] ?? 0).toDouble();

          // Opcional: Bloquear se não tiver estoque. Se quiser permitir, comente este IF.
          /*
          if (estoqueAtual < item.quantidadeSolicitada) {
            erroEstoque = 'Estoque insuficiente para: ${item.produtoNome}. (Disponível: $estoqueAtual)';
            throw Exception(erroEstoque);
          }
          */
        }
      });

      String? nomeClienteFinal;
      if (_parceiroDocSelecionado != null) {
        nomeClienteFinal = (_parceiroDocSelecionado!.data() as Map<String, dynamic>)['nome'];
      } else if (_parceiroAutocompleteController.text.isNotEmpty) {
        nomeClienteFinal = _parceiroAutocompleteController.text;
      }

      final novaRequisicao = Requisicao(
        empresaId: _empresaId!,
        solicitanteId: _usuarioLogado!.uid,
        solicitanteNome: _dadosUsuario!['nome'] ?? 'Nome não encontrado',
        dataSolicitacao: DateTime.now(),
        status: "PENDENTE",
        itens: _itensDaRequisicao,
        subTipo: _subtipoSelecionado!,
        numeroOS: _numeroOsController.text.trim().isNotEmpty ? _numeroOsController.text.trim() : null,
        nomeColaborador: _colaboradorController.text.trim().isNotEmpty ? _colaboradorController.text.trim() : null,
        centroDeCusto: _centroDeCustoController.text.trim().isNotEmpty ? _centroDeCustoController.text.trim() : null,
        numeroPedido: _numeroPedidoController.text.trim().isNotEmpty ? _numeroPedidoController.text.trim() : null,
        numeroNF: _numeroNfController.text.trim().isNotEmpty ? _numeroNfController.text.trim() : null,
        agencia: _agenciaController.text.trim().isNotEmpty ? _agenciaController.text.trim() : null,
        nomeCliente: nomeClienteFinal,
      );
      await FirebaseFirestore.instance
          .collection('requisicoes')
          .add(novaRequisicao.toJson());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Requisição enviada com sucesso!'), backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }

    } catch (e) {
      String mensagemErro = erroEstoque ?? e.toString().replaceAll("Exception: ", "");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $mensagemErro'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() { _isSalvando = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar Requisição')),
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
          const Divider(thickness: 2, height: 20),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _itemFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('2. Itens', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildSelecaoProdutoAutocomplete(),
                  const SizedBox(height: 16),
                  _buildCampoQuantidade(),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Adicionar Item'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 16), minimumSize: const Size(double.infinity, 50)),
                    onPressed: _adicionarItemNaLista,
                  ),
                ],
              ),
            ),
          ),
          const Divider(thickness: 2),
          _buildListaItensRequisicao(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _isSalvando ? null : _salvarRequisicao,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 20), minimumSize: const Size(double.infinity, 60)),
              child: _isSalvando ? const CircularProgressIndicator(color: Colors.white) : const Text('Enviar Requisição', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildSelecaoProdutoAutocomplete() {
    return Autocomplete<QueryDocumentSnapshot>(
      displayStringForOption: (option) {
        final data = option.data() as Map<String, dynamic>;
        return '${data['codigo']} - ${data['nome']}';
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        textEditingController.addListener(() {
          if (_produtoAutocompleteController.text != textEditingController.text) {
            _produtoAutocompleteController.value = textEditingController.value;
          }
        });
        if (_produtoAutocompleteController.text.isEmpty && textEditingController.text.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_produtoAutocompleteController.text.isEmpty) textEditingController.clear();
          });
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
                _produtoAutocompleteController.clear();
                _produtoSelecionadoParaAdicionar = null;
                focusNode.requestFocus();
              },
            ),
          ),
          validator: (value) => (value == null || value.isEmpty) ? 'Selecione um produto.' : null,
          onFieldSubmitted: (_) => _adicionarItemNaLista(),
        );
      },
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.toLowerCase().trim();
        if (query.isEmpty) return const Iterable<QueryDocumentSnapshot>.empty();
        final List<QueryDocumentSnapshot> suggestions = _listaDeProdutos.where((option) {
          final data = option.data() as Map<String, dynamic>;
          final nome = (data['nome'] ?? '').toLowerCase();
          final codigo = (data['codigo'] ?? '').toLowerCase();
          return codigo.startsWith(query) || nome.contains(query);
        }).toList();
        return suggestions;
      },
      onSelected: (selection) {
        _produtoSelecionadoParaAdicionar = selection;
        FocusScope.of(context).nextFocus();
      },
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
      onFieldSubmitted: (_) => _adicionarItemNaLista(),
    );
  }

  Widget _buildListaItensRequisicao() {
    if (_itensDaRequisicao.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 32.0), child: Text('Nenhum item adicionado.', style: TextStyle(fontSize: 16, color: Colors.grey))));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _itensDaRequisicao.length,
      itemBuilder: (context, index) {
        final item = _itensDaRequisicao[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            title: Text(item.produtoNome),
            subtitle: Text('Código: ${item.produtoCodigo}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Qtd: ${item.quantidadeSolicitada.toString().replaceAll('.', ',')}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _removerItemDaLista(index)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubtipoDropdown() {
    return DropdownButtonFormField<String>(
      value: _subtipoSelecionado,
      hint: const Text('Destino / Motivo'),
      isExpanded: true,
      items: _subtiposSaida.map((String v) => DropdownMenuItem<String>(value: v, child: Text(v))).toList(),
      onChanged: (v) => setState(() {
        _subtipoSelecionado = v;
        _parceiroDocSelecionado = null;
        _parceiroAutocompleteController.clear();
      }),
      validator: (v) => v == null ? 'Selecione uma opção' : null,
      decoration: const InputDecoration(border: OutlineInputBorder()),
    );
  }

  Widget _buildCampoCentroDeCusto() {
    return TextFormField(
      controller: _centroDeCustoController,
      decoration: const InputDecoration(labelText: 'Centro de Custo', border: OutlineInputBorder()),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
    );
  }

  Widget _buildParceiroAutocomplete() {
    return Autocomplete<QueryDocumentSnapshot>(
      displayStringForOption: (option) => (option.data() as Map<String, dynamic>)['nome'] ?? '',
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
            labelText: 'Cliente',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                textEditingController.clear();
                _parceiroAutocompleteController.clear();
                setState(() => _parceiroDocSelecionado = null);
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'O cliente é obrigatório.';
            if (_parceiroDocSelecionado == null && _parceiroAutocompleteController.text.isEmpty) return 'Selecione um cliente válido.';
            return null;
          },
        );
      },
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) return const Iterable<QueryDocumentSnapshot>.empty();
        return _listaDeClientes.where((option) {
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

  Widget _buildCamposCondicionais() {
    if (_subtipoSelecionado == null) return const SizedBox.shrink();

    final bool precisaCliente = _subtipoSelecionado == 'OS' ||
        _subtipoSelecionado == 'Venda (NF)' ||
        _subtipoSelecionado == 'Venda (Pedido)';

    return Wrap(
      runSpacing: 16,
      spacing: 16,
      children: [
        if (_subtipoSelecionado == 'Venda (NF)')
          TextFormField(
            controller: _numeroNfController,
            decoration: const InputDecoration(labelText: 'Número da NF', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
          ),
        if (_subtipoSelecionado == 'Venda (Pedido)')
          TextFormField(
            controller: _numeroPedidoController,
            decoration: const InputDecoration(labelText: 'Número do Pedido', border: OutlineInputBorder()),
            keyboardType: TextInputType.text,
          ),

        // --- AQUI ESTÁ A MÁGICA DA BUSCA DE OS ---
        if (_subtipoSelecionado == 'OS')
          TextFormField(
            controller: _numeroOsController,
            decoration: InputDecoration(
              labelText: 'Número da OS',
              border: const OutlineInputBorder(),
              // Ícone de lupa que chama a busca
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, color: Colors.blue),
                onPressed: () => _buscarDadosOS(_numeroOsController.text),
              ),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
            // Busca ao dar Enter
            onFieldSubmitted: (val) => _buscarDadosOS(val),
          ),

        if (_subtipoSelecionado == 'Itau')
          TextFormField(
            controller: _agenciaController,
            decoration: const InputDecoration(labelText: 'Número da AG', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
          ),
        if (_subtipoSelecionado == 'Colaborador')
          TextFormField(
            controller: _colaboradorController,
            decoration: const InputDecoration(labelText: 'Nome do Colaborador', border: OutlineInputBorder()),
            textCapitalization: TextCapitalization.characters,
          ),

        // Campo de cliente (será preenchido automático se achar OS)
        if (precisaCliente)
          _buildParceiroAutocomplete(),

        if (_subtipoSelecionado != null)
          _buildCampoCentroDeCusto(),
      ],
    );
  }
}