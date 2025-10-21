// Salve este arquivo como: telas/home_screen.dart (VERSÃO CORRIGIDA FINAL)

import 'package:estocando/telas/tela_criar_requisicao.dart';
import 'package:estocando/telas/tela_requisicoes_pendentes.dart';
import 'package:flutter/material.dart';

import 'package:estocando/telas/tela_lista_produtos.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Importamos o SpeedDial
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

// Imports para o Drawer e SpeedDial
import 'package:estocando/telas/tela_aprovacao_usuarios.dart';
import 'package:estocando/telas/tela_extrato_movimentacoes.dart';
import 'package:estocando/telas/tela_importacao_movimentacoes.dart';
import 'package:estocando/telas/tela_importacao_parceiros.dart';
import 'package:estocando/telas/tela_importacao_produtos.dart';
import 'package:estocando/telas/tela_parceiros.dart';
import 'package:estocando/telas/tela_historico.dart'; // TelaRelatorios
import 'package:estocando/telas/tela_gerenciar_movimentacoes.dart';
import 'package:estocando/telas/tela_cadastro_produto.dart';
import 'package:estocando/telas/tela_movimentacao.dart';
import 'package:estocando/telas/tela_cadastro_parceiro.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _buscaController = TextEditingController();

  String? _permissaoUsuario;
  String? _empresaId;
  bool _carregandoDadosIniciais = true;
  Map<String, dynamic>? _dadosUsuario;


  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
  }

  Future<void> _carregarDadosUsuario() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _carregandoDadosIniciais = false);
      return;
    }

    try {
      DocumentSnapshot userData = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();

      if (mounted && userData.exists) {
        final data = userData.data() as Map<String, dynamic>;
        setState(() {
          _dadosUsuario = data;
          _permissaoUsuario = data['permissao'];
          _empresaId = data['empresaId'];
          if (_permissaoUsuario == null || !['admin', 'almoxarife', 'producao'].contains(_permissaoUsuario)) {
            _permissaoUsuario = 'producao';
          }
          _carregandoDadosIniciais = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _permissaoUsuario = 'producao';
            _carregandoDadosIniciais = false;
          });
        }
      }
    } catch (e) {
      print("Erro ao carregar dados do usuário na Home: $e");
      if (mounted) {
        setState(() {
          _permissaoUsuario = 'producao';
          _carregandoDadosIniciais = false;
        });
      }
    }
  }


  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  // ---> ESTA É A FUNÇÃO QUE FAZ A BUSCA FUNCIONAR <---
  void _irParaListaDeProdutos(String? termoBuscado) {
    // Fecha o Drawer caso ele esteja aberto
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    // Navega para a tela da lista de produtos
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TelaListaProdutos(
          // Passa o termo de busca para a outra tela
          termoBuscaInicial: termoBuscado,
        ),
      ),
    );

    // Limpa o campo de busca aqui no Dashboard
    _buscaController.clear();
    FocusScope.of(context).unfocus();
  }

  void _irParaCriarRequisicao() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TelaCriarRequisicao()),
    );
  }

  void _irParaRequisicoesPendentes() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TelaRequisicoesPendentes()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lógica de permissão para os botões
    final bool isAdmin = _permissaoUsuario == 'admin';
    final bool isAlmoxarife = _permissaoUsuario == 'almoxarife';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Protecin Estocando'),
        centerTitle: true,
      ),
      drawer: _carregandoDadosIniciais
          ? const Drawer(child: Center(child: CircularProgressIndicator()))
          : _buildDrawer(),

      // Adicionamos o SpeedDial (botão '+') de volta
      floatingActionButton: _carregandoDadosIniciais || _permissaoUsuario == null
          ? null
          : _buildSpeedDial(context, _permissaoUsuario!),

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---> ESTE É O CAMPO DE BUSCA <---
            _buildCampoBusca(),
            const SizedBox(height: 32),

            Text(
              'Acesso Rápido',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Botão de Criar Requisição (Todos veem)
            _buildBotaoAcessoRapido(
              contexto: context,
              icone: Icons.add_shopping_cart,
              titulo: 'Criar Requisição',
              subtitulo: 'Solicitar material para a produção',
              cor: Colors.blueAccent,
              onPressed: _irParaCriarRequisicao,
            ),
            const SizedBox(height: 12),

            // Botão "Requisições Pendentes" (Ponto 3 corrigido)
            // Só aparece se for Admin ou Almoxarife
            if (isAdmin || isAlmoxarife)
              _buildBotaoAcessoRapido(
                contexto: context,
                icone: Icons.pending_actions,
                titulo: 'Requisições Pendentes',
                subtitulo: 'Aprovar ou reprovar pedidos',
                cor: Colors.orangeAccent,
                onPressed: _irParaRequisicoesPendentes,
              ),
          ],
        ),
      ),
    );
  }

  // ---> ESTA É A LÓGICA DO CAMPO DE BUSCA <---
  Widget _buildCampoBusca() {
    return TextFormField(
      controller: _buscaController,
      decoration: InputDecoration(
        hintText: 'Buscar por código ou nome...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        filled: true,
        fillColor: Colors.grey[100],
      ),
      // Ao apertar "Enter" (ou 'concluído') no teclado:
      onFieldSubmitted: (valor) {
        if (valor.trim().isNotEmpty) {
          // Ele chama a função que navega para a lista
          _irParaListaDeProdutos(valor.trim());
        }
      },
    );
  }

  Widget _buildBotaoAcessoRapido({
    required BuildContext contexto,
    required IconData icone,
    required String titulo,
    required String subtitulo,
    required Color cor,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icone, size: 40, color: cor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitulo,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {

    final String? permissao = _permissaoUsuario;
    final bool isAdmin = permissao == 'admin';
    final bool isAlmoxarife = permissao == 'almoxarife';
    final String? currentUserEmail = FirebaseAuth.instance.currentUser?.email;


    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Estocando', style: TextStyle(color: Colors.white, fontSize: 24)),
                const Spacer(),
                Text(currentUserEmail ?? 'Usuário', style: const TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          ),

          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Início (Dashboard)'),
            onTap: () {
              Navigator.of(context).pop(); // Fecha o drawer
            },
          ),

          ListTile(
            leading: const Icon(Icons.inventory_2),
            title: const Text('Lista de Produtos'),
            onTap: () => _irParaListaDeProdutos(null), // Vai para a lista sem filtro
          ),

          if (isAdmin || isAlmoxarife) ...[
            ListTile(
                title: const Text('Parceiros'),
                leading: const Icon(Icons.people),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const TelaParceiros()));
                }
            ),
            ListTile(
                title: const Text('Extrato de Movimentações'),
                leading: const Icon(Icons.receipt_long),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const TelaExtratoMovimentacoes()));
                }
            ),
            ListTile(
              title: const Text('Dashboard de Relatórios'),
              leading: const Icon(Icons.dashboard),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (c) => const TelaRelatorios()));
              },
            ),
          ],

          if (isAdmin) ...[
            const Divider(),
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Importação', style: TextStyle(color: Colors.grey))
            ),
            ListTile(
                title: const Text('Importar Produtos'),
                leading: const Icon(Icons.inventory_2),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const TelaImportacaoProdutos()));
                }
            ),
            ListTile(
                title: const Text('Importar Parceiros'),
                leading: const Icon(Icons.groups),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const TelaImportacaoParceiros()));
                }
            ),
            ListTile(
                title: const Text('Importar Movimentações'),
                leading: const Icon(Icons.sync_alt),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const TelaImportacaoMovimentacoes()));
                }
            ),
          ],

          if (isAdmin || isAlmoxarife) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text('Administração', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
            if (isAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.blue),
                title: const Text('Aprovar Usuários', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const TelaAprovacaoUsuarios()));
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit_note, color: Colors.blue),
              title: const Text('Gerenciar Movimentações', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (c) => const TelaGerenciarMovimentacoes()));
              },
            ),
          ],

          const Divider(),
          ListTile(
            leading: const Icon(Icons.add_shopping_cart),
            title: const Text('Criar Requisição'),
            onTap: () {
              Navigator.of(context).pop();
              _irParaCriarRequisicao();
            },
          ),

          // "Requisições Pendentes" no Drawer (Ponto 3 corrigido)
          if (isAdmin || isAlmoxarife)
            ListTile(
              leading: const Icon(Icons.pending_actions),
              title: const Text('Requisições Pendentes'),
              onTap: () {
                Navigator.of(context).pop();
                _irParaRequisicoesPendentes();
              },
            ),

          const Divider(),
          ListTile(
            title: const Text('Sair'),
            leading: const Icon(Icons.logout),
            onTap: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
    );
  }

  // Esta é a função _buildSpeedDial (Ponto 2 corrigido)
  SpeedDial _buildSpeedDial(BuildContext context, String permissao) {
    List<SpeedDialChild> children = [];

    // Perfil Produção (e Admin) pode criar requisição
    if (permissao == 'producao' || permissao == 'admin') {
      children.add(
          SpeedDialChild(
            child: const Icon(Icons.shopping_basket, color: Colors.white),
            label: 'Nova Requisição',
            backgroundColor: Colors.blueAccent,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const TelaCriarRequisicao())),
          )
      );
    }

    // Perfil Almoxarife (e Admin) pode cadastrar
    if (permissao == 'admin' || permissao == 'almoxarife') {
      children.addAll([
        SpeedDialChild(
          child: const Icon(Icons.inventory_2),
          label: 'Novo Produto',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const TelaCadastroProduto())),
        ),
        SpeedDialChild(
          child: const Icon(Icons.sync_alt),
          label: 'Nova Movimentação',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const TelaMovimentacao())),
        ),
        SpeedDialChild(
          child: const Icon(Icons.person_add),
          label: 'Novo Parceiro',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const TelaCadastroParceiro())),
        ),
      ]);
    }

    children.sort((a, b) => a.label!.compareTo(b.label!));

    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: Theme.of(context).colorScheme.secondary, // Vermelho Protecin
      foregroundColor: Colors.white,
      buttonSize: const Size(56.0, 56.0),
      visible: children.isNotEmpty,
      children: children,
    );
  }
}