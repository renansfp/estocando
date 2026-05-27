// lib/telas/producao/estacao/tela_lista_lotes_manutencao.dart
//
// Atenção: esta tela precisa do usuário logado para passar o nome
// para a TelaEstacaoManutencaoValvula. Por isso lemos o UsuarioProvider
// aqui, antes de montar a TelaListaLotesBase, e capturamos o nome
// dentro do construtorTela via closure.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_base.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_manutencao_valvula.dart';

class TelaListaLotesManutencao extends StatelessWidget {
  const TelaListaLotesManutencao({super.key});

  @override
  Widget build(BuildContext context) {
    // Lemos o nome do usuário aqui (fora do construtorTela) para evitar
    // acesso ao contexto dentro do callback de navegação.
    final nomeUsuario =
        Provider.of<UsuarioProvider>(context, listen: false).usuario?.nome ??
            'Técnico';

    return TelaListaLotesBase(
      titulo: 'Fila: Manutenção de Componentes',
      corSetor: Colors.teal.shade700,
      mostrarBotaoHome: true,
      statusAguardando: 'aguardando_manutencao_valvula',
      mensagemVazia: 'Nenhum componente pendente de revisão.',
      textoSubtitulo: (passaram, total) => passaram == total
          ? 'Todos os componentes revisados'
          : 'Revisando componentes do lote...',
      streamFonte: (repo, empresaId) => repo.streamItensEmProducao(empresaId),
      contadorJaPassaram: (itens) => itens.where((doc) {
        final st = doc['status']?.toString() ?? '';
        return st != 'aguardando_limpeza' &&
            st != 'em_limpeza' &&
            st != 'aguardando_lixa';
      }).length,
      construtorTela: (osId) => TelaEstacaoManutencaoValvula(
        usuarioNome: nomeUsuario,
        estacaoNome: 'Manutenção de Componentes',
        osId: osId,
      ),
      // ── Novos recursos ──────────────────────────────────────────
      mostrarNomeCliente: true,
      mostrarBotaoRequisicao: true,
      nomeSetorCC: 'MANUTENÇÃO DE COMPONENTES', // → CC 4224
      mostrarBotaoReverter: true,
      statusParaReverter: 'aguardando_manutencao_valvula',
      statusAnteriorReverter: 'aguardando_lixa',
      etapaAnteriorOS: 'lixa',
      statusLoteAnteriorOS: 'em_lixa',
      mensagemReverter:
      'Deseja devolver este lote inteiro para a etapa de LIXA?',
    );
  }
}