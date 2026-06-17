// lib/telas/producao/estacao/tela_lista_lotes_estanqueidade.dart
//
// Estanqueidade filtra por:
//   1. O extintor tem 'estanqueidade' no seu roteiro (caminho de produção)
//   2. O tipo de agente bate com os filtros passados (ex: ['PO', 'ABC'])
//
// nomeSetorCC é opcional: permite que a home screen informe o CC
// correto para cada tipo. Se não informado, o campo fica em branco.

import 'package:flutter/material.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_base.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_estanqueidade.dart';

class TelaListaLotesEstanqueidade extends StatelessWidget {
  final String titulo;
  final List<String> filtrosAgente;

  /// Centro de custo do setor. Opcional — usuário preenche se ficar em branco.
  final String nomeSetorCC;

  const TelaListaLotesEstanqueidade({
    super.key,
    required this.titulo,
    required this.filtrosAgente,
    this.nomeSetorCC = '',
  });

  @override
  Widget build(BuildContext context) {
    return TelaListaLotesBase(
      titulo: 'Fila: $titulo',
      corSetor: Colors.lightBlue.shade800,
      iconeTrailing: Icon(
        titulo.contains('PQS') || titulo.contains('PÓ')
            ? Icons.bubble_chart
            : Icons.water_drop,
        color: Colors.blue.shade300,
      ),
      statusAguardando: 'aguardando_estanqueidade',
      mensagemVazia: 'Nenhum lote pendente neste setor.',
      textoSubtitulo: (passaram, total) =>
      passaram == total ? 'Teste Concluído' : 'Aguardando submersão...',
      streamFonte: (repo, empresaId) => repo.streamItensEmProducao(empresaId),
      filtroItem: (doc) {
        final agente = doc['tipoAgente']?.toString().toUpperCase() ?? '';
        final List roteiro = doc['roteiro'] ?? [];
        final temEstanqueidade =
        roteiro.any((e) => e.toString().contains('estanqueidade'));
        final agenteBate =
        filtrosAgente.any((f) => agente.contains(f.toUpperCase()));
        return temEstanqueidade && agenteBate;
      },
      contadorJaPassaram: (itens) => itens.where((doc) {
        final st = doc['status'].toString();
        return st != 'aguardando_estanqueidade' && !st.contains('recarga');
      }).length,
      construtorTela: (osId) => TelaEstacaoEstanqueidade(
        osId: osId,
        filtrosAgente: filtrosAgente,
      ),
      // ── Novos recursos ──────────────────────────────────────────
      mostrarNomeCliente: true,
      mostrarBotaoRequisicao: true,
      nomeSetorCC: nomeSetorCC,
      mostrarBotaoReverter: true,
      statusParaReverter: 'aguardando_estanqueidade',
      // ── CORREÇÃO BUG: reverter estanqueidade → recarga correto por agente ──
      // Antes: statusAnteriorReverter: 'aguardando_recarga' (genérico)
      // As telas de recarga filtram por 'aguardando_recarga_co2/abc/bc',
      // então o genérico fazia todos os itens desaparecerem.
      // Agora: deriva o status correto lendo o roteiro de cada item.
      //   roteiro CO2: [..., 'recarga_co2', 'estanqueidade_co2', ...]
      //   roteiro ABC: [..., 'recarga_abc', 'estanqueidade_abc', ...]
      //   roteiro BC:  [..., 'recarga_bc',  'estanqueidade_bc',  ...]
      // A etapa imediatamente ANTES da estanqueidade no roteiro é sempre a recarga.
      statusAnteriorReverterFn: (item) {
        final roteiro = List<String>.from(item['roteiro'] ?? []);
        final idx = roteiro.indexWhere((e) => e.toString().contains('estanqueidade'));
        if (idx > 0) return 'aguardando_${roteiro[idx - 1]}';
        // Fallback por tipoAgente (segurança caso roteiro esteja vazio)
        final agente = (item['tipoAgente'] ?? '').toString().toLowerCase();
        if (agente.contains('co2')) return 'aguardando_recarga_co2';
        if (agente.contains('abc')) return 'aguardando_recarga_abc';
        if (agente.contains('bc')) return 'aguardando_recarga_bc';
        if (agente.contains('ap') || agente.contains('esp') || agente.contains('agua')) return 'aguardando_recarga_agua_espuma';
        return 'aguardando_recarga_abc';
      },
      etapaAnteriorOS: 'recarga',
      statusLoteAnteriorOS: 'em_recarga',
      mensagemReverter:
      'Deseja devolver este lote inteiro para a etapa de RECARGA?',
    );
  }
}