// lib/telas/producao/estacao/tela_lista_lotes_base.dart
//
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  TELA-MESTRE — FILA DE LOTES POR ESTAÇÃO
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//
//  Por que este arquivo existe:
//  Todas as telas tela_lista_lotes_*.dart fazem a mesma coisa:
//  mostrar quais Ordens de Serviço têm extintores aguardando numa
//  estação específica. Antes, essa lógica estava copiada 12 vezes.
//  Agora ela vive aqui uma única vez.
//
//  Como usar:
//  Cada setor cria um widget pequenininho que instancia este aqui,
//  passando apenas o que é diferente (título, cor, status, etc.).
//  Veja os exemplos em tela_lista_lotes_lixa.dart e afins.
//
//  Atualização maio/2025:
//  Adicionados: mostrarNomeCliente, mostrarBotaoRequisicao e
//  mostrarBotaoReverter. Todos opcionais — telas existentes não
//  precisam ser alteradas para continuar funcionando.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/repositories/item_os_repository.dart';
import 'package:protecin_producao/repositories/ordem_servico_repository.dart';
import 'package:protecin_producao/telas/estoque/tela_criar_requisicao.dart';
import 'package:protecin_producao/utils/mapeador_custos.dart';

// ── Tipos auxiliares ─────────────────────────────────────────────

/// Função que conta quantos itens "já passaram ou estão" neste setor.
/// Recebe a lista de itens da OS. Retorna um número inteiro.
///
/// Exemplo para Lixa:
///   (itens) => itens.where((doc) {
///     final st = doc['status']?.toString() ?? '';
///     return st != 'aguardando_limpeza' && st != 'em_limpeza';
///   }).length;
typedef ContadorPassaram = int Function(List<Map<String, dynamic>> itens);

/// Função que constrói a tela de destino ao tocar num card.
/// Recebe o ID da OS. Retorna o widget da tela correspondente.
///
/// Exemplo: (osId) => TelaEstacaoLixa(osId: osId)
typedef ConstrutorTela = Widget Function(String osId);

// ── Widget principal ─────────────────────────────────────────────

class TelaListaLotesBase extends StatelessWidget {
  // ── VISUAL ────────────────────────────────────────────────────

  /// Texto que aparece na barra do topo. Ex: 'Fila de Lixa / Jato'
  final String titulo;

  /// Cor da barra do topo e dos círculos de progresso
  final Color corSetor;

  /// Ícone no canto direito de cada card (padrão: seta →)
  final Widget iconeTrailing;

  /// Se true, mostra botão "🏠" para voltar à Home na barra do topo.
  final bool mostrarBotaoHome;

  /// Se informado, mostra um ícone no círculo em vez do contador "X/Y".
  final IconData? iconeAvatar;

  /// Formata o texto dentro do círculo do avatar. Padrão: '$passaram/$total'.
  final String Function(int passaram, int total)? textoAvatar;

  // ── DADOS ────────────────────────────────────────────────────

  /// Fornece o stream de itens da estação.
  final Stream<List<Map<String, dynamic>>> Function(ItemOsRepository repo, String empresaId)
  streamFonte;

  /// Filtro aplicado em cada item antes de agrupar por OS.
  final bool Function(Map<String, dynamic> doc)? filtroItem;

  // ── LÓGICA DE EXIBIÇÃO ────────────────────────────────────────

  /// Status que define se uma OS deve aparecer na lista.
  final String statusAguardando;

  /// Substitui o filtro padrão de OS quando necessário.
  final bool Function(List<Map<String, dynamic>> itensOS)? filtroOS;

  /// Calcula quantos itens "já passaram ou estão" neste setor.
  final ContadorPassaram contadorJaPassaram;

  // ── TEXTOS ───────────────────────────────────────────────────

  /// Mensagem exibida quando não há nenhuma OS pendente neste setor.
  final String mensagemVazia;

  /// Texto do subtítulo de cada card. Recebe (passaram, total).
  final String Function(int passaram, int total)? textoSubtitulo;

  // ── NAVEGAÇÃO ────────────────────────────────────────────────

