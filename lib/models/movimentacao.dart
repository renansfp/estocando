// Arquivo: lib/models/movimentacao.dart (VERSÃO FINAL E CORRIGIDA)

import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoMovimentacao {
  entrada,
  saida,
}

class Movimentacao {
  final String produtoId;
  final String produtoNome;
  final String produtoCodigo;

  final TipoMovimentacao tipo;
  final double quantidade;
  final DateTime data;
  final String? subTipo;

  final double? valorUnitarioMovimentacao;

  final String? numeroNF;
  final String? numeroOS;
  final String? nomeFornecedor;
  final String? nomeCliente;
  final String? nomeDevolucao;
  final String? motivoAcerto;
  final String? numeroAG;
  final String? nomeColaborador;
  final String? centroDeCusto;

  final String? numeroPedido;

  final String empresaId;

  // ─── Auditoria: quem lançou ───────────────────────────────────────────────
  final String? usuarioId;
  final String? usuarioNome;

  // ─── Cancelamento: rastro de estorno ─────────────────────────────────────
  final bool cancelada;
  final String? canceladaPor;
  final DateTime? canceladaEm;

  Movimentacao({
    required this.produtoId,
    required this.produtoNome,
    required this.produtoCodigo,
    required this.tipo,
    required this.quantidade,
    required this.data,
    this.subTipo,
    this.valorUnitarioMovimentacao,
    this.numeroNF,
    this.numeroOS,
    this.nomeFornecedor,
    this.nomeCliente,
    this.nomeDevolucao,
    this.motivoAcerto,
    this.numeroAG,
    this.nomeColaborador,
    this.centroDeCusto,
    this.numeroPedido,
    required this.empresaId,
    this.usuarioId,
    this.usuarioNome,
    this.cancelada = false,
    this.canceladaPor,
    this.canceladaEm,
  });

  Map<String, dynamic> toJson() => {
    'produtoId': produtoId,
    'produtoNome': produtoNome,
    'produtoCodigo': produtoCodigo,
    'tipo': tipo.name,
    'quantidade': quantidade,
    'data': Timestamp.fromDate(data),
    'subTipo': subTipo,
    'valorUnitarioMovimentacao': valorUnitarioMovimentacao,
    'numeroNF': numeroNF,
    'numeroOS': numeroOS,
    'nomeFornecedor': nomeFornecedor,
    'nomeCliente': nomeCliente,
    'nomeDevolucao': nomeDevolucao,
    'motivoAcerto': motivoAcerto,
    'numeroAG': numeroAG,
    'nomeColaborador': nomeColaborador,
    'centroDeCusto': centroDeCusto,
    'numeroPedido': numeroPedido,
    'empresaId': empresaId,
    'usuarioId': usuarioId,
    'usuarioNome': usuarioNome,
    'cancelada': cancelada,
    'canceladaPor': canceladaPor,
    'canceladaEm': canceladaEm != null ? Timestamp.fromDate(canceladaEm!) : null,
  };

  factory Movimentacao.fromJson(Map<String, dynamic> json) {
    return Movimentacao(
      produtoId: json['produtoId'] ?? '',
      produtoNome: json['produtoNome'] ?? 'PRODUTO NÃO ENCONTRADO',
      produtoCodigo: json['produtoCodigo'] ?? 'N/A',
      tipo: TipoMovimentacao.values.byName(json['tipo']),
      quantidade: (json['quantidade'] as num).toDouble(),
      data: (json['data'] as Timestamp).toDate(),
      subTipo: json['subTipo'],
      valorUnitarioMovimentacao:
      (json['valorUnitarioMovimentacao'] as num?)?.toDouble(),
      numeroNF: json['numeroNF'],
      numeroOS: json['numeroOS'],
      nomeFornecedor: json['nomeFornecedor'],
      nomeCliente: json['nomeCliente'],
      nomeDevolucao: json['nomeDevolucao'],
      motivoAcerto: json['motivoAcerto'],
      numeroAG: json['numeroAG'],
      nomeColaborador: json['nomeColaborador'],
      centroDeCusto: json['centroDeCusto'],
      numeroPedido: json['numeroPedido'],
      empresaId: json['empresaId'] ?? '',
      usuarioId: json['usuarioId'],
      usuarioNome: json['usuarioNome'],
      cancelada: json['cancelada'] as bool? ?? false,
      canceladaPor: json['canceladaPor'],
      canceladaEm: json['canceladaEm'] != null
          ? (json['canceladaEm'] as Timestamp).toDate()
          : null,
    );
  }
}