// Salve como: lib/home_screen.dart
// (VERSÃO v3.0 - Com Auto-Start da Impressora Argox)

import 'package:protecin_producao/telas/estoque/tela_criar_requisicao.dart';
import 'package:protecin_producao/telas/estoque/tela_requisicoes_pendentes.dart';
import 'package:flutter/material.dart';
import 'package:protecin_producao/telas/estoque/tela_lista_produtos.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:protecin_producao/provider/produto_provider.dart';
import 'package:protecin_producao/telas/producao/tela_lista_os.dart';
// Import Tela de Controle de Pó (Nova)
import 'package:protecin_producao/telas/estoque/tela_controle_lotes.dart';
// Imports Admin/Estoque
import 'package:protecin_producao/telas/admin/tela_aprovacao_usuarios.dart';
import 'package:protecin_producao/telas/estoque/tela_extrato_movimentacoes.dart';
import 'package:protecin_producao/telas/admin/tela_parceiros.dart';
import 'package:protecin_producao/telas/estoque/tela_historico.dart';
import 'package:protecin_producao/telas/estoque/tela_cadastro_produto.dart';
import 'package:protecin_producao/telas/estoque/tela_movimentacao.dart';
import 'package:protecin_producao/telas/admin/tela_cadastro_parceiro.dart';
// Imports Produção (Fluxo Completo)
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_descarga.dart';
import 'package:protecin_producao/telas/producao/tela_criar_os.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_limpeza.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_lixa.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_pintura.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_saque.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_manutencao.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_valvula_po.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_th.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_recarga.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_estanqueidade.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_premontagem.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_montagem.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_expedicao.dart';
// Import Gerenciar Extintores
import 'package:protecin_producao/telas/producao/tela_consulta_equipamentos.dart';
// --- IMPORTS PARA A IMPRESSORA (WINDOWS) ---
import 'package:protecin_producao/telas/windows/tela_servidor_impressao.dart'; // Tela Manual
// OBS: Verifique se o arquivo do Monitor está nessa pasta 'services' ou ajuste aqui:
import 'package:protecin_producao/services/monitor_impressao_windows.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/repositories/requisicao_repository.dart';
// -------------------------------------------
import 'dart:io';
import 'package:flutter/foundation.dart'; // Para kIsWeb
import 'package:universal_html/html.dart' as html;
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _buscaController = TextEditingController();

  // Variável para manter o Monitor vivo em memória
  MonitorImpressaoWindows? _monitorWindows;

  final Color _corPrincipal = const Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    // Inicia a escuta do dashboard pelo provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final usuario = context.read<UsuarioProvider>().usuario;
      context.read<ItemOsProvider>().iniciarEscuta(usuario?.empresaId ?? '');
    });

    if (!kIsWeb && Platform.isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _iniciarMonitorEmSegundoPlano();
      });
    }
    // ---------------------------------------------
  }

  // Lógica para ligar o Monitor sozinho
  void _iniciarMonitorEmSegundoPlano() {
    try {
      // Cria a instância do Monitor (Mesma lógica da tela manual)
      _monitorWindows = MonitorImpressaoWindows(
        nomeImpressora: "Argox01",
        // Nome da FILA que o site manda (O monitor converte pra real internamente)
        onLog: (msg) {
          // Aqui podemos optar por não mostrar nada, ou apenas erros graves no console
          if (kDebugMode) print("Monitor Background: $msg");
        },
      );

      _monitorWindows!.iniciar();

      // Avisa o usuário que o sistema de impressão está ON
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.print, color: Colors.white),
              SizedBox(width: 10),
              Text("Servidor de Impressão Argox: ONLINE 🟢"),
            ],
          ),
          backgroundColor: Colors.green[800],
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint("Erro ao iniciar monitor background: $e");
    }
  }

  @override
  void dispose() {
    // Se sair da Home (Logout), paramos o monitor para não dar erro
    _monitorWindows?.parar();
    _buscaController.dispose();
    super.dispose();
  }


  // --- NAVEGAÇÃO ---
  void _irParaListaDeProdutos(String? termoBuscado) {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    Navigator.push(context, MaterialPageRoute(builder: (context) =>
        TelaListaProdutos(termoBuscaInicial: termoBuscado)));
    _buscaController.clear();
    FocusScope.of(context).unfocus();
  }

  void _irParaCriarRequisicao() =>
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const TelaCriarRequisicao()));

  void _irParaRequisicoesPendentes() =>
      Navigator.push(context, MaterialPageRoute(
          builder: (context) => const TelaRequisicoesPendentes()));

  void _irParaNovaMovimentacao() =>
      Navigator.push(
          context, MaterialPageRoute(builder: (c) => const TelaMovimentacao()));

  void _irParaNovoProduto() =>
      Navigator.push(context,
          MaterialPageRoute(builder: (c) => const TelaCadastroProduto()));

  void _irParaNovoParceiro() =>
      Navigator.push(context,
          MaterialPageRoute(builder: (c) => const TelaCadastroParceiro()));

  // DEPOIS
  Future<void> _exportarProdutosParaExcel() async {
    try {
      final usuario = context.read<UsuarioProvider>().usuario;
      if (usuario == null) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Gerando relatório...'), backgroundColor: Colors.blue));
      final produtos = await context
          .read<ProdutoProvider>()
          .buscarTodosPorEmpresa(usuario.empresaId);
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Produtos'];
      List<String> headers = [
        'Código',
        'Nome',
        'Qtd',
        'Mín',
        'Máx',
        'Valor',
        'SC',
        'Ativo'
      ];
      sheetObject.appendRow(
          headers.map((header) => TextCellValue(header)).toList());
      for (var data in produtos) {
        sheetObject.appendRow([
          TextCellValue(data['codigo'] ?? ''),
          TextCellValue(data['nome'] ?? ''),
          DoubleCellValue((data['quantidadeAtual'] ?? 0.0).toDouble()),
          DoubleCellValue((data['estoqueMinimo'] ?? 0.0).toDouble()),
          DoubleCellValue((data['estoqueMaximo'] ?? 0.0).toDouble()),
          DoubleCellValue((data['valor'] ?? 0.0).toDouble()),
          TextCellValue(data['numeroSC'] ?? ''),
          TextCellValue(data['ativo'] == true ? 'Sim' : 'Não'),
        ]);
      }
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Estocando_Produtos_$timestamp.xlsx';
      var fileBytes = excel.save();
      if (kIsWeb) {
        if (fileBytes != null) {
          final blob = html.Blob([fileBytes],
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
          final url = html.Url.createObjectUrlFromBlob(blob);
          html.AnchorElement(href: url)
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
          await Share.shareXFiles(
              [XFile(filePath)], text: 'Relatório de Produtos');
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<UsuarioProvider>().usuario;
    final String permissao = usuario?.permissao ?? 'producao';
    final bool isAdmin = permissao == 'admin';
    final bool isAlmoxarife = permissao == 'almoxarife';
    final bool isProducao = permissao == 'producao';
    final contadores = context.watch<ItemOsProvider>().contadores;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Protecin Produção'),
        centerTitle: true,
        backgroundColor: _corPrincipal,
        foregroundColor: Colors.white,
        elevation: 0,
        // --- BOTÃO DA IMPRESSORA NA BARRA SUPERIOR ---
        actions: [
          if (!kIsWeb && Platform.isWindows)
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: "Status da Impressora",
              onPressed: () {
                // Abre a tela manual para ver logs ou configurar
                Navigator.push(context, MaterialPageRoute(
                    builder: (c) => const TelaServidorImpressao()));
              },
            ),
        ],
        // ---------------------------------------------
      ),
      drawer: context.watch<UsuarioProvider>().isLoading
          ? const Drawer(child: Center(child: CircularProgressIndicator()))
          : _buildDrawer(),
      backgroundColor: Colors.grey[100],

      body: context.watch<UsuarioProvider>().isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. BUSCA E DASHBOARD
            _buildCampoBusca(),
            const SizedBox(height: 20),

            const Text('Status da Produção', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildDashCard('Descarga', contadores['descarga'] ?? 0, Colors.orange),
                  _buildDashCard('Limpeza', contadores['limpeza'] ?? 0, Colors.blue),
                  _buildDashCard('Lixa', contadores['lixa'] ?? 0, Colors.blueGrey),
                  _buildDashCard('Manut. Válv', contadores['manutencao'] ?? 0, Colors.teal),
                  _buildDashCard('Saque Válv.', contadores['saque'] ?? 0, Colors.red),
                  _buildDashCard('T. Hidro', contadores['teste'] ?? 0, Colors.purple),
                  _buildDashCard('Pintura', contadores['pintura'] ?? 0, Colors.brown),
                  _buildDashCard('Válv. Pó', contadores['valvulaPo'] ?? 0, Colors.deepOrange),
                  _buildDashCard('Recarga', contadores['recarga'] ?? 0, Colors.green),
                  _buildDashCard('Estanq.', contadores['estanqueidade'] ?? 0, Colors.lightBlue),
                  _buildDashCard('Pré-Mont.', contadores['premontagem'] ?? 0, Colors.indigo),
                  _buildDashCard('Montagem', contadores['montagem'] ?? 0, Colors.deepPurple),
                  _buildDashCard('Expedição', contadores['expedicao'] ?? 0, Colors.black87),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Text('Estações', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),

            // 2. BOTÕES DAS ESTAÇÕES
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.start,
              children: [
                _buildSquareButton(
                  icon: Icons.download,
                  label: 'Descarga',
                  color: Colors.orange[800]!,
                  count: contadores['descarga'] ?? 0,
                  onTap: () => _mostrarOpcoesDescarga(context, contadores),
                ),
                _buildSquareButton(
                  icon: Icons.cleaning_services,
                  label: 'Limpeza',
                  color: Colors.blue[800]!,
                  count: contadores['limpeza'] ?? 0,
                  onTap: () =>
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const TelaListaLotesLimpeza())),
                ),
                _buildSquareButton(
                  icon: Icons.build,
                  label: 'Lixa',
                  color: Colors.blueGrey[700]!,
                  count: contadores['lixa'] ?? 0,
                  onTap: () =>
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const TelaListaLotesLixa())),
                ),
                _buildSquareButton(
                  icon: Icons.handyman,
                  label: 'Manut. Válv',
                  color: Colors.teal[700]!,
                  count: contadores['manutencao'] ?? 0,
                  onTap: () =>
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const TelaListaLotesManutencao())),
                ),
                _buildSquareButton(
                  icon: Icons.settings_backup_restore,
                  label: 'Saque Válv.',
                  color: Colors.red[700]!,
                  count: contadores['saque'] ?? 0,
                  onTap: () =>
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const TelaListaLotesSaque())),
                ),
                _buildSquareButton(
                  icon: Icons.science,
                  label: 'T. Hidro',
                  color: Colors.purple[700]!,
                  count: contadores['teste'] ?? 0,
                  onTap: () =>
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const TelaListaLotesTH())),
                ),
                _buildSquareButton(
                  icon: Icons.format_paint,
                  label: 'Pintura',
                  color: Colors.brown[700]!,
                  count: contadores['pintura'] ?? 0,
                  onTap: () =>
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const TelaListaLotesPintura())),
                ),
                _buildSquareButton(
                  icon: Icons.handyman,
                  label: 'Válv. Pó',
                  color: Colors.deepOrange[700]!,
                  count: contadores['valvulaPo'] ?? 0,
                  onTap: () =>
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const TelaListaLotesValvulaPo())),
                ),
                _buildSquareButton(
                  icon: Icons.compress,
                  label: 'Recarga',
                  color: Colors.green[700]!,
                  count: contadores['recarga'] ?? 0,
                  onTap: () => _mostrarOpcoesRecarga(context, contadores),
                ),
                _buildSquareButton(
                  icon: Icons.water,
                  label: 'Estanq.',
                  color: Colors.lightBlue[800]!,
                  count: contadores['estanqueidade'] ?? 0,
                  onTap: () => _mostrarOpcoesEstanqueidade(context, contadores),
                ),
                _buildSquareButton(
                  icon: Icons.group_work,
                  label: 'Pré-Mont.',
                  color: Colors.indigo[700]!,
                  count: contadores['premontagem'] ?? 0,
                  onTap: () =>
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const TelaListaLotesPremontagem())),
                ),
                _buildSquareButton(
                  icon: Icons.verified,
                  label: 'Montagem',
                  color: Colors.deepPurple[700]!,
                  count: contadores['montagem'] ?? 0,
                  onTap: () =>
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const TelaListaLotesMontagem())),
                ),
                _buildSquareButton(
                  icon: Icons.local_shipping,
                  label: 'Expedição',
                  color: Colors.black87,
                  count: contadores['expedicao'] ?? 0,
                  onTap: () =>
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const TelaListaLotesExpedicao())),
                ),
              ],
            ),

            const SizedBox(height: 25),
            const Divider(thickness: 1),
            const SizedBox(height: 10),

            // 3. ÁREA DE ALMOXARIFADO
            if (isProducao || isAdmin || isAlmoxarife) ...[
              const Text('Acesso Rápido', style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
              const SizedBox(height: 10),

              _buildBotaoAcessoRapido(
                icone: Icons.add_shopping_cart,
                titulo: 'Criar Requisição',
                subtitulo: 'Solicitar material',
                cor: Colors.blueAccent,
                onPressed: _irParaCriarRequisicao,
              ),
            ],

            if (isAdmin || isAlmoxarife) ...[
              const SizedBox(height: 5),
              StreamBuilder<bool>(
                stream: context
                    .read<RequisicaoRepository>()
                    .streamTemPendentes(usuario?.empresaId ?? ''),
                builder: (context, snapshot) {
                  final bool temPendentes = snapshot.data ?? false;
                  return _buildBotaoAcessoRapido(
                    icone: Icons.pending_actions,
                    titulo: 'Requisições',
                    subtitulo: 'Aprovar solicitações',
                    cor: Colors.orangeAccent[700]!,
                    onPressed: _irParaRequisicoesPendentes,
                    showBadge: temPendentes,
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text('Cadastros', style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
              const SizedBox(height: 10),
              _buildBotaoAcessoRapido(
                icone: Icons.sync_alt,
                titulo: 'Movimentação',
                subtitulo: 'Entrada/Saída Manual',
                cor: Colors.green.shade600,
                onPressed: _irParaNovaMovimentacao,
              ),
              const SizedBox(height: 5),
              _buildBotaoAcessoRapido(
                icone: Icons.inventory_2,
                titulo: 'Novo Produto',
                subtitulo: 'Cadastrar item',
                cor: Colors.purple.shade400,
                onPressed: _irParaNovoProduto,
              ),
              const SizedBox(height: 5),
              _buildBotaoAcessoRapido(
                icone: Icons.person_add,
                titulo: 'Novo Parceiro',
                subtitulo: 'Cliente/Fornecedor',
                cor: Colors.teal.shade400,
                onPressed: _irParaNovoParceiro,
              ),
            ],
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TelaCriarOS())),
        label: const Text('Nova OS'),
        icon: const Icon(Icons.add_box),
        backgroundColor: _corPrincipal,
        foregroundColor: Colors.white,
      ),
    );
  }

  // --- MÉTODOS AUXILIARES (IGUAIS AO ANTERIOR) ---
  void _mostrarOpcoesDescarga(BuildContext context, Map<String, int> contadores) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 350,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Selecione o Agente:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.ac_unit, color: Colors.brown),
                title: const Text("Pó Químico (PQS ABC)"),
                trailing: (contadores['descargaABC'] ?? 0) > 0 ? Badge(label: Text('${contadores['descargaABC']}')) : null,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) =>
                  const TelaEstacaoDescarga(tituloEstacao: 'Descarga PQS ABC',
                      filtrosAgente: ['ABC', 'PQS', 'PO'])));
                },
              ),
              ListTile(
                leading: const Icon(Icons.ac_unit, color: Colors.grey),
                title: const Text("Pó Químico (PQS BC)"),
                trailing: (contadores['descargaBC'] ?? 0) > 0 ? Badge(label: Text('${contadores['descargaBC']}')) : null,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) =>
                  const TelaEstacaoDescarga(tituloEstacao: 'Descarga PQS BC',
                      filtrosAgente: ['BC', 'PQS', 'PO'])));
                },
              ),
              ListTile(
                leading: const Icon(Icons.water_drop, color: Colors.blue),
                title: const Text("Água / Espuma"),
                trailing: (contadores['descargaAgua'] ?? 0) > 0 ? Badge(label: Text('${contadores['descargaAgua']}')) : null,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) =>
                  const TelaEstacaoDescarga(
                      tituloEstacao: 'Descarga Água/Espuma',
                      filtrosAgente: ['AP', 'ESP', 'AGUA'])));
                },
              ),
              ListTile(
                leading: const Icon(Icons.air, color: Colors.black),
                title: const Text("CO2"),
                trailing: (contadores['descargaCO2'] ?? 0) > 0 ? Badge(label: Text('${contadores['descargaCO2']}')) : null,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) =>
                  const TelaEstacaoDescarga(tituloEstacao: 'Descarga CO2',
                      filtrosAgente: ['CO2'])));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarOpcoesRecarga(BuildContext context, Map<String, int> contadores) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 350,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Selecione a Bancada:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.ac_unit, color: Colors.brown),
                title: const Text("Pó Químico (PQS ABC)"),
                trailing: (contadores['recargaABC'] ?? 0) > 0 ? Badge(label: Text('${contadores['recargaABC']}')) : null,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) =>
                  const TelaListaLotesRecarga(
                    titulo: 'Recarga PQS ABC',
                    filtrosAgente: ['ABC', 'PQS'],
                  )));
                },
              ),
              ListTile(
                leading: const Icon(Icons.ac_unit, color: Colors.grey),
                title: const Text("Pó Químico (PQS BC)"),
                trailing: (contadores['recargaBC'] ?? 0) > 0 ? Badge(label: Text('${contadores['recargaBC']}')) : null,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) =>
                  const TelaListaLotesRecarga(
                    titulo: 'Recarga PQS BC',
                    filtrosAgente: ['BC', 'PQS'],
                  )));
                },
              ),
              ListTile(
                leading: const Icon(Icons.water_drop, color: Colors.blue),
                title: const Text("Água / Espuma"),
                trailing: (contadores['recargaAgua'] ?? 0) > 0 ? Badge(label: Text('${contadores['recargaAgua']}')) : null,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) =>
                  const TelaListaLotesRecarga(
                    titulo: 'Recarga Água/Espuma',
                    filtrosAgente: ['AP', 'ESP', 'AGUA'],
                  )));
                },
              ),
              ListTile(
                leading: const Icon(Icons.air, color: Colors.black),
                title: const Text("CO2"),
                trailing: (contadores['recargaCO2'] ?? 0) > 0 ? Badge(label: Text('${contadores['recargaCO2']}')) : null,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) =>
                  const TelaListaLotesRecarga(
                    titulo: 'Recarga CO2',
                    filtrosAgente: ['CO2'],
                  )));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarOpcoesEstanqueidade(BuildContext context, Map<String, int> contadores) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 350,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Selecione o Tanque:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.ac_unit, color: Colors.brown),
                title: const Text("Pó Químico (PQS ABC)"),
                trailing: (contadores['estanqueABC'] ?? 0) > 0 ? Badge(label: Text('${contadores['estanqueABC']}')) : null,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) =>
                  const TelaListaLotesEstanqueidade(
                    titulo: 'Estanqueidade PQS ABC',
                    filtrosAgente: ['ABC', 'PQS'],
                  )));
                },
              ),
              ListTile(
                leading: const Icon(Icons.ac_unit, color: Colors.grey),
                title: const Text("Pó Químico (PQS BC)"),
                trailing: (contadores['estanqueBC'] ?? 0) > 0 ? Badge(label: Text('${contadores['estanqueBC']}')) : null,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) =>
                  const TelaListaLotesEstanqueidade(
                    titulo: 'Estanqueidade PQS BC',
                    filtrosAgente: ['BC', 'PQS'],
                  )));
                },
              ),
              ListTile(
                leading: const Icon(Icons.water_drop, color: Colors.blue),
                title: const Text("Água / Espuma"),
                trailing: (contadores['estanqueAgua'] ?? 0) > 0 ? Badge(label: Text('${contadores['estanqueAgua']}')) : null,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) =>
                  const TelaListaLotesEstanqueidade(
                    titulo: 'Estanqueidade Água/Espuma',
                    filtrosAgente: ['AP', 'ESP', 'AGUA'],
                  )));
                },
              ),
              ListTile(
                leading: const Icon(Icons.air, color: Colors.black),
                title: const Text("CO2"),
                trailing: (contadores['estanqueCO2'] ?? 0) > 0 ? Badge(label: Text('${contadores['estanqueCO2']}')) : null,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) =>
                  const TelaListaLotesEstanqueidade(
                    titulo: 'Estanqueidade CO2',
                    filtrosAgente: ['CO2'],
                  )));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCampoBusca() {
    return TextFormField(
      controller: _buscaController,
      decoration: InputDecoration(
        hintText: 'Buscar produto...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
      ),
      onFieldSubmitted: (valor) {
        if (valor
            .trim()
            .isNotEmpty) _irParaListaDeProdutos(valor.trim());
      },
    );
  }

  Widget _buildDashCard(String title, int count, Color color) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(right: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 3)),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(count.toString(), style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(title,
                style: const TextStyle(fontSize: 11, color: Colors.black87),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildSquareButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    int count = 0,
  }) {
    return SizedBox(
      width: 100,
      height: 90,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: 100,
            height: 90,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: color,
                elevation: 1,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(5),
              ),
              onPressed: onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 28, color: color),
                  const SizedBox(height: 5),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ],
              ),
            ),
          ),
          // Badge vermelho — só aparece quando tem itens aguardando
          if (count > 0)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 3,
                        offset: const Offset(0, 1))
                  ],
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBotaoAcessoRapido(
      {required IconData icone, required String titulo, required String subtitulo, required Color cor, required VoidCallback onPressed, bool showBadge = false}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icone, size: 24, color: cor),
                  if (showBadge)
                    Positioned(top: -2,
                        right: -2,
                        child: Container(width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: Colors.red, shape: BoxShape.circle))),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(titulo, style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(subtitulo,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
              ),
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final usuario = context.read<UsuarioProvider>().usuario;
    final String permissao = usuario?.permissao ?? 'producao';
    final bool isAdmin = permissao == 'admin';
    final bool isAlmoxarife = permissao == 'almoxarife';
    final String? currentUserEmail = FirebaseAuth.instance.currentUser?.email;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: _corPrincipal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Protecin Produção',
                    style: TextStyle(color: Colors.white, fontSize: 24)),
                const Spacer(),
                Text(currentUserEmail ?? 'Usuário',
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          ),
          ListTile(leading: const Icon(Icons.home),
              title: const Text('Início'),
              onTap: () => Navigator.of(context).pop()),
          ListTile(leading: const Icon(Icons.inventory_2),
              title: const Text('Lista de Produtos'),
              onTap: () => _irParaListaDeProdutos(null)),
          ListTile(leading: const Icon(Icons.fire_extinguisher),
              title: const Text('Gerenciar Extintores'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (c) => const TelaConsultaEquipamentos()));
              }),
          ListTile(leading: const Icon(Icons.assignment),
              title: const Text('Lista de OS'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (c) => const TelaListaOS()));
              }),

          ListTile(
              leading: const Icon(Icons.science),
              title: const Text('Controle Lotes de Pó'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (c) => const TelaControleLotesPo()));
              }
          ),

          if (isAdmin || isAlmoxarife) ...[
            const Divider(),
            const Padding(padding: EdgeInsets.only(left: 16, top: 8),
                child: Text("Gestão",
                    style: TextStyle(color: Colors.grey, fontSize: 12))),
            ListTile(leading: const Icon(Icons.people),
                title: const Text('Parceiros'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (c) => const TelaParceiros()));
                }),
            ListTile(leading: const Icon(Icons.receipt_long),
                title: const Text('Extrato Movimentações'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (c) => const TelaExtratoMovimentacoes()));
                }),
            ListTile(leading: const Icon(Icons.dashboard),
                title: const Text('Relatórios'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (c) => const TelaRelatorios()));
                }),
            ListTile(leading: const Icon(Icons.file_download),
                title: const Text('Exportar Produtos (Excel)'),
                onTap: () {
                  Navigator.pop(context);
                  _exportarProdutosParaExcel();
                }),
          ],
          if (isAdmin) ...[
            const Divider(),
            ListTile(leading: const Icon(Icons.admin_panel_settings),
                title: const Text('Aprovar Usuários'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (c) => const TelaAprovacaoUsuarios()));
                }),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sair'),
            onTap: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
    );
  }
}