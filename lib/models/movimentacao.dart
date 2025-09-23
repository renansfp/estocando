// Arquivo: lib/models/movimentacao.dart
// VERSÃO REFATORADA PARA FIREBASE

// Não precisamos mais de nenhum import do sistema antigo!

enum TipoMovimentacao {
  entrada,
  saida,
}

class Movimentacao {
  // --- CAMPOS MODIFICADOS ---
  // Substituímos o objeto 'Produto' por referências diretas.
  final String produtoId;       // ID do documento do produto no Firestore
  final String produtoNome;     // Cópia do nome do produto no momento da movimentação
  final String produtoCodigo;   // Cópia do código do produto

  final TipoMovimentacao tipo;
  final int quantidade;
  final DateTime data;
  final String? subTipo;
  final String? numeroNF;
  final String? numeroOS;
  final String? nomeFornecedor;
  final String? nomeCliente;
  final String? nomeDevolucao;
  final String? motivoAcerto;
  final String? numeroAG;
  final String? nomeColaborador;
  final String? centroDeCusto;

  Movimentacao({
    // Construtor atualizado
    required this.produtoId,
    required this.produtoNome,
    required this.produtoCodigo,
    required this.tipo,
    required this.quantidade,
    required this.data,
    this.subTipo,
    this.numeroNF,
    this.numeroOS,
    this.nomeFornecedor,
    this.nomeCliente,
    this.nomeDevolucao,
    this.motivoAcerto,
    this.numeroAG,
    this.nomeColaborador,
    this.centroDeCusto,
  });

  // --- toJson ATUALIZADO ---
  // Salva as referências do produto em vez de um único nome.
  Map<String, dynamic> toJson() => {
    'produtoId': produtoId,
    'produtoNome': produtoNome,
    'produtoCodigo': produtoCodigo,
    'tipo': tipo.name, // .name converte o enum para String (ex: 'entrada')
    'quantidade': quantidade,
    'data': data.toIso8601String(), // Formato padrão para datas
    'subTipo': subTipo,
    'numeroNF': numeroNF,
    'numeroOS': numeroOS,
    'nomeFornecedor': nomeFornecedor,
    'nomeCliente': nomeCliente,
    'nomeDevolucao': nomeDevolucao,
    'motivoAcerto': motivoAcerto,
    'numeroAG': numeroAG,
    'nomeColaborador': nomeColaborador,
    'centroDeCusto': centroDeCusto,
  };

  // --- fromJson ATUALIZADO ---
  // Agora é muito mais simples! Apenas lê os dados, sem precisar pesquisar em listas.
  factory Movimentacao.fromJson(Map<String, dynamic> json) {
    return Movimentacao(
      produtoId: json['produtoId'] ?? '', // Usa ?? para evitar erros se o campo não existir
      produtoNome: json['produtoNome'] ?? 'PRODUTO NÃO ENCONTRADO',
      produtoCodigo: json['produtoCodigo'] ?? 'N/A',
      tipo: TipoMovimentacao.values.byName(json['tipo']),
      quantidade: json['quantidade'],
      data: DateTime.parse(json['data']),
      subTipo: json['subTipo'],
      numeroNF: json['numeroNF'],
      numeroOS: json['numeroOS'],
      nomeFornecedor: json['nomeFornecedor'],
      nomeCliente: json['nomeCliente'],
      nomeDevolucao: json['nomeDevolucao'],
      motivoAcerto: json['motivoAcerto'],
      numeroAG: json['numeroAG'],
      nomeColaborador: json['nomeColaborador'],
      centroDeCusto: json['centroDeCusto'],
    );
  }
}