import 'package:cloud_firestore/cloud_firestore.dart';

// -----------------------------------------------------------------------------
// 1. O ENUM COMPLETO (Mantido igual)
// -----------------------------------------------------------------------------
enum StatusOS {
  emCadastro,
  emProducao,

  // Fluxo de Entrada
  aguardandoDescarga, emDescarga,

  // Tratamento
  aguardandoLimpeza, emLimpeza,
  aguardandoLixa, emLixa,
  aguardandoPintura, emPintura,

  // Válvulas
  aguardandoManutencao, emManutencao,
  aguardandoSaque, emSaque,

  // Testes
  aguardandoTH, emTH,
  aguardandoEstanqueidade, emEstanqueidade,
  emEnsaioMangueira,

  // Finalização
  aguardandoRecarga, emRecarga,
  aguardandoMontagem, emMontagem,
  aguardandoAcabamento, emAcabamento,

  aguardandoExpedicao, emExpedicao,
  finalizado,
}

// -----------------------------------------------------------------------------
// 2. O DIÁRIO DE BORDO
// -----------------------------------------------------------------------------
class HistoricoEtapa {
  final StatusOS etapa;
  final DateTime dataHora;
  final String usuarioNome;
  final String? observacao;

  HistoricoEtapa({
    required this.etapa,
    required this.dataHora,
    required this.usuarioNome,
    this.observacao,
  });

  Map<String, dynamic> toJson() {
    return {
      'etapa': etapa.name,
      'dataHora': Timestamp.fromDate(dataHora),
      'usuarioNome': usuarioNome,
      'observacao': observacao,
    };
  }

  factory HistoricoEtapa.fromJson(Map<String, dynamic> json) {
    return HistoricoEtapa(
      etapa: ItemOS._traduzirStatus(json['etapa']),
      dataHora: (json['dataHora'] as Timestamp? ?? Timestamp.now()).toDate(),
      usuarioNome: json['usuarioNome'] ?? 'Usuário Desconhecido',
      observacao: json['observacao'],
    );
  }
}

// -----------------------------------------------------------------------------
// 3. O ITEM DE PRODUÇÃO (CORRIGIDO)
// -----------------------------------------------------------------------------
class ItemOS {
  final String id;
  final String osId;
  final String equipamentoId;
  final String idCrachaTemporario;
  final String empresaId;
  final String tipoAgente;

  final StatusOS statusAtual;
  final String statusOriginal; // Espião

  final List<HistoricoEtapa> historicoEtapas;
  final Map<String, dynamic>? dadosTH;
  final Map<String, dynamic>? dadosRecarga;

  ItemOS({
    required this.id,
    required this.osId,
    required this.equipamentoId,
    required this.idCrachaTemporario,
    required this.empresaId,
    required this.tipoAgente,
    required this.statusAtual,
    required this.statusOriginal,
    required this.historicoEtapas,
    this.dadosTH,
    this.dadosRecarga,
  });

  Map<String, dynamic> toJson() {
    return {
      'osId': osId,
      'equipamentoId': equipamentoId,
      'idCrachaTemporario': idCrachaTemporario,
      'empresaId': empresaId,
      'tipoAgente': tipoAgente,
      'statusAtual': statusAtual.name,
      'historicoEtapas': historicoEtapas.map((h) => h.toJson()).toList(),
      'dadosTH': dadosTH,
      'dadosRecarga': dadosRecarga,
    };
  }

  factory ItemOS.fromJson(Map<String, dynamic> json, String id) {

    // --- AQUI ESTAVA O ERRO E AQUI ESTÁ A CORREÇÃO ---
    // Antes: json['statusAtual'] ?? json['status'] (Priorizava o genérico "emProducao")
    // Agora: json['status'] ?? json['statusAtual'] (Prioriza o específico "aguardando_descarga")

    String rawStatus = (json['status'] ?? json['statusAtual'] ?? '').toString();

    // Se o status específico estiver vazio, tenta o genérico como backup
    if (rawStatus.isEmpty || rawStatus == 'null') {
      rawStatus = (json['statusAtual'] ?? '').toString();
    }
    // ------------------------------------------------

    return ItemOS(
      id: id,
      osId: json['osId'] ?? '',
      equipamentoId: json['equipamentoId'] ?? '',
      idCrachaTemporario: json['idCrachaTemporario'] ?? '',
      empresaId: json['empresaId'] ?? '',
      tipoAgente: json['tipoAgente'] ?? '',

      statusOriginal: rawStatus, // Guarda o que leu para debug

      statusAtual: _traduzirStatus(rawStatus), // Traduz o específico

      historicoEtapas: (json['historicoEtapas'] as List<dynamic>? ?? [])
          .map((h) => HistoricoEtapa.fromJson(h as Map<String, dynamic>))
          .toList(),
      dadosTH: json['dadosTH'] as Map<String, dynamic>?,
      dadosRecarga: json['dadosRecarga'] as Map<String, dynamic>?,
    );
  }

  // --- TRADUTOR (Mantive o Agressivo que criamos) ---
  static StatusOS _traduzirStatus(String? valorBanco) {
    if (valorBanco == null || valorBanco.isEmpty) return StatusOS.emCadastro;

    String s = valorBanco.toLowerCase();

    // Palavras-chave
    if (s.contains('limpeza')) return StatusOS.aguardandoLimpeza;
    if (s.contains('descarga')) return StatusOS.aguardandoDescarga;
    if (s.contains('lixa')) return StatusOS.aguardandoLixa;
    if (s.contains('pintura')) return StatusOS.aguardandoPintura;
    if (s.contains('manutencao')) return StatusOS.aguardandoManutencao;
    if (s.contains('valvula') || s.contains('saque')) return StatusOS.aguardandoSaque;
    if (s.contains('estanqueidade')) return StatusOS.aguardandoEstanqueidade;
    if (s.contains('hidro') || s.contains('th')) return StatusOS.aguardandoTH;
    if (s.contains('recarga')) return StatusOS.aguardandoRecarga;
    if (s.contains('montagem')) return StatusOS.aguardandoMontagem;
    if (s.contains('acabamento')) return StatusOS.aguardandoAcabamento;
    if (s.contains('expedicao')) return StatusOS.aguardandoExpedicao;
    if (s.contains('finalizado') || s.contains('pronto')) return StatusOS.finalizado;
    if (s.contains('cadastro')) return StatusOS.emCadastro;

    try {
      String limpo = s.replaceAll('_', '');
      return StatusOS.values.firstWhere(
              (e) => e.name.toLowerCase() == limpo
      );
    } catch (e) {
      return StatusOS.emProducao;
    }
  }
}