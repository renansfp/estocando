// Arquivo: lib/models/movimentacao.dart (VERSÃO ATUALIZADA)

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

  // ---> MUDANÇA 1: Adicionamos o campo para o ID da empresa. <---
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
    // ---> MUDANÇA 2: Tornamos o campo obrigatório ao criar uma nova movimentação. <---
    required this.empresaId,
  });

  Map<String, dynamic> toJson() => {
    'produtoId': produtoId,
    'produtoNome': produtoNome,
    'produtoCodigo': produtoCodigo,
    'tipo': tipo.name,
    'quantidade': quantidade,
    'data': data.toIso8601String(),
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
    // ---> MUDANÇA 3: Adicionamos ao "tradutor" para JSON (salvar no Firebase). <---
    'empresaId': empresaId,
  };

  factory Movimentacao.fromJson(Map<String, dynamic> json) {
    return Movimentacao(
      produtoId: json['produtoId'] ?? '',
      produtoNome: json['produtoNome'] ?? 'PRODUTO NÃO ENCONTRADO',
      produtoCodigo: json['produtoCodigo'] ?? 'N/A',
      tipo: TipoMovimentacao.values.byName(json['tipo']),
      quantidade: (json['quantidade'] as num).toDouble(),
      data: DateTime.parse(json['data']),
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
      // ---> MUDANÇA 4: Adicionamos ao "tradutor" que lê do Firebase. <---
      empresaId: json['empresaId'] ?? '',
    );
  }
}