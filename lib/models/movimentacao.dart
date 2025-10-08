// Arquivo: lib/models/movimentacao.dart (VERSÃO FINAL E CORRIGIDA)

import 'package:cloud_firestore/cloud_firestore.dart'; // ---> MUDANÇA FINAL 1: Importamos para usar o Timestamp.

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

  final String empresaId;

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
    required this.empresaId,
  });

  Map<String, dynamic> toJson() => {
    'produtoId': produtoId,
    'produtoNome': produtoNome,
    'produtoCodigo': produtoCodigo,
    'tipo': tipo.name,
    'quantidade': quantidade,
    'data': Timestamp.fromDate(data), // ---> MUDANÇA FINAL 2: Convertendo para Timestamp ao salvar.
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
    'empresaId': empresaId,
  };

  factory Movimentacao.fromJson(Map<String, dynamic> json) {
    return Movimentacao(
      produtoId: json['produtoId'] ?? '',
      produtoNome: json['produtoNome'] ?? 'PRODUTO NÃO ENCONTRADO',
      produtoCodigo: json['produtoCodigo'] ?? 'N/A',
      tipo: TipoMovimentacao.values.byName(json['tipo']),
      quantidade: (json['quantidade'] as num).toDouble(),
      data: (json['data'] as Timestamp).toDate(), // ---> MUDANÇA FINAL 3: Lendo o Timestamp e convertendo de volta.
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
      empresaId: json['empresaId'] ?? '',
    );
  }
}