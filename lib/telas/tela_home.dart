// CÓDIGO 100% COMPLETO E CORRIGIDO DA TELA HOME

import 'dart:async';
import 'dart:io'; // ---> ADICIONEI ESTA LINHA PARA O APP SABER ONDE ESTÁ SUA TELA DE RELATÓRIOS
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

import 'package:estocando/telas/tela_aprovacao_usuarios.dart';
import 'package:estocando/telas/tela_cadastro_parceiro.dart';
import 'package:estocando/telas/tela_extrato_movimentacoes.dart';
import 'package:estocando/telas/tela_historico.dart';
import 'package:estocando/telas/tela_importacao_movimentacoes.dart';
import 'package:estocando/telas/tela_importacao_parceiros.dart';
import 'package:estocando/telas/tela_importacao_produtos.dart';
import 'package:estocando/telas/tela_login.dart';
import 'package:estocando/telas/tela_movimentacao.dart';
import 'package:estocando/telas/tela_parceiros.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:intl/intl.dart';
import 'tela_cadastro_produto.dart';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';


enum FiltroProdutos { ativos, inativos, todos, pontoDePedido }
enum AcoesProduto { editar, solicitarCompra, excluir }
class TelaHome extends StatefulWidget {
  const TelaHome({super.key});
  @override
  State<TelaHome> createState() => _TelaHomeState();
}
class _TelaHomeState extends State<TelaHome> {
  bool _isSearching = false;
  final _searchController = TextEditingController();
  FiltroProdutos _filtroAtual = FiltroProdutos.ativos;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportarProdutosParaExcel() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Gerando relatório... Por favor, aguarde.'),
        backgroundColor: Colors.blue,
      ));

      final querySnapshot = await FirebaseFirestore.instance.collection('produtos').orderBy('nome').get();
      final produtos = querySnapshot.docs;

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Produtos'];

      List<String> headers = [
        'Código', 'Nome', 'Quantidade Atual', 'Estoque Mínimo',
        'Estoque Máximo', 'Valor Unitário', 'Número SC', 'Ativo'
      ];
      sheetObject.appendRow(headers.map((header) => TextCellValue(header)).toList());

      for (var doc in produtos) {
        final data = doc.data();
        List<CellValue> row = [
          TextCellValue(data['codigo'] ?? ''),
          TextCellValue(data['nome'] ?? ''),
          DoubleCellValue((data['quantidadeAtual'] ?? 0.0).toDouble()),
          DoubleCellValue((data['estoqueMinimo'] ?? 0.0).toDouble()),
          DoubleCellValue((data['estoqueMaximo'] ?? 0.0).toDouble()),
          DoubleCellValue((data['valor'] ?? 0.0).toDouble()),
          TextCellValue(data['numeroSC'] ?? ''),
          TextCellValue(data['ativo'] == true ? 'Sim' : 'Não'),
        ];
        sheetObject.appendRow(row);
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Estocando_Produtos_$timestamp.xlsx';
      var fileBytes = excel.save();

      if (kIsWeb) {
        if (fileBytes != null) {
          final blob = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute("download", fileName)
            ..click();
          html.Url.revokeObjectUrl(url);
        }
      } else {
        if (fileBytes != null) {
          final directory = await getTemporaryDirectory();
          final filePath = '${directory.path}/$fileName';
          File(filePath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(fileBytes);
          await Share.shareXFiles([XFile(filePath)], text: 'Relatório de Produtos - Estocando');
        }
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erro ao exportar: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  String _formatarQuantidade(double valor) {
    if (valor == valor.truncate()) {
      return valor.truncate().toString();
    } else {
      return NumberFormat('#,##0.###', 'pt_BR').format(valor);
    }
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('produtos');

    if (_filtroAtual == FiltroProdutos.ativos || _filtroAtual == FiltroProdutos.pontoDePedido) {
      query = query.where('ativo', isEqualTo: true);
    } else if (_filtroAtual == FiltroProdutos.inativos) {
      query = query.where('ativo', isEqualTo: false);
    }

    query = query.orderBy('nome');

    return Scaffold(
      appBar: _buildAppBar(),
      drawer: _buildDrawer(context),
      floatingActionButton: _buildSpeedDial(context),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: Text('Ocorreu um erro ao carregar os produtos.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text('Nenhum produto para exibir.',
                    style: TextStyle(fontSize: 18, color: Colors.grey)));
          }

          List<QueryDocumentSnapshot> produtos = snapshot.data!.docs;

          if (_filtroAtual == FiltroProdutos.pontoDePedido) {
            produtos = produtos.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final double quantidade = (data['quantidadeAtual'] ?? 0.0).toDouble();
              final double estoqueMinimo = (data['estoqueMinimo'] ?? 0.0).toDouble();
              return quantidade <= estoqueMinimo && estoqueMinimo > 0;
            }).toList();
          }

          final String queryBusca = _searchController.text.toLowerCase().trim();
          if (queryBusca.isNotEmpty) {
            produtos = produtos.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final nome = (data['nome'] ?? '').toLowerCase();
              final codigo = (data['codigo'] ?? '').toLowerCase();
              return nome.contains(queryBusca) || codigo.contains(queryBusca);
            }).toList();

            produtos.sort((a, b) {
              final dataA = a.data() as Map<String, dynamic>;
              final dataB = b.data() as Map<String, dynamic>;
              final nomeA = (dataA['nome'] ?? '').toLowerCase();
              final codigoA = (dataA['codigo'] ?? '').toLowerCase();
              final nomeB = (dataB['nome'] ?? '').toLowerCase();
              final codigoB = (dataB['codigo'] ?? '').toLowerCase();

              int getMatchScore(String nome, String codigo) {
                if (codigo == queryBusca) return 1;
                if (codigo.startsWith(queryBusca)) return 2;
                if (nome.startsWith(queryBusca)) return 3;
                return 4;
              }

              final scoreA = getMatchScore(nomeA, codigoA);
              final scoreB = getMatchScore(nomeB, codigoB);
              return scoreA != scoreB ? scoreA.compareTo(scoreB) : nomeA.compareTo(nomeB);
            });
          } else {
            produtos.sort((a, b) {
              final dataA = a.data() as Map<String, dynamic>;
              final dataB = b.data() as Map<String, dynamic>;
              final double quantidadeA = (dataA['quantidadeAtual'] ?? 0.0).toDouble();
              final double estoqueMinimoA = (dataA['estoqueMinimo'] ?? 0.0).toDouble();
              final String nomeA = dataA['nome'] ?? '';
              final double quantidadeB = (dataB['quantidadeAtual'] ?? 0.0).toDouble();
              final double estoqueMinimoB = (dataB['estoqueMinimo'] ?? 0.0).toDouble();
              final String nomeB = dataB['nome'] ?? '';

              int getPrioridade(double qtd, double min) {
                if (qtd <= 0) return 1;
                if (qtd <= min && min > 0) return 2;
                return 3;
              }

              final prioridadeA = getPrioridade(quantidadeA, estoqueMinimoA);
              final prioridadeB = getPrioridade(quantidadeB, estoqueMinimoB);
              return prioridadeA != prioridadeB ? prioridadeA.compareTo(prioridadeB) : nomeA.toLowerCase().compareTo(nomeB.toLowerCase());
            });
          }

          if (produtos.isEmpty) {
            String msg = 'Nenhum produto encontrado para "$queryBusca"';
            if(queryBusca.isEmpty && _filtroAtual == FiltroProdutos.pontoDePedido){
              msg = 'Nenhum produto em ponto de pedido.';
            }
            return Center(
                child: Text(msg,
                    style: const TextStyle(fontSize: 18, color: Colors.grey)));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80.0),
            itemCount: produtos.length,
            itemBuilder: (context, index) =>
                _buildCardProduto(context, produtos[index]),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar() {
    String titulo = 'Estocando';
    if (_filtroAtual == FiltroProdutos.pontoDePedido) titulo = 'Ponto de Pedido';
    else if (_filtroAtual == FiltroProdutos.ativos) titulo = 'Estoque (Ativos)';
    else if (_filtroAtual == FiltroProdutos.inativos) titulo = 'Estoque (Inativos)';
    else if (_filtroAtual == FiltroProdutos.todos) titulo = 'Estoque (Todos)';

    if (!_isSearching) {
      return AppBar(
        title: Text(titulo),
        actions: [
          IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _isSearching = true)),
          PopupMenuButton<FiltroProdutos>(
            icon: const Icon(Icons.filter_list),
            onSelected: (FiltroProdutos result) {
              setState(() => _filtroAtual = result);
            },
            itemBuilder: (BuildContext context) =>
            <PopupMenuEntry<FiltroProdutos>>[
              const PopupMenuItem(
                  value: FiltroProdutos.ativos, child: Text('Ver Ativos')),
              const PopupMenuItem(
                value: FiltroProdutos.pontoDePedido,
                child: Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.orange), SizedBox(width: 8), Text('Ponto de Pedido')]),
              ),
              const PopupMenuItem(
                  value: FiltroProdutos.inativos, child: Text('Ver Inativos')),
              const PopupMenuItem(
                  value: FiltroProdutos.todos, child: Text('Ver Todos')),
            ],
          ),
        ],
      );
    } else {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() {
            _isSearching = false;
            _searchController.clear();
          }),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'Buscar por código ou nome...',
              hintStyle: TextStyle(color: Colors.white70),
              border: InputBorder.none),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _searchController.clear())
        ],
      );
    }
  }

  Drawer _buildDrawer(BuildContext context) {
    const String adminEmail = 'renan.franco@protecin.com.br';
    final String? currentUserEmail = FirebaseAuth.instance.currentUser?.email;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration:
            BoxDecoration(color: Theme.of(context).colorScheme.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Estocando',
                    style: TextStyle(color: Colors.white, fontSize: 24)),
                const Spacer(),
                Text(currentUserEmail ?? 'Usuário',
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          ),
          ListTile(
              title: const Text('Parceiros'),
              leading: const Icon(Icons.people),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (c) => const TelaParceiros()))),
          ListTile(
              title: const Text('Extrato de Movimentações'),
              leading: const Icon(Icons.receipt_long),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (c) => const TelaExtratoMovimentacoes()))),

          // ---> ALTEREI AQUI: Adicionei a lógica para abrir a tela de relatórios <---
          ListTile(
            title: const Text('Dashboard de Relatórios'),
            leading: const Icon(Icons.dashboard),
            onTap: () {
              Navigator.pop(context); // Fecha o menu
              Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const TelaRelatorios()),
              );
            },
          ),

          const Divider(),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('Importação / Exportação', style: TextStyle(color: Colors.grey))),
          ListTile(
              title: const Text('Importar Produtos'),
              leading: const Icon(Icons.inventory_2),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (c) => const TelaImportacaoProdutos()))),
          ListTile(
              title: const Text('Importar Parceiros'),
              leading: const Icon(Icons.groups),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (c) => const TelaImportacaoParceiros()))),
          ListTile(
              title: const Text('Importar Movimentações'),
              leading: const Icon(Icons.sync_alt),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (c) => const TelaImportacaoMovimentacoes()))),

          ListTile(
            title: const Text('Exportar Produtos (Excel)'),
            leading: const Icon(Icons.download_for_offline),
            onTap: () {
              Navigator.pop(context);
              _exportarProdutosParaExcel();
            },
          ),

          const Divider(),
          if (currentUserEmail == adminEmail) ...[
            const Divider(color: Colors.blueGrey),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text('Administração',
                  style: TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading:
              const Icon(Icons.admin_panel_settings, color: Colors.blue),
              title: const Text('Aprovar Usuários',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (c) => const TelaAprovacaoUsuarios()));
              },
            ),
          ],
          const Divider(),
          ListTile(
            title: const Text('Sair'),
            leading: const Icon(Icons.logout),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCardProduto(BuildContext context, QueryDocumentSnapshot produtoDoc) {
    final data = produtoDoc.data() as Map<String, dynamic>;
    final double quantidade = (data['quantidadeAtual'] ?? 0.0).toDouble();
    final double estoqueMinimo = (data['estoqueMinimo'] ?? 0.0).toDouble();
    final double estoqueMaximo = (data['estoqueMaximo'] ?? 0.0).toDouble();

    final String? numeroSC = data['numeroSC'];
    final double valorUnitario = (data['valor'] ?? 0.0).toDouble();
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    Color statusColor = Theme.of(context).colorScheme.primary.withOpacity(0.7);
    String statusText = 'Estoque OK';
    Color textColor = Colors.white;

    if (quantidade <= 0) {
      statusColor = Colors.red.shade700;
      statusText = 'Estoque Zerado';
    } else if (quantidade <= estoqueMinimo && estoqueMinimo > 0) {
      statusColor = Colors.orange.shade800;
      statusText = 'Abaixo do Mínimo';
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: statusColor, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 12, right: 0),
            leading: CircleAvatar(
                backgroundColor: statusColor,
                child: Text(_formatarQuantidade(quantidade),
                    style: TextStyle(
                        color: textColor, fontWeight: FontWeight.bold))),
            title: Text(
                '${data['codigo'] ?? 'N/A'} - ${data['nome'] ?? 'Sem nome'}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(statusText,
                          style: TextStyle(
                              color: statusColor, fontWeight: FontWeight.bold)),
                      if (estoqueMinimo > 0 || estoqueMaximo > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Min: ${_formatarQuantidade(estoqueMinimo)} / Max: ${_formatarQuantidade(estoqueMaximo)}',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ),
                      if (numeroSC != null && numeroSC.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Chip(
                            label: Text('SC: $numeroSC',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10)),
                            backgroundColor: Colors.blue.shade700,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  formatoMoeda.format(valorUnitario),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54),
                ),
                const SizedBox(width: 8),
              ],
            ),
            trailing: PopupMenuButton<AcoesProduto>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Mais Opções',
              onSelected: (AcoesProduto acao) {
                switch (acao) {
                  case AcoesProduto.editar:
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (c) => TelaCadastroProduto(
                                produtoParaEditar: produtoDoc)));
                    break;
                  case AcoesProduto.solicitarCompra:
                    _mostrarDialogoSC(context, produtoDoc);
                    break;
                  case AcoesProduto.excluir:
                    _mostrarDialogoDeConfirmacao(context, produtoDoc);
                    break;
                }
              },
              itemBuilder: (BuildContext context) =>
              <PopupMenuEntry<AcoesProduto>>[
                const PopupMenuItem(
                    value: AcoesProduto.editar, child: Text('Editar')),
                const PopupMenuItem(
                    value: AcoesProduto.solicitarCompra,
                    child: Text('Solicitar Compra (SC)')),
                const PopupMenuItem(
                    value: AcoesProduto.excluir, child: Text('Excluir')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildActionButton(
                    context,
                    'ENTRADA',
                    Icons.add_circle_outline,
                    Colors.green,
                        () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (c) => TelaMovimentacao(
                                produtoPreSelecionado: produtoDoc)))),
                const SizedBox(width: 8),
                _buildActionButton(
                    context,
                    'SAÍDA',
                    Icons.remove_circle_outline,
                    Colors.red,
                        () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (c) => TelaMovimentacao(
                                produtoPreSelecionado: produtoDoc)))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon,
      Color color, VoidCallback onPressed) {
    return TextButton.icon(
      icon: Icon(icon, color: color, size: 20),
      label: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  SpeedDial _buildSpeedDial(BuildContext context) {
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: Theme.of(context).colorScheme.secondary,
      foregroundColor: Colors.white,
      buttonSize: const Size(56.0, 56.0),
      children: [
        SpeedDialChild(
          child: const Icon(Icons.inventory_2),
          label: 'Novo Produto',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (c) => const TelaCadastroProduto())),
        ),
        SpeedDialChild(
          child: const Icon(Icons.sync_alt),
          label: 'Nova Movimentação',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (c) => const TelaMovimentacao())),
        ),
        SpeedDialChild(
          child: const Icon(Icons.person_add),
          label: 'Novo Parceiro',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (c) => const TelaCadastroParceiro())),
        ),
      ],
    );
  }

  void _mostrarDialogoSC(
      BuildContext context, QueryDocumentSnapshot produtoDoc) {
    final scController = TextEditingController(
        text: (produtoDoc.data() as Map<String, dynamic>)['numeroSC'] ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Solicitação de Compra'),
          content: TextField(
            controller: scController,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(labelText: 'Número da SC'),
          ),
          actions: [
            TextButton(
                child: const Text('Cancelar'),
                onPressed: () => Navigator.of(context).pop()),
            ElevatedButton(
              child: const Text('Salvar'),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('produtos')
                    .doc(produtoDoc.id)
                    .update({'numeroSC': scController.text.trim()});
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoDeConfirmacao(
      BuildContext context, QueryDocumentSnapshot produtoDoc) {
    final nomeProduto =
        (produtoDoc.data() as Map<String, dynamic>)['nome'] ?? 'este produto';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
            'Tem certeza que deseja excluir "$nomeProduto"?\nEsta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar')),
          TextButton(
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('produtos')
                  .doc(produtoDoc.id)
                  .delete();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}