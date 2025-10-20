// CÓDIGO COMPLETO - telas/tela_criar_requisicao.dart (v. 20/10/2025 - Filtro corrigido, tentando limpeza)

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
  bool _carregandoDados = true;
  bool _isSalvando = false;

  final List<ItemRequisicao> _itensDaRequisicao = [];
  QueryDocumentSnapshot? _produtoSelecionadoParaAdicionar;

  String? _subtipoSelecionado;
  final List<String> _subtiposSaida = const [
    'OS',
    'Colaborador',
    'Venda (Pedido)',
    'Venda (NF)',
    'Itau'
  ];

  // Controller para REFERÊNCIA do texto atual, mas não para controle direto do TextFormField
  final _produtoAutocompleteController = TextEditingController();
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
      final produtosSnapshot = await FirebaseFirestore.instance
          .collection('produtos')
          .where('empresaId', isEqualTo: empresaId)
          .where('ativo', isEqualTo: true)
          .orderBy('nome')
          .get();
      if (mounted) {
        setState(() {
          _empresaId = empresaId;
          _dadosUsuario = dadosUsuario;
          _listaDeProdutos = produtosSnapshot.docs;
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
    if (_itemFormKey.currentState!.validate()) {
      QueryDocumentSnapshot? produtoParaAdicionar = _produtoSelecionadoParaAdicionar;

      if (produtoParaAdicionar == null) {
        final currentText = _produtoAutocompleteController.text.trim(); // Usa nosso controller como referência
        if (currentText.isEmpty) { // Adiciona validação extra para campo vazio
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

      // Limpa os campos após adicionar
      _produtoSelecionadoParaAdicionar = null;
      _produtoAutocompleteController.clear(); // Limpa nosso controller de referência
      _qtdController.clear();
      FocusScope.of(context).unfocus(); // Esconde o teclado
      // Força um rebuild para garantir que a limpeza seja refletida visualmente
      // Isso é crucial para que o fieldViewBuilder use o controller interno limpo na próxima vez
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha o Destino/Motivo da requisição.'), backgroundColor: Colors.red));
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
      await db.runTransaction((transaction) async {
        print("DEBUG (Criar Req): Iniciando verificação de estoque...");
        for (final item in _itensDaRequisicao) {
          final produtoRef = db.collection('produtos').doc(item.produtoId);
          print("DEBUG (Criar Req): Verificando ${item.produtoNome} (ID: ${item.produtoId})");
          final produtoSnapshot = await transaction.get(produtoRef);
          if (!produtoSnapshot.exists) {
            erroEstoque = 'O produto ${item.produtoNome} não foi encontrado.';
            print("DEBUG (Criar Req): Erro - $erroEstoque");
            throw Exception(erroEstoque);
          }
          final dadosProduto = produtoSnapshot.data() as Map<String, dynamic>;
          final estoqueAtual = (dadosProduto['quantidadeAtual'] ?? 0).toDouble();
          print("DEBUG (Criar Req): Estoque ${item.produtoNome}: $estoqueAtual, Solicitado: ${item.quantidadeSolicitada}");
          if (estoqueAtual < item.quantidadeSolicitada) {
            erroEstoque = 'Estoque insuficiente para: ${item.produtoNome}. (Disponível: $estoqueAtual)';
            print("DEBUG (Criar Req): Erro - $erroEstoque");
            throw Exception(erroEstoque);
          }
        }
        print("DEBUG (Criar Req): Verificação de estoque OK.");
      });

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
      print("--- ERRO AO ENVIAR REQUISIÇÃO ---");
      print(mensagemErro);
      print("Erro original: $e");
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
          : ListView( // Usamos ListView para evitar overflow com o teclado
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
                      minimumSize: const Size(double.infinity, 50), // Garante largura total
                    ),
                    onPressed: _adicionarItemNaLista,
                  ),
                ],
              ),
            ),
          ),
          const Divider(thickness: 2),
          // O Container com constraints pode ser removido ou ajustado
          // Se a lista ficar muito grande, o ListView pai já permite rolar
          _buildListaItensRequisicao(),
          // Container(
          //   constraints: const BoxConstraints(maxHeight: 250),
          //   child: _buildListaItensRequisicao(),
          // ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _isSalvando ? null : _salvarRequisicao,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                minimumSize: const Size(double.infinity, 60), // Garante largura total
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

  // --- Widgets de Item ---
  Widget _buildSelecaoProdutoAutocomplete() {
    return Autocomplete<QueryDocumentSnapshot>(
      displayStringForOption: (option) {
        final data = option.data() as Map<String, dynamic>;
        return '${data['codigo']} - ${data['nome']}';
      },
      // ---> MUDANÇA: Voltamos a usar o textEditingController interno <---
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        // Sincroniza o nosso controller com o interno QUANDO o interno muda
        textEditingController.addListener(() {
          if (_produtoAutocompleteController.text != textEditingController.text) {
            // Atualiza nosso controller silenciosamente para referência
            _produtoAutocompleteController.value = textEditingController.value;
          }
        });
        // Se o nosso controller foi limpo (após adicionar), limpa o interno também
        if (_produtoAutocompleteController.text.isEmpty && textEditingController.text.isNotEmpty) {
          // Usamos addPostFrameCallback para evitar erro de build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Verifica se o controller interno ainda tem texto antes de limpar
            // Isso evita limpar se o usuário já começou a digitar algo novo
            if (_produtoAutocompleteController.text.isEmpty) {
              textEditingController.clear();
            }
          });
        }

        return TextFormField(
          controller: textEditingController, // <-- VOLTOU a usar o controller do builder
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: _carregandoDados ? 'Carregando Produtos...' : 'Produto',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                textEditingController.clear(); // Limpa o interno
                _produtoAutocompleteController.clear(); // Limpa o nosso
                _produtoSelecionadoParaAdicionar = null;
                focusNode.requestFocus();
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Selecione um produto.';
            }
            // Validação se é válido é feita no _adicionarItemNaLista
            return null;
          },
          onFieldSubmitted: (_) {
            // Tenta adicionar o item se o usuário apertar Enter no teclado
            // A validação completa será feita dentro de _adicionarItemNaLista
            _adicionarItemNaLista();
          },
        );
      },
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.toLowerCase().trim();
        if (query.isEmpty) return const Iterable<QueryDocumentSnapshot>.empty();

        final exactCodeMatch = _listaDeProdutos.where((option) {
          final data = option.data() as Map<String, dynamic>;
          final codigo = (data['codigo'] ?? '').toLowerCase();
          return codigo == query;
        }).toList();

        if (exactCodeMatch.length == 1) return exactCodeMatch;
        if (exactCodeMatch.length > 1) return exactCodeMatch;

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
        print("DEBUG: Item selecionado via onSelected: ${selection.id}");
        _produtoSelecionadoParaAdicionar = selection; // Guarda a seleção
        // O Autocomplete já atualiza o textEditingController interno.
        // O listener que adicionamos no fieldViewBuilder atualizará o nosso _produtoAutocompleteController.
        FocusScope.of(context).nextFocus(); // Move o foco para Quantidade
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
      onFieldSubmitted: (_) => _adicionarItemNaLista(), // Aperta Enter aqui, adiciona o item
    );
  }

  Widget _buildListaItensRequisicao() {
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

    // Usamos ListView.builder diretamente, sem Container com altura fixa
    // pois o pai já é um ListView que permite rolar.
    return ListView.builder(
      shrinkWrap: true, // Importante para estar dentro de outro ListView
      physics: const NeverScrollableScrollPhysics(), // Impede scroll interno
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
      onChanged: (v) => setState(() => _subtipoSelecionado = v),
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

  Widget _buildCamposCondicionais() {
    if (_subtipoSelecionado == null) return const SizedBox.shrink();

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
        if (_subtipoSelecionado != null)
          _buildCampoCentroDeCusto(),
      ],
    );
  }
} // FIM DA CLASSE