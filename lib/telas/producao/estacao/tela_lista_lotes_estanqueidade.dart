// lib/telas/producao/estacao/tela_lista_lotes_estanqueidade.dart
//
// Estanqueidade filtra por:
//   1. O extintor tem 'estanqueidade' no seu roteiro (caminho de produção)
//   2. O tipo de agente bate com os filtros passados (ex: ['PO', 'ABC'])
//
// O parâmetro filtrosAgente é mantido igual ao original para não quebrar
// as telas que já instanciam esta classe.

import 'package:flutter/material.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_base.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_estanqueidade.dart';

class TelaListaLotesEstanqueidade extends StatelessWidget {
  final String titulo;
  final List<String> filtrosAgente;

  const TelaListaLotesEstanqueidade({
    super.key,
    required this.titulo,
    required this.filtrosAgente,
  });

  @override
  Widget build(BuildContext context) {
    return TelaListaLotesBase(
      titulo: 'Fila: $titulo',
      corSetor: Colors.lightBlue.shade800,
      // Ícone dinâmico: bolhas para pó, gota para água/espuma
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
      streamFonte: (repo) => repo.streamItensEmProducao(),
      // Filtra: só itens com estanqueidade no roteiro E com o agente certo
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
    );
  }
}
