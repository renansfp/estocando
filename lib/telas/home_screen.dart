// Salve como: lib/home_screen.dart
// (VERSÃO v4.0 - Home Adaptativa por Perfil)

import 'package:protecin_producao/telas/estoque/tela_criar_requisicao.dart';
import 'package:protecin_producao/telas/estoque/tela_requisicoes_pendentes.dart';
import 'package:flutter/material.dart';
import 'package:protecin_producao/telas/estoque/tela_lista_produtos.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:protecin_producao/provider/produto_provider.dart';
import 'package:protecin_producao/telas/producao/tela_lista_os.dart';
import 'package:protecin_producao/telas/admin/tela_gestao_acesso.dart';
import 'package:protecin_producao/telas/estoque/tela_controle_lotes.dart';
import 'package:protecin_producao/telas/admin/tela_aprovacao_usuarios.dart';
import 'package:protecin_producao/telas/estoque/tela_extrato_movimentacoes.dart';
import 'package:protecin_producao/telas/admin/tela_parceiros.dart';
import 'package:protecin_producao/telas/estoque/tela_historico.dart';
import 'package:protecin_producao/telas/estoque/tela_cadastro_produto.dart';
import 'package:protecin_producao/telas/estoque/tela_movimentacao.dart';
import 'package:protecin_producao/telas/admin/tela_cadastro_parceiro.dart';
import 'package:protecin_producao/telas/producao/tela_criar_os.dart';
import 'package:protecin_producao/telas/producao/tela_scanner_cracha.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_limpeza.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_lixa.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_pintura.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_saque.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_manutencao.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_valvula_po.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_th.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_selecao_descarga.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_selecao_recarga.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_selecao_estanqueidade.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_premontagem.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_montagem.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_expedicao.dart';
import 'package:protecin_producao/telas/producao/tela_consulta_equipamentos.dart';
import 'package:protecin_producao/telas/windows/tela_servidor_impressao.dart';
import 'package:protecin_producao/services/monitor_impressao_windows.dart';
import 'package:protecin_producao/models/usuario.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/repositories/requisicao_repository.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:universal_html/html.dart' as html;
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// ── CONFIG DE CADA ESTAÇÃO ────────────────────────────────────────────────
// Centraliza ícone, cor, chave do contador e tela destino de cada estação.
// A home usa essa lista para montar os botões filtrando por permissão.

class _EstacaoConfig {
  final String chave;           // Chave em EstacaoProducao
  final String label;
  final IconData icone;
  final Color cor;
  final String chaveContador;
  final Widget Function() tela;

  const _EstacaoConfig({
    required this.chave,
    required this.label,
    required this.icone,
    required this.cor,
    required this.chaveContador,
    required this.tela,
  });
}