  /// Constrói a tela que abre ao tocar no card da OS.
  final ConstrutorTela construtorTela;

  // ── NOME DO CLIENTE ──────────────────────────────────────────
  //
  // Quando true, a Base abre um segundo stream (de OS) para buscar
  // o clienteNome de cada OS e exibi-lo como título do card.
  // O custo é baixo: um único stream de OS em paralelo ao de itens.
  //
  // Analogia: é como ter uma lista de pedidos (itens) e uma lista
  // de clientes (OS) abertas ao mesmo tempo para saber o nome de
  // quem fez cada pedido.

  /// Se true, mostra o nome do cliente como título do card.
  /// Requer que OrdemServicoRepository esteja disponível na árvore.
  final bool mostrarNomeCliente;

  // ── BOTÃO REQUISIÇÃO ─────────────────────────────────────────
  //
  // Quando true, adiciona o botão 🛒 no canto direito de cada card.
  // O operador toca nele para abrir a tela de requisição de material
  // já com o número da OS e o centro de custo do setor preenchidos.

  /// Se true, exibe o botão de Requisição de Material 🛒 em cada card.
  final bool mostrarBotaoRequisicao;

  /// Nome do setor para lookup no MapeadorCustos.
  /// Ex: 'LIXAMENTO', 'PINTURA', 'TESTE HIDROSTÁTICO EXTINTORES'.
  /// Se não encontrado, o campo fica em branco para preenchimento manual.
  final String nomeSetorCC;

  // ── BOTÃO REVERTER LOTE ──────────────────────────────────────
  //
  // Quando true, o admin pode fazer long press num card para devolver
  // o lote inteiro à etapa anterior. Aparece uma confirmação antes
  // de qualquer ação. Operadores normais não veem nada ao segurar.
  //
  // Parâmetros necessários (todos sem padrão útil — devem ser
  // informados sempre que mostrarBotaoReverter = true):
  //
  //   statusParaReverter   → status atual dos itens (ex: 'aguardando_lixa')
  //   statusAnteriorReverter → status de destino   (ex: 'aguardando_limpeza')
  //   etapaAnteriorOS      → etapaAtual no doc OS  (ex: 'limpeza')
  //   statusLoteAnteriorOS → statusLote no doc OS  (ex: 'em_limpeza')
  //   mensagemReverter     → texto de confirmação  (ex: 'Devolver para Limpeza?')

  /// Se true, admin pode segurar o card para reverter o lote.
  final bool mostrarBotaoReverter;

  /// Status atual dos itens (de onde sair). Ex: 'aguardando_lixa'
  final String statusParaReverter;

  /// Status de destino (para onde voltar). Ex: 'aguardando_limpeza'
  final String statusAnteriorReverter;

  /// Valor de etapaAtual a gravar no documento da OS. Ex: 'limpeza'
  final String etapaAnteriorOS;

  /// Valor de statusLote a gravar no documento da OS. Ex: 'em_limpeza'
  final String statusLoteAnteriorOS;

  /// Texto exibido no diálogo de confirmação do reverter.
  /// Ex: 'Deseja devolver este lote inteiro para a etapa de LIMPEZA?'
  final String mensagemReverter;

  // ── Construtor ───────────────────────────────────────────────

  const TelaListaLotesBase({
    super.key,
    // Visuais
    required this.titulo,
    required this.corSetor,
    this.iconeTrailing = const Icon(Icons.arrow_forward_ios, size: 16),
    this.mostrarBotaoHome = false,
    this.iconeAvatar,
    this.textoAvatar,
    // Dados
    required this.streamFonte,
    this.filtroItem,
    // Lógica
    required this.statusAguardando,
    this.filtroOS,
    required this.contadorJaPassaram,
    // Textos
    required this.mensagemVazia,
    this.textoSubtitulo,
    // Navegação
    required this.construtorTela,
    // Nome do cliente
    this.mostrarNomeCliente = false,
    // Requisição
    this.mostrarBotaoRequisicao = false,
    this.nomeSetorCC = '',
    // Reverter
    this.mostrarBotaoReverter = false,
    this.statusParaReverter = '',
    this.statusAnteriorReverter = '',
    this.etapaAnteriorOS = '',
    this.statusLoteAnteriorOS = '',
    this.mensagemReverter = 'Deseja devolver este lote para a etapa anterior?',
  });

