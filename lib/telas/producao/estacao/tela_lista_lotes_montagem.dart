// lib/telas/producao/estacao/tela_lista_lotes_montagem.dart

import 'package:flutter/material.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_lista_lotes_base.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_montagem.dart';

class TelaListaLotesMontagem extends StatelessWidget {
  const TelaListaLotesMontagem({super.key});

  @override
  Widget build(BuildContext context) {
    return TelaListaLotesBase(
      titulo: 'Fila: Montagem Final e Lacração',
      corSetor: Colors.deepPurple.shade700,
      iconeTrailing: Icon(Icons.verified, color: Colors.deepPurple.shade700),
      statusAguardando: 'aguardando_montagem',
      mensagemVazia: 'Nenhum extintor pendente de lacração.',
      textoSubtitulo: (passaram, total) =>
          passaram == total ? 'Pronto para Expedição' : 'Processando lacração...',
      streamFonte: (repo) => repo.streamItensEmProducao(),
      // Considera concluído quando o item já saiu para expedição ou foi finalizado
      contadorJaPassaram: (itens) => itens.where((doc) {
        final st = doc['status']?.toString().toLowerCase().replaceAll('_', '') ?? '';
        return st == 'aguardandoexpedicao' || st == 'finalizado';
      }).length,
      construtorTela: (osId) => TelaEstacaoMontagem(osId: osId),
    );
  }
}
