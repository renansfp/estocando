// CÓDIGO COMPLETO - telas/tela_criar_requisicao.dart (v. 22/10/2025 - com Campo de Cliente)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estocando/models/requisicao.dart';
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
  // ---> MUDANÇA 1: Variáveis para carregar e selecionar parceiros
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
  // ---> MUDANÇA 2: Novo controller para o cliente
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
    _parceiroAutocompleteController.dispose(); // <-- MUDANÇA 3: Dispose
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

      // ---> MUDANÇA 4: Carregar produtos E parceiros
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

      // Espera ambos terminarem
      final results = await Future.wait([produtosFuture, parceirosFuture]);
      final produtosSnapshot = results[0] as QuerySnapshot;
      final parceirosSnapshot = results[1] as QuerySnapshot;

      if (mounted) {
        setState(() {
          _empresaId = empresaId;
          _dadosUsuario = dadosUsuario;
          _listaDeProdutos = produtosSnapshot.docs;
          _listaDeParceiros = parceirosSnapshot.docs;
          // Filtra apenas os clientes para o autocomplete
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

  void _adicionarItemNaLista() {
    // (Esta função permanece idêntica)
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produto não encontrado ou inválido. Selecione um item da lista ou digite o código/nome exato.'), backgroundColor: Colors.red, duration: Duration(seconds: 4),));
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
    // (Esta função é quase idêntica, apenas adiciona 'nomeCliente')
    if (!_contextFormKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha os campos obrigatórios da requisição.'), backgroundColor: Colors.red));
      return;
    }
    if (_itensDaRequisicao.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adicione pelo menos um item à requisição.'), backgroundColor: Colors.red));
      return;
    }
    if (_isSalvando || _usuarioLogado == null || _empresaId == null || _dadosUsuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dados do usuário não carregados.'), backgroundColor: Colors.red));
      return;
    }

    setState(() { _isSalvando = true; });
    final db = FirebaseFirestore.instance;
    String? erroEstoque;

    try {
      // Verificação de estoque (idêntica)
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
          if (estoqueAtual < item.quantidadeSolicitada) {
            erroEstoque = 'Estoque insuficiente para: ${item.produtoNome}. (Disponível: $estoqueAtual)';
            throw Exception(erroEstoque);
          }
        }
      });

      // ---> MUDANÇA 5: Passar o nome do cliente selecionado para o objeto
      String? nomeClienteFinal;
      if (_parceiroDocSelecionado != null) {
        nomeClienteFinal = (_parceiroDocSelecionado!.data() as Map<String, dynamic>)['nome'];
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
        nomeCliente: nomeClienteFinal, // <-- AQUI!
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro: $mensagemErro'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8)
        ));
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
      appBar: AppBar(
        title: const Text('Criar Requisição'),
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
                  const Text('1. Destino / Motivo da Requisição', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildSubtipoDropdown(),
                  const SizedBox(height: 10),
                  _buildCamposCondicionais(), // <-- O campo de cliente será adicionado aqui dentro
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
                  const Text('2. Itens da Requisição', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildSelecaoProdutoAutocomplete(),
                  const SizedBox(height: 16),
                  _buildCampoQuantidade(),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Adicionar Item'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 50),
                    ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                minimumSize: const Size(double.infinity, 60),
              ),
              child: _isSalvando
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Enviar Requisição'),
            ),
          ),
        ],
      ),
    );
  }

  // --- Widgets de Item (Idênticos) ---
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
            if (_produtoAutocompleteController.text.isEmpty) {
              textEditingController.clear();
            }
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
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Selecione um produto.';
            }
            return null;
          },
          onFieldSubmitted: (_) {
            _adicionarItemNaLista();
          },
        );
      },
      optionsBuilder: (TextEditingValue textEditingValue) {
        // (Lógica de busca idêntica)
        final query = textEditingValue.text.toLowerCase().trim();
        if (query.isEmpty) return const Iterable<QueryDocumentSnapshot>.empty();
        final exactCodeMatch = _listaDeProdutos.where((option) {
          final data = option.data() as Map<String, dynamic>;
          final codigo = (data['codigo'] ?? '').toLowerCase();
          return codigo == query;
        }).toList();
        if (exactCodeMatch.length >= 1) return exactCodeMatch;
        final List<QueryDocumentSnapshot> suggestions = _listaDeProdutos.where((option) {
          final data = option.data() as Map<String, dynamic>;
          final nome = (data['nome'] ?? '').toLowerCase();
          final codigo = (data['codigo'] ?? '').toLowerCase();
          return codigo.startsWith(query) || nome.startsWith(query);
        }).toList();
        suggestions.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final codigoA = (dataA['codigo'] ?? '').toLowerCase();
          final nomeA = (dataA['nome'] ?? '').toLowerCase();
          final dataB = b.data() as Map<String, dynamic>;
          final codigoB = (dataB['codigo'] ?? '').toLowerCase();
          final String nomeB = (dataB['nome'] ?? '').toLowerCase();
          final bool aHasCodeMatch = codigoA.startsWith(query);
          final bool bHasCodeMatch = codigoB.startsWith(query);
          if (aHasCodeMatch && !bHasCodeMatch) return -1;
          if (!aHasCodeMatch && bHasCodeMatch) return 1;
          return nomeA.compareTo(nomeB);
        });
        return suggestions;
      },
      onSelected: (selection) {
        _produtoSelecionadoParaAdicionar = selection;
        FocusScope.of(context).nextFocus();
      },
    );
  }

  Widget _buildCampoQuantidade() {
    // (Idêntico)
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
    // (Idêntico)
    if (_itensDaRequisicao.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32.0),
          child: Text(
            'Nenhum item adicionado.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
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
                Text(
                  'Qtd: ${item.quantidadeSolicitada.toString().replaceAll('.', ',')}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removerItemDaLista(index),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Widgets de Contexto ---
  Widget _buildSubtipoDropdown() {
    return DropdownButtonFormField<String>(
      value: _subtipoSelecionado,
      hint: const Text('Destino / Motivo'),
      isExpanded: true,
      items: _subtiposSaida.map((String v) => DropdownMenuItem<String>(value: v, child: Text(v))).toList(),
      onChanged: (v) => setState(() {
        _subtipoSelecionado = v;
        // ---> MUDANÇA 6: Limpar seleção de cliente ao mudar o tipo
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

  // ---> MUDANÇA 7: Novo widget para selecionar cliente
  Widget _buildParceiroAutocomplete() {
    return Autocomplete<QueryDocumentSnapshot>(
      displayStringForOption: (option) => (option.data() as Map<String, dynamic>)['nome'] ?? '',
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        // Sincroniza os controllers
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
            // Obrigatório para estes tipos
            if (value == null || value.isEmpty) return 'O cliente é obrigatório.';
            // Se digitou algo mas não selecionou da lista
            if (_parceiroDocSelecionado == null) return 'Selecione um cliente válido.';
            return null;
          },
        );
      },
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) return const Iterable<QueryDocumentSnapshot>.empty();
        // Filtra da lista de clientes que já carregamos
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

  // ---> MUDANÇA 8: Adicionar o campo de cliente nos tipos corretos
  Widget _buildCamposCondicionais() {
    if (_subtipoSelecionado == null) return const SizedBox.shrink();

    // Campos que precisam de Cliente
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
        if (_subtipoSelecionado == 'OS')
          TextFormField(
            controller: _numeroOsController,
            decoration: const InputDecoration(labelText: 'Número da OS', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
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

        // Adiciona o campo de cliente se necessário
        if (precisaCliente)
          _buildParceiroAutocomplete(),

        // Adiciona o Centro de Custo para (quase) todos
        if (_subtipoSelecionado != null)
          _buildCampoCentroDeCusto(),
      ],
    );
  }
}