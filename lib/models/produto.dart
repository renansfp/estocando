// Arquivo: lib/models/produto.dart (VERSÃO ATUALIZADA)

class Produto {
  String codigo;
  String nome;
  String tipo;
  String grupo;
  // O "PORQUÊ": Trocamos para double para manter a consistência com o resto do app
  // que agora aceita quantidades decimais.
  double estoqueMinimo;
  double estoqueMaximo;
  String unidade;
  double valor;
  double quantidade; // Trocado para double
  String? numeroSC;

  // ---> MUDANÇA 1: Adicionamos o campo para o ID da empresa. <---
  final String empresaId;

  Produto({
    required this.codigo,
    required this.nome,
    required this.tipo,
    required this.grupo,
    required this.estoqueMinimo,
    required this.estoqueMaximo,
    required this.unidade,
    required this.valor,
    this.quantidade = 0.0, // Padrão agora é 0.0
    this.numeroSC,
    // ---> MUDANÇA 2: Tornamos o campo obrigatório ao criar um novo produto. <---
    required this.empresaId,
  });

  Map<String, dynamic> toJson() => {
    'codigo': codigo,
    'nome': nome,
    'tipo': tipo,
    'grupo': grupo,
    'estoqueMinimo': estoqueMinimo,
    'estoqueMaximo': estoqueMaximo,
    'unidade': unidade,
    'valor': valor,
    'quantidade': quantidade,
    'numeroSC': numeroSC,
    // ---> MUDANÇA 3: Adicionamos ao "tradutor" para JSON, para salvar no Firebase. <---
    'empresaId': empresaId,
  };

  factory Produto.fromJson(Map<String, dynamic> json) {
    return Produto(
      codigo: json['codigo'] ?? '',
      nome: json['nome'] ?? '',
      tipo: json['tipo'] ?? '',
      grupo: json['grupo'] ?? '',
      // Garantimos que os valores sejam lidos como double
      estoqueMinimo: (json['estoqueMinimo'] ?? 0.0).toDouble(),
      estoqueMaximo: (json['estoqueMaximo'] ?? 0.0).toDouble(),
      unidade: json['unidade'] ?? '',
      valor: (json['valor'] ?? 0.0).toDouble(),
      quantidade: (json['quantidade'] ?? 0.0).toDouble(),
      numeroSC: json['numeroSC'],
      // ---> MUDANÇA 4: Adicionamos ao "tradutor" que lê do Firebase. <---
      // Usamos '?? ''` para garantir que, se um produto antigo não tiver o campo, o app não quebre.
      empresaId: json['empresaId'] ?? '',
    );
  }
}