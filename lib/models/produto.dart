// Arquivo: lib/models/produto.dart

class Produto {
  String codigo;
  String nome;
  String tipo;
  String grupo;
  int estoqueMinimo;
  int estoqueMaximo;
  String unidade;
  double valor;
  int quantidade;
  String? numeroSC; // <-- NOSSO NOVO CAMPO! (Opcional)

  Produto({
    required this.codigo,
    required this.nome,
    required this.tipo,
    required this.grupo,
    required this.estoqueMinimo,
    required this.estoqueMaximo,
    required this.unidade,
    required this.valor,
    this.quantidade = 0,
    this.numeroSC,
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
    'numeroSC': numeroSC, // <-- Adicionado ao "tradutor"
  };

  factory Produto.fromJson(Map<String, dynamic> json) {
    return Produto(
      codigo: json['codigo'] ?? '',
      nome: json['nome'] ?? '',
      tipo: json['tipo'] ?? '',
      grupo: json['grupo'] ?? '',
      estoqueMinimo: json['estoqueMinimo'] ?? 0,
      estoqueMaximo: json['estoqueMaximo'] ?? 0,
      unidade: json['unidade'] ?? '',
      valor: (json['valor'] ?? 0.0).toDouble(),
      quantidade: json['quantidade'] ?? 0,
      numeroSC: json['numeroSC'], // <-- Adicionado ao "tradutor"
    );
  }
}