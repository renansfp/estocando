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
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/repositories/item_os_repository.dart';

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
  /// Alguns setores têm, outros não.
  final bool mostrarBotaoHome;

  /// Se informado, mostra um ícone no círculo em vez do contador "X/Y".
  /// Usado por Pré-Montagem (ícone de relógio/check) e Expedição (caminhão).
  final IconData? iconeAvatar;

  /// Formata o texto dentro do círculo do avatar. Padrão: '$passaram/$total'.
  /// Use para customizar, ex: mostrar só os pendentes.
  final String Function(int passaram, int total)? textoAvatar;

  // ── DADOS ────────────────────────────────────────────────────

  /// Fornece o stream de dados. Recebe o repositório e devolve o stream.
  ///
  /// Use streamItensPorRoteiro para setores com roteiro específico:
  ///   (repo) => repo.streamItensPorRoteiro('lixa')
  ///
  /// Use streamItensEmProducao para setores que filtram depois:
  ///   (repo) => repo.streamItensEmProducao()
  final Stream<List<Map<String, dynamic>>> Function(ItemOsRepository repo)
      streamFonte;

  /// Filtro aplicado em cada item antes de agrupar por OS.
  /// Se null, todos os itens passam.
  ///
  /// Usado por Recarga e Estanqueidade, que filtram por tipo de agente
  /// (Pó ABC, CO2, Água...).
  final bool Function(Map<String, dynamic> doc)? filtroItem;

  // ── LÓGICA DE EXIBIÇÃO ────────────────────────────────────────

  /// Status que define se uma OS deve aparecer na lista.
  /// A OS aparece se tiver ao menos 1 item com este status.
  ///
  /// Ex: 'aguardando_lixa', 'aguardando_pintura', etc.
  final String statusAguardando;

  /// Substitui o filtro padrão de OS quando necessário.
  /// Por padrão, uma OS aparece se algum item tem [statusAguardando].
  /// Passe aqui uma função personalizada para casos especiais (ex: Recarga).
  final bool Function(List<Map<String, dynamic>> itensOS)? filtroOS;

  /// Calcula quantos itens "já passaram ou estão" neste setor.
  /// Usado para calcular o progresso e o texto do avatar.
  final ContadorPassaram contadorJaPassaram;

  // ── TEXTOS ───────────────────────────────────────────────────

  /// Mensagem exibida quando não há nenhuma OS pendente neste setor.
  final String mensagemVazia;

  /// Texto do subtítulo de cada card. Recebe (passaram, total).
  ///
  /// Se não informado, usa:
  ///   - 'Todos os itens processados' quando 100%
  ///   - 'Processando itens do lote...' quando incompleto
  final String Function(int passaram, int total)? textoSubtitulo;

  // ── NAVEGAÇÃO ────────────────────────────────────────────────

  /// Constrói a tela que abre ao tocar no card da OS.
  /// Recebe o ID da OS. Ex: (osId) => TelaEstacaoLixa(osId: osId)
  final ConstrutorTela construtorTela;

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
  });

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ItemOsRepository>();

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        backgroundColor: corSetor,
        foregroundColor: Colors.white,
        // Botão Home: só aparece nos setores que pedem
        leading: mostrarBotaoHome
            ? IconButton(
                icon: const Icon(Icons.home),
                tooltip: 'Ir para Home',
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              )
            : null,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: streamFonte(repo),
        builder: (context, snapshot) {
          // Tratamento de estados do stream
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar dados: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final todosOsItens = snapshot.data!;

          // ── 1. Filtra e agrupa por OS ───────────────────────
          final Map<String, List<Map<String, dynamic>>> agrupadosPorOS = {};
          for (final doc in todosOsItens) {
            // Aplica o filtro de item (ex: por tipo de agente)
            if (filtroItem != null && !filtroItem!(doc)) continue;

            final osId = doc['osId']?.toString() ?? 'S/OS';
            agrupadosPorOS.putIfAbsent(osId, () => []).add(doc);
          }

          // ── 2. Decide quais OS mostrar ──────────────────────
          // Usa o filtroOS personalizado ou o filtro padrão por statusAguardando
          final osParaMostrar = agrupadosPorOS.keys.where((osId) {
            final itens = agrupadosPorOS[osId]!;
            if (filtroOS != null) return filtroOS!(itens);
            return itens.any((doc) => doc['status'] == statusAguardando);
          }).toList();

          if (osParaMostrar.isEmpty) {
            return Center(child: Text(mensagemVazia));
          }

          // ── 3. Monta a lista de cards ───────────────────────
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
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => construtorTela(osId),
                    ),
                  ),
                  // Círculo de progresso (avatar)
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
                  title: Text(
                    'Lote OS: $osId',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      // Barra de progresso
                      LinearProgressIndicator(
                        value: progresso,
                        backgroundColor: Colors.grey[200],
                        color: concluido ? Colors.green : corSetor,
                        minHeight: 6,
                      ),
                      const SizedBox(height: 4),
                      Text(subtitulo),
                    ],
                  ),
                  trailing: iconeTrailing,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
