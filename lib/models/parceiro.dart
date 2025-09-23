// Arquivo: lib/models/parceiro.dart (Com o campo 'codigo')

enum TipoParceiro {
  cliente,
  fornecedor,
}

class Parceiro {
  final String id;
  final String codigo; // <-- NOSSO NOVO CAMPO!
  final TipoParceiro tipo;
  final String nome;
  final String cnpj;
  final String telefone;
  final String endereco;

  Parceiro({
    required this.id,
    required this.codigo, // <-- Adicionado ao construtor
    required this.tipo,
    required this.nome,
    this.cnpj = '',
    this.telefone = '',
    this.endereco = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'codigo': codigo, // <-- Adicionado ao toJson
    'tipo': tipo.name,
    'nome': nome,
    'cnpj': cnpj,
    'telefone': telefone,
    'endereco': endereco,
  };

  factory Parceiro.fromJson(Map<String, dynamic> json) {
    return Parceiro(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      codigo: json['codigo'] ?? '', // <-- Adicionado ao fromJson
      tipo: TipoParceiro.values.byName(json['tipo'] ?? 'cliente'),
      nome: json['nome'] ?? '',
      cnpj: json['cnpj'] ?? '',
      telefone: json['telefone'] ?? '',
      endereco: json['endereco'] ?? '',
    );
  }
}