// CÓDIGO COMPLETO E REpaginado PARA A TELA HOME

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'tela_cadastro_produto.dart';
import 'tela_historico.dart';
import 'tela_movimentacao.dart';
import 'tela_parceiros.dart';
import 'tela_extrato_movimentacoes.dart';
import 'tela_importacao_produtos.dart';
import 'tela_importacao_parceiros.dart';

class TelaHome extends StatefulWidget {
  const TelaHome({super.key});

  @override
  State<TelaHome> createState() => _TelaHomeState();
}

class _TelaHomeState extends State<TelaHome> {
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _adicionarCampoAtivoEmProdutosAntigos() async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    final produtosAntigosSnapshot = await db.collection('produtos').where('ativo', isEqualTo: null).get();
    if (produtosAntigosSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum produto antigo para atualizar!'), backgroundColor: Colors.blue),
      );
      return;
    }
    for (final doc in produtosAntigosSnapshot.docs) {
      batch.update(doc.reference, {'ativo': true});
    }
    await batch.commit();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${produtosAntigosSnapshot.docs.length} produtos foram atualizados com sucesso!'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('produtos')
          .where('ativo', isEqualTo: true)
          .orderBy('nome')
          .snapshots(),
      builder: (context, snapshot) {

        final produtos = snapshot.hasData ? snapshot.data!.docs : [];

        return Scaffold(
          appBar: _buildAppBar(produtos.length),
          drawer: _buildDrawer(),
          body: _buildBody(context, snapshot),
          floatingActionButton: _buildSpeedDial(),
        );
      },
    );
  }

  AppBar _buildAppBar(int totalProdutos) {
    if (!_isSearching) {
      return AppBar(
        title: Text('Estocando ($totalProdutos ativos)'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = true;
              });
            },
          ),
        ],
      );
    }
    else {
      return AppBar(
        backgroundColor: Colors.indigo,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchController.clear();
            });
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Buscar por código ou nome...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
            },
          ),
        ],
      );
    }
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.indigo),
            child: Text('Estocando Gemini', style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Clientes & Fornecedores'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaParceiros()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Extrato de Movimentações'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaExtratoMovimentacoes()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Importar Produtos'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaImportacaoProdutos()));
            },
          ),
          // NOVO BOTÃO ADICIONADO AQUI
          ListTile(
            leading: const Icon(Icons.group_add),
            title: const Text('Importar Parceiros'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaImportacaoParceiros()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.healing, color: Colors.orange),
            title: const Text('Corrigir Produtos Antigos'),
            subtitle: const Text('Clique uma vez para ativar produtos importados'),
            onTap: () {
              Navigator.pop(context);
              _adicionarCampoAtivoEmProdutosAntigos();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
    if (snapshot.hasError) {
      return const Center(child: Text('Erro ao carregar os dados. Pode ser necessário criar um índice no Firestore. Verifique o Debug Console.'));
    }
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum produto ativo cadastrado.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    List<QueryDocumentSnapshot> produtos = snapshot.data!.docs;
    final String query = _searchController.text.toLowerCase().trim();

    if (query.isNotEmpty) {
      produtos = produtos.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final nome = (data['nome'] ?? '').toLowerCase();
        final codigo = (data['codigo'] ?? '').toLowerCase();
        return nome.contains(query) || codigo.contains(query);
      }).toList();
    }

    produtos.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;
      final int quantidadeA = dataA['quantidadeAtual'] ?? 0;
      final int estoqueMinimoA = dataA['estoqueMinimo'] ?? 0;
      final int quantidadeB = dataB['quantidadeAtual'] ?? 0;
      final int estoqueMinimoB = dataB['estoqueMinimo'] ?? 0;

      int getPrioridade(int qtd, int min) {
        if (qtd == 0 && min > 0) return 1;
        if (qtd <= min && min > 0) return 2;
        return 3;
      }
      final prioridadeA = getPrioridade(quantidadeA, estoqueMinimoA);
      final prioridadeB = getPrioridade(quantidadeB, estoqueMinimoB);
      if (prioridadeA != prioridadeB) {
        return prioridadeA.compareTo(prioridadeB);
      }
      return 0;
    });

    if (produtos.isEmpty) {
      return Center(
        child: Text(
          'Nenhum produto encontrado para "$query"',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80.0),
      itemCount: produtos.length,
      itemBuilder: (context, index) {
        final produtoDoc = produtos[index];
        return _buildCardProduto(produtoDoc);
      },
    );
  }

  // ================== CARD DE PRODUTO ATUALIZADO ==================
  Widget _buildCardProduto(QueryDocumentSnapshot produtoDoc) {
    final data = produtoDoc.data() as Map<String, dynamic>;
    final String codigo = data['codigo'] ?? 'N/A';
    final String nome = data['nome'] ?? 'Sem nome';
    final int estoqueMinimo = data['estoqueMinimo'] ?? 0;
    final int quantidade = data['quantidadeAtual'] ?? 0;
    final double valor = data['valor'] ?? 0.0;
    final String? numeroSC = data['numeroSC'];

    bool estoqueCritico = (quantidade <= estoqueMinimo) && (estoqueMinimo > 0);
    bool estoqueZerado = (quantidade == 0) && (estoqueMinimo > 0);
    Color corStatus;
    if (estoqueZerado) {
      corStatus = Colors.red.shade700;
    } else if (estoqueCritico) {
      corStatus = Colors.orange.shade700;
    } else {
      corStatus = Colors.green.shade700;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      elevation: 2,
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: corStatus,
              child: Text(
                quantidade.toString(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            title: Text('$codigo - $nome', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            // O subtítulo foi removido para um layout mais limpo
            subtitle: null,
            // O valor agora fica na direita, ao lado das ações
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'R\$ ${valor.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'editar') {
                      _navegarParaCadastro(produtoParaEditar: produtoDoc);
                    } else if (value == 'excluir') {
                      _mostrarDialogoDeConfirmacao(produtoDoc);
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'editar',
                      child: ListTile(leading: Icon(Icons.edit), title: Text('Editar')),
                    ),
                    const PopupMenuItem<String>(
                      value: 'excluir',
                      child: ListTile(leading: Icon(Icons.delete), title: Text('Excluir')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (estoqueCritico)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: corStatus.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      numeroSC == null || numeroSC.isEmpty ? 'Atenção: Estoque baixo!' : 'SC Aberta: $numeroSC',
                      style: TextStyle(color: corStatus, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    icon: Icon(numeroSC == null || numeroSC.isEmpty ? Icons.add_comment : Icons.edit_note, color: corStatus, size: 20),
                    label: Text(numeroSC == null || numeroSC.isEmpty ? 'ADD SC' : 'EDITAR SC', style: TextStyle(color: corStatus, fontSize: 13)),
                    onPressed: () => _mostrarDialogoSC(produtoDoc),
                  )
                ],
              ),
            )
        ],
      ),
    );
  }

  Widget _buildSpeedDial() {
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: Colors.indigo,
      foregroundColor: Colors.white,
      overlayColor: Colors.black,
      overlayOpacity: 0.4,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.bar_chart),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          label: 'Ver Relatórios',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaRelatorios())),
        ),
        SpeedDialChild(
          child: const Icon(Icons.swap_horiz),
          backgroundColor: Colors.amber,
          foregroundColor: Colors.white,
          label: 'Realizar Movimentação',
          onTap: _navegarParaMovimentacao,
        ),
        SpeedDialChild(
          child: const Icon(Icons.post_add),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          label: 'Cadastrar Novo Produto',
          onTap: () => _navegarParaCadastro(),
        ),
      ],
    );
  }

  void _mostrarDialogoSC(QueryDocumentSnapshot produtoDoc) {
    final data = produtoDoc.data() as Map<String, dynamic>;
    final scController = TextEditingController(text: data['numeroSC']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Registrar SC para ${data["nome"]}'),
          content: TextField(controller: scController, decoration: const InputDecoration(labelText: 'Número da Solicitação de Compra')),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('produtos').doc(produtoDoc.id).update({
                  'numeroSC': scController.text.trim(),
                });
                Navigator.of(context).pop();
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  void _navegarParaCadastro({QueryDocumentSnapshot? produtoParaEditar}) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => TelaCadastroProduto(produtoParaEditar: produtoParaEditar)));
  }

  void _navegarParaMovimentacao() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaMovimentacao()));
  }

  void _mostrarDialogoDeConfirmacao(QueryDocumentSnapshot produtoDoc) {
    final data = produtoDoc.data() as Map<String, dynamic>;
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('Confirmar Exclusão'),
      content: Text('Tem certeza que deseja excluir o produto ${data["nome"]}?'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        TextButton(onPressed: () async {
          await FirebaseFirestore.instance.collection('produtos').doc(produtoDoc.id).delete();
          Navigator.of(context).pop();
        }, child: const Text('Excluir', style: TextStyle(color: Colors.red))),
      ],
    ));
  }
}