  // ── Reverter lote ────────────────────────────────────────────

  Future<void> _confirmarReverter(
      BuildContext context,
      String osId,
      ) async {
    // Captura o repositório antes do await — boa prática com BuildContext async
    final repo = context.read<ItemOsRepository>();

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '⚠️ REVERTER LOTE',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Text(mensagemReverter),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'SIM, DEVOLVER',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmou != true) return;

    try {
      await repo.reverterLote(
        osId: osId,
        statusAtual: statusParaReverter,
        statusAnterior: statusAnteriorReverter,
        dadosOS: {
          'etapaAtual': etapaAnteriorOS,
          'statusLote': statusLoteAnteriorOS,
        },
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lote devolvido com sucesso!'),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
    } catch (e) {
      debugPrint('[TelaListaLotesBase] Erro ao reverter lote $osId: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao reverter: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Build principal ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ItemOsRepository>();

    // Lê permissão do usuário para controlar o reverter.
    // context.read<> não causa rebuild — só lemos uma vez.
    final usuario = context.read<UsuarioProvider>().usuario;
    final isAdmin = usuario?.permissao.toLowerCase() == 'admin' ||
        usuario?.permissao.toLowerCase() == 'administrador';

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        backgroundColor: corSetor,
        foregroundColor: Colors.white,
        leading: mostrarBotaoHome
            ? IconButton(
          icon: const Icon(Icons.home),
          tooltip: 'Ir para Home',
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        )
            : null,
      ),
      body: mostrarNomeCliente
          ? _buildComNomeCliente(context, repo, isAdmin)
          : _buildLista(context, repo, isAdmin, {}),
    );
  }

  // ── Quando mostrarNomeCliente = true ─────────────────────────
  //
  // Abre um stream externo de OS para montar o mapa osId → dados.
  // Enquanto o stream de OS carrega, exibe o stream de itens
  // normalmente (sem nome — melhor que travar a tela).

  Widget _buildComNomeCliente(
      BuildContext context,
      ItemOsRepository repo,
      bool isAdmin,
      ) {
    final empresaId = context.read<UsuarioProvider>().usuario?.empresaId ?? '';
    // FutureBuilder em vez de StreamBuilder: o mapa osId → clienteNome
    // só precisa ser carregado uma vez — não há necessidade de conexão
    // permanente. buscarOSAbertas já filtra no Firestore, sem baixar
    // OS finalizadas.
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: context.read<OrdemServicoRepository>().buscarOSAbertas(empresaId),
      builder: (context, osSnapshot) {
        // Monta o mapa de lookup: osId → dados da OS (clienteNome, numeroOS…)
        // Se o future ainda não chegou, passa mapa vazio — a lista já aparece.
        final osDataMap = <String, Map<String, dynamic>>{};
        if (osSnapshot.hasData) {
          for (final os in osSnapshot.data!) {
            final id = os['id']?.toString() ?? '';
            if (id.isNotEmpty) osDataMap[id] = os;
          }
        }

        return _buildLista(context, repo, isAdmin, osDataMap);
      },
    );
  }

  // ── Lista principal de OS ────────────────────────────────────

  Widget _buildLista(
      BuildContext context,
      ItemOsRepository repo,
      bool isAdmin,
      Map<String, Map<String, dynamic>> osDataMap,
      ) {
    final empresaId = context.read<UsuarioProvider>().usuario?.empresaId ?? '';
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: streamFonte(repo, empresaId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Text('Erro ao carregar dados: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final todosOsItens = snapshot.data!;

        // ── 1. Filtra e agrupa por OS ─────────────────────────
        final Map<String, List<Map<String, dynamic>>> agrupadosPorOS = {};
        for (final doc in todosOsItens) {
          if (filtroItem != null && !filtroItem!(doc)) continue;
          final osId = doc['osId']?.toString() ?? 'S/OS';
          agrupadosPorOS.putIfAbsent(osId, () => []).add(doc);
        }

        // ── 2. Decide quais OS mostrar ────────────────────────
        final osParaMostrar = agrupadosPorOS.keys.where((osId) {
          final itens = agrupadosPorOS[osId]!;
          if (filtroOS != null) return filtroOS!(itens);
          return itens.any((doc) => doc['status'] == statusAguardando);
        }).toList();

        if (osParaMostrar.isEmpty) {
          return Center(child: Text(mensagemVazia));
        }

        // ── 3. Monta a lista de cards ─────────────────────────
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: osParaMostrar.length,
          itemBuilder: (context, index) {
            final osId = osParaMostrar[index];
            final itens = agrupadosPorOS[osId]!;

            final total = itens.length;
            final passaram = contadorJaPassaram(itens);
            final progresso = total > 0 ? passaram / total : 0.0;
            final concluido = passaram == total;

            // Dados da OS (nome do cliente, número da OS)
            final osData = osDataMap[osId] ?? {};
            final clienteNome =
                osData['clienteNome']?.toString() ?? 'Cliente N/D';
            final numeroOS = osData['numeroOS']?.toString() ??
                (osId.length >= 5
                    ? osId.substring(osId.length - 5).toUpperCase()
                    : osId);

            // Texto do avatar (círculo da esquerda)
            final textoDoAvatar = textoAvatar != null
                ? textoAvatar!(passaram, total)
                : '$passaram/$total';

            // Texto do subtítulo embaixo da barra de progresso
            final subtitulo = textoSubtitulo != null
                ? textoSubtitulo!(passaram, total)
                : concluido
                ? 'Todos os itens processados'
                : 'Processando itens do lote...';

            return Card(
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                // Navega para a estação ao tocar
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => construtorTela(osId),
                  ),
                ),
                // Long press → reverter (somente admin, somente quando habilitado)
                onLongPress: (mostrarBotaoReverter && isAdmin)
                    ? () => _confirmarReverter(context, osId)
                    : null,

                // ── Avatar: círculo de progresso ──────────────
                leading: CircleAvatar(
                  backgroundColor: concluido ? Colors.green : corSetor,
                  child: iconeAvatar != null
                      ? Icon(
                    concluido ? Icons.check_circle : iconeAvatar,
                    color: Colors.white,
                  )
                      : Text(
                    textoDoAvatar,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // ── Título: nome do cliente (se habilitado) ou ID da OS ──
                title: Text(
                  mostrarNomeCliente ? clienteNome : 'Lote OS: $osId',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                // ── Subtítulo: OS + barra de progresso + texto ───
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Número da OS — só aparece quando mostramos o nome do cliente
                    // (caso contrário o osId já está no título)
                    if (mostrarNomeCliente) ...[
                      const SizedBox(height: 2),
                      Text(
                        'OS: $numeroOS',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    // Barra de progresso
                    LinearProgressIndicator(
                      value: progresso,
                      backgroundColor: Colors.grey[200],
                      color: concluido ? Colors.green : corSetor,
                      minHeight: 6,
                    ),
                    const SizedBox(height: 4),
                    Text(subtitulo),
                    // Dica de long press para admin
                    if (mostrarBotaoReverter && isAdmin)
                      Text(
                        '(Segure para reverter lote)',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red.shade400,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),

                // ── Trailing: botão 🛒 (se habilitado) + seta ───
                trailing: mostrarBotaoRequisicao
                    ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.shopping_cart_checkout,
                        color: Colors.blue,
                      ),
                      tooltip: 'Solicitar material',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TelaCriarRequisicao(
                            osPrePreenchida: numeroOS,
                            ccPrePreenchido:
                            MapeadorCustos.obterCC(nomeSetorCC),
                            subTipoPrePreenchido: 'OS',
                          ),
                        ),
                      ),
                    ),
                    iconeTrailing,
                  ],
                )
                    : iconeTrailing,
              ),
            );
          },
        );
      },
    );
  }
}