import 'package:cloud_firestore/cloud_firestore.dart';

// -----------------------------------------------------------------------------
// 1. O ENUM COMPLETO
// -----------------------------------------------------------------------------
enum StatusOS {
  emCadastro,
  emProducao,
  aguardandoDescarga, emDescarga,
  aguardandoLimpeza, emLimpeza,
  aguardandoLixa, emLixa,
  aguardandoPintura, emPintura,
  aguardandoManutencao, emManutencao,
  aguardandoSaque, emSaque,
  aguardandoTH, emTH,
  aguardandoEstanqueidade, emEstanqueidade,
  emEnsaioMangueira,
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
// 3. O ITEM DE PRODUÇÃO
// -----------------------------------------------------------------------------
class ItemOS {
  final String id;
  final String osId;
  final String equipamentoId;
  final String? ativoFixo;
  final String idCrachaTemporario;
  final String empresaId;
  final String tipoAgente;
  final StatusOS statusAtual;
  final String statusOriginal;
  final List<HistoricoEtapa> historicoEtapas;
  final Map<String, dynamic>? dadosTH;
  final Map<String, dynamic>? dadosRecarga;

  ItemOS({
    required this.id,
    required this.osId,
    required this.equipamentoId,
    this.ativoFixo,
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
      'ativoFixo': ativoFixo,
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
    String rawStatus = (json['status'] ?? json['statusAtual'] ?? '').toString();
    if (rawStatus.isEmpty || rawStatus == 'null') {
      rawStatus = (json['statusAtual'] ?? '').toString();
    }

    return ItemOS(
      id: id,
      osId: json['osId'] ?? '',
      equipamentoId: json['equipamentoId'] ?? '',
      ativoFixo: json['ativoFixo'],
      idCrachaTemporario: json['idCrachaTemporario'] ?? '',
      empresaId: json['empresaId'] ?? '',
      tipoAgente: json['tipoAgente'] ?? '',
      statusOriginal: rawStatus,
      statusAtual: _traduzirStatus(rawStatus),
      historicoEtapas: (json['historicoEtapas'] as List<dynamic>? ?? [])
          .map((h) => HistoricoEtapa.fromJson(h as Map<String, dynamic>))
          .toList(),
      dadosTH: json['dadosTH'] as Map<String, dynamic>?,
      dadosRecarga: json['dadosRecarga'] as Map<String, dynamic>?,
    );
  }

  // ─── NÍVEL DE MANUTENÇÃO ──────────────────────────────────────────────────
  // Regras:
  //   N1  = inspeção no cliente (não entra na fábrica — não usado neste relatório)
  //   N2  = recarga na fábrica
  //   N2P = recarga + pintura
  //   N3  = TH (ensaio hidrostático)
  //   N3P = TH + pintura
  static String derivarNivel(List<String> roteiro) {
    final temTH      = roteiro.contains('th') || roteiro.contains('ensaio_th');
    final temPintura = roteiro.contains('pintura');

    if (temTH && temPintura) return 'N3P';
    if (temTH)               return 'N3';
    if (temPintura)          return 'N2P';
    return 'N2'; // todo trabalho na fábrica é pelo menos N2
  }

  // ─── TRADUTOR DE STATUS ───────────────────────────────────────────────────
  static StatusOS _traduzirStatus(String? valorBanco) {
    if (valorBanco == null || valorBanco.isEmpty) return StatusOS.emCadastro;

    String s = valorBanco.toLowerCase();

    if (s.contains('limpeza'))    return StatusOS.aguardandoLimpeza;
    if (s.contains('descarga'))   return StatusOS.aguardandoDescarga;
    if (s.contains('lixa'))       return StatusOS.aguardandoLixa;
    if (s.contains('pintura'))    return StatusOS.aguardandoPintura;
    if (s.contains('manutencao')) return StatusOS.aguardandoManutencao;
    if (s.contains('valvula') || s.contains('saque')) return StatusOS.aguardandoSaque;
    if (s.contains('estanqueidade')) return StatusOS.aguardandoEstanqueidade;
    if (s.contains('hidro') || s.contains('th')) return StatusOS.aguardandoTH;
    if (s.contains('recarga'))    return StatusOS.aguardandoRecarga;
    if (s.contains('montagem'))   return StatusOS.aguardandoMontagem;
    if (s.contains('acabamento')) return StatusOS.aguardandoAcabamento;
    if (s.contains('expedicao'))  return StatusOS.aguardandoExpedicao;
    if (s.contains('finalizado') || s.contains('pronto') || s.contains('entregue'))
      return StatusOS.finalizado;
    if (s.contains('cadastro'))   return StatusOS.emCadastro;

    try {
      String limpo = s.replaceAll('_', '');
      return StatusOS.values.firstWhere(
              (e) => e.name.toLowerCase() == limpo);
    } catch (e) {
      return StatusOS.emProducao;
    }
  }
}