final _estacoes = <_EstacaoConfig>[
  _EstacaoConfig(chave: EstacaoProducao.descarga,    label: 'Descarga',    icone: Icons.download,                cor: Colors.orange[800]!,    chaveContador: 'descarga',    tela: () => const TelaSelecaoDescarga()),
  _EstacaoConfig(chave: EstacaoProducao.limpeza,     label: 'Limpeza',     icone: Icons.cleaning_services,       cor: Colors.blue[800]!,      chaveContador: 'limpeza',     tela: () => const TelaListaLotesLimpeza()),
  _EstacaoConfig(chave: EstacaoProducao.lixa,        label: 'Lixa',        icone: Icons.build,                   cor: Colors.blueGrey[700]!,  chaveContador: 'lixa',        tela: () => const TelaListaLotesLixa()),
  _EstacaoConfig(chave: EstacaoProducao.manutencao,  label: 'Manut. Válv', icone: Icons.handyman,                cor: Colors.teal[700]!,      chaveContador: 'manutencao',  tela: () => const TelaListaLotesManutencao()),
  _EstacaoConfig(chave: EstacaoProducao.saque,       label: 'Saque Válv.', icone: Icons.settings_backup_restore, cor: Colors.red[700]!,       chaveContador: 'saque',       tela: () => const TelaListaLotesSaque()),
  _EstacaoConfig(chave: EstacaoProducao.th,          label: 'T. Hidro',    icone: Icons.science,                 cor: Colors.purple[700]!,    chaveContador: 'teste',       tela: () => const TelaListaLotesTH()),
  _EstacaoConfig(chave: EstacaoProducao.pintura,     label: 'Pintura',     icone: Icons.format_paint,            cor: Colors.brown[700]!,     chaveContador: 'pintura',     tela: () => const TelaListaLotesPintura()),
  _EstacaoConfig(chave: EstacaoProducao.valvulaPo,   label: 'Válv. Pó',   icone: Icons.handyman,                cor: Colors.deepOrange[700]!,chaveContador: 'valvulaPo',   tela: () => const TelaListaLotesValvulaPo()),
  _EstacaoConfig(chave: EstacaoProducao.recarga,     label: 'Recarga',     icone: Icons.compress,                cor: Colors.green[700]!,     chaveContador: 'recarga',     tela: () => const TelaSelecaoRecarga()),
  _EstacaoConfig(chave: EstacaoProducao.estanqueidade,label:'Estanq.',     icone: Icons.water,                   cor: Colors.lightBlue[800]!, chaveContador: 'estanqueidade',tela: () => const TelaSelecaoEstanqueidade()),
  _EstacaoConfig(chave: EstacaoProducao.premontagem, label: 'Pré-Mont.',   icone: Icons.group_work,              cor: Colors.indigo[700]!,    chaveContador: 'premontagem', tela: () => const TelaListaLotesPremontagem()),
  _EstacaoConfig(chave: EstacaoProducao.montagem,    label: 'Montagem',    icone: Icons.verified,                cor: Colors.deepPurple[700]!,chaveContador: 'montagem',    tela: () => const TelaListaLotesMontagem()),
  _EstacaoConfig(chave: EstacaoProducao.expedicao,   label: 'Expedição',   icone: Icons.local_shipping,          cor: Colors.black87,         chaveContador: 'expedicao',   tela: () => const TelaListaLotesExpedicao()),
];

// ─────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _buscaController = TextEditingController();
  MonitorImpressaoWindows? _monitorWindows;
  final Color _corPrincipal = const Color(0xFF1565C0);
  String? _empresaIdEscutando; // ← novo

  @override
  void initState() {
    super.initState();
    // Monitor de impressão continua aqui (não depende do usuário)
    if (!kIsWeb && Platform.isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _iniciarMonitorEmSegundoPlano();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final empresaId = context.watch<UsuarioProvider>().usuario?.empresaId;
    if (empresaId != null && empresaId.isNotEmpty && empresaId != _empresaIdEscutando) {
      _empresaIdEscutando = empresaId;
      context.read<ItemOsProvider>().iniciarEscuta(empresaId);
    }
  }

  void _iniciarMonitorEmSegundoPlano() {
    try {
      _monitorWindows = MonitorImpressaoWindows(
        nomeImpressora: "Argox01",
        onLog: (msg) { debugPrint("Monitor Background: $msg"); },
      );
      _monitorWindows!.iniciar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: const [
          Icon(Icons.print, color: Colors.white),
          SizedBox(width: 10),
          Text("Servidor de Impressão Argox: ONLINE 🟢"),
        ]),
        backgroundColor: Colors.green[800],
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      debugPrint("Erro ao iniciar monitor background: $e");
    }
  }

  @override
  void dispose() {
    _monitorWindows?.parar();
    _buscaController.dispose();
    super.dispose();
  }

  void _irParaListaDeProdutos(String? termoBuscado) {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    Navigator.push(context, MaterialPageRoute(
        builder: (context) => TelaListaProdutos(termoBuscaInicial: termoBuscado)));
    _buscaController.clear();
    FocusScope.of(context).unfocus();
  }

  void _irParaCriarRequisicao() => Navigator.push(context,
      MaterialPageRoute(builder: (context) => const TelaCriarRequisicao()));

  void _irParaRequisicoesPendentes() => Navigator.push(context,
      MaterialPageRoute(builder: (context) => const TelaRequisicoesPendentes()));

  void _irParaNovaMovimentacao() => Navigator.push(context,
      MaterialPageRoute(builder: (c) => const TelaMovimentacao()));

  void _irParaNovoProduto() => Navigator.push(context,
      MaterialPageRoute(builder: (c) => const TelaCadastroProduto()));

  void _irParaNovoParceiro() => Navigator.push(context,
      MaterialPageRoute(builder: (c) => const TelaCadastroParceiro()));

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
      sheetObject.appendRow(['Código','Nome','Qtd','Mín','Máx','Valor','SC','Ativo']
          .map((h) => TextCellValue(h)).toList());
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
          File(filePath)..createSync(recursive: true)..writeAsBytesSync(fileBytes);
          await Share.shareXFiles([XFile(filePath)], text: 'Relatório de Produtos');
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
    final contadores = context.watch<ItemOsProvider>().contadores;

    // ── Perfis ────────────────────────────────────────────────────────────
    final bool isAdmin      = usuario?.isAdmin      ?? false;
    final bool isLider      = usuario?.isLider      ?? false;
    final bool isAlmoxarife = usuario?.isAlmoxarife ?? false;
    final bool isVendedor   = usuario?.isVendedor   ?? false;

    // Quem vê produção e quem cria OS
    final bool temAcessoProducao = isAdmin || isLider || (usuario?.isOperador ?? false);
    final bool podeCriarOS       = isAdmin || isLider ||
        (usuario?.podeAcessarEstacao(EstacaoProducao.criarOS) ?? false);
    final bool temAcessoEstoque  = isAdmin || isAlmoxarife;

    // Estações filtradas pelo perfil do usuário logado
    final estacoesFiltradas = _estacoes
        .where((e) => usuario?.podeAcessarEstacao(e.chave) ?? false)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Protecin Produção'),
        centerTitle: true,
        backgroundColor: _corPrincipal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!kIsWeb && Platform.isWindows)
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: "Status da Impressora",
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (c) => const TelaServidorImpressao())),
            ),
        ],
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

            // ── BUSCA ──────────────────────────────────────────────────
            _buildCampoBusca(),
            const SizedBox(height: 20),

            // ── DASHBOARD DE PRODUÇÃO ──────────────────────────────────
            // Só aparece para quem opera produção (admin, líder, operador)
            if (temAcessoProducao) ...[
              const Text('Status da Produção', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _estacoes.map((e) => _buildDashCard(
                    e.label,
                    contadores[e.chaveContador] ?? 0,
                    e.cor,
                  )).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── ESTAÇÕES ───────────────────────────────────────────────
            // Operador: só estações liberadas. Admin/Líder: todas.
            // Almoxarife/Vendedor: nenhuma.
            if (estacoesFiltradas.isNotEmpty) ...[
              const Text('Estações', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: estacoesFiltradas.map((e) => _buildSquareButton(
                  icon: e.icone,
                  label: e.label,
                  color: e.cor,
                  count: contadores[e.chaveContador] ?? 0,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => e.tela())),
                )).toList(),
              ),
              const SizedBox(height: 25),
              const Divider(thickness: 1),
              const SizedBox(height: 10),
            ],

            // ── MENSAGEM PARA ALMOXARIFE / VENDEDOR ────────────────────
            // Explica o que o perfil tem acesso quando não há estações
            if (!temAcessoProducao && !isVendedor && isAlmoxarife) ...[
              _buildInfoPerfil(
                icone: Icons.inventory_2,
                titulo: 'Módulo de Estoque',
                descricao: 'Use o menu lateral para acessar produtos, movimentações e requisições.',
                cor: Colors.green,
              ),
              const SizedBox(height: 16),
            ],
            if (isVendedor) ...[
              _buildInfoPerfil(
                icone: Icons.point_of_sale,
                titulo: 'Acesso Comercial',
                descricao: 'Use o menu lateral para consultar OS e verificar o estoque disponível.',
                cor: Colors.purple,
              ),
              const SizedBox(height: 16),
            ],

            // ── SCANNER DE CRACHÁ ─────────────────────────────────────────
            // Acessível a todos os perfis — localiza um extintor pelo crachá
            _buildBotaoAcessoRapido(
              icone: Icons.qr_code_scanner,
              titulo: 'Scanner de Crachá',
              subtitulo: 'Localizar extintor pelo QR',
              cor: Colors.blueGrey.shade700,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const TelaScannerCracha()),
              ),
            ),
            const SizedBox(height: 5),

            // ── ACESSO RÁPIDO ──────────────────────────────────────────
            // Criar requisição: admin, líder, operador (não vendedor)
            if (!isVendedor && !isAlmoxarife || temAcessoEstoque) ...[
              const Text('Acesso Rápido', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 10),
            ],

            if (temAcessoProducao) ...[
              _buildBotaoAcessoRapido(
                icone: Icons.add_shopping_cart,
                titulo: 'Criar Requisição',
                subtitulo: 'Solicitar material',
                cor: Colors.blueAccent,
                onPressed: _irParaCriarRequisicao,
              ),
            ],

            // ── ESTOQUE (admin e almoxarife) ───────────────────────────
            if (temAcessoEstoque) ...[
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
              const Text('Cadastros', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
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

      // ── FAB: só admin e líder criam OS ─────────────────────────────────
      floatingActionButton: podeCriarOS
          ? FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const TelaCriarOS())),
        label: const Text('Nova OS'),
        icon: const Icon(Icons.add_box),
        backgroundColor: _corPrincipal,
        foregroundColor: Colors.white,
      )
          : null,
    );
  }

  // ── WIDGETS ───────────────────────────────────────────────────────────────

  Widget _buildInfoPerfil({
    required IconData icone,
    required String titulo,
    required String descricao,
    required Color cor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icone, color: cor, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: TextStyle(
                    fontWeight: FontWeight.bold, color: cor, fontSize: 15)),
                const SizedBox(height: 4),
                Text(descricao, style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampoBusca() {
    return TextFormField(
      controller: _buscaController,
      decoration: InputDecoration(
        hintText: 'Buscar produto...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
      ),
      onFieldSubmitted: (valor) {
        if (valor.trim().isNotEmpty) _irParaListaDeProdutos(valor.trim());
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
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 3,
                      offset: const Offset(0, 1))],
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBotaoAcessoRapido({
    required IconData icone,
    required String titulo,
    required String subtitulo,
    required Color cor,
    required VoidCallback onPressed,
    bool showBadge = false,
  }) {
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
              Stack(clipBehavior: Clip.none, children: [
                Icon(icone, size: 24, color: cor),
                if (showBadge)
                  Positioned(top: -2, right: -2,
                      child: Container(width: 8, height: 8,
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle))),
              ]),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(subtitulo, style: const TextStyle(
                      fontSize: 11, color: Colors.grey)),
                ],
              )),
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final usuario = context.read<UsuarioProvider>().usuario;
    final String permissao = usuario?.permissao ?? 'operador';
    final bool isAdmin      = permissao == 'admin';
    final bool isAlmoxarife = permissao == 'almoxarife';
    final bool isLider      = permissao == 'lider';
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
          ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Início'),
              onTap: () => Navigator.of(context).pop()),
          ListTile(
              leading: const Icon(Icons.inventory_2),
              title: const Text('Lista de Produtos'),
              onTap: () => _irParaListaDeProdutos(null)),
          // Gerenciar Extintores e Lista de OS: não para almoxarife e vendedor
          if (isAdmin || isLider || (usuario?.isOperador ?? false)) ...[
            ListTile(
                leading: const Icon(Icons.fire_extinguisher),
                title: const Text('Gerenciar Extintores'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (c) => const TelaConsultaEquipamentos()));
                }),
          ],
          ListTile(
              leading: const Icon(Icons.assignment),
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
              }),
          if (isAdmin || isAlmoxarife) ...[
            const Divider(),
            const Padding(
                padding: EdgeInsets.only(left: 16, top: 8),
                child: Text("Gestão",
                    style: TextStyle(color: Colors.grey, fontSize: 12))),
            ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Parceiros'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (c) => const TelaParceiros()));
                }),
            ListTile(
                leading: const Icon(Icons.receipt_long),
                title: const Text('Extrato Movimentações'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (c) => const TelaExtratoMovimentacoes()));
                }),
            ListTile(
                leading: const Icon(Icons.dashboard),
                title: const Text('Relatórios'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (c) => const TelaRelatorios()));
                }),
            ListTile(
                leading: const Icon(Icons.file_download),
                title: const Text('Exportar Produtos (Excel)'),
                onTap: () {
                  Navigator.pop(context);
                  _exportarProdutosParaExcel();
                }),
          ],
          if (isAdmin) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Aprovar Usuários'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (c) => const TelaAprovacaoUsuarios()));
              },
            ),
          ],
          if (isAdmin || isLider) ...[
            if (!isAdmin) const Divider(),
            ListTile(
              leading: const Icon(Icons.manage_accounts),
              title: const Text('Gestão de Acesso'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (c) => const TelaGestaoAcesso()));
              },
            ),
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