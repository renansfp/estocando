// Arquivo: lib/models/parceiro.dart
// (VERSÃO COM ENDEREÇO COMPLETO)

enum TipoParceiro {
  cliente,
  fornecedor,
}

class Parceiro {
  final String id;
  final String codigo;
  final TipoParceiro tipo;
  final String nome;
  final String cnpj;

  // Novos campos adicionados:
  final String telefone;
  final String endereco;
  final String cidade;
  final String estado;
  final String cep;

  final String empresaId;

  // Código de registro nos órgãos de fiscalização (ex: CBMERJ)
  final String sirla;

  Parceiro({
    required this.id,
    required this.codigo,
    required this.tipo,
    required this.nome,
    this.cnpj = '',
    this.telefone = '',
    this.endereco = '',
    this.cidade = '',
    this.estado = '',
    this.cep = '',
    required this.empresaId,
    this.sirla = '',
  });

  Map<String, dynamic> toJson() => {
    'codigo': codigo,
    'tipo': tipo.name,
    'nome': nome,
    'cnpj': cnpj,
    'telefone': telefone,
    'endereco': endereco,
    'cidade': cidade,
    'estado': estado,
    'cep': cep,
    'empresaId': empresaId,
    'sirla': sirla,
  };

  factory Parceiro.fromJson(Map<String, dynamic> json, String documentId) {
    return Parceiro(
      id: documentId,
      codigo: json['codigo'] ?? '',
      tipo: TipoParceiro.values.byName(json['tipo'] ?? 'cliente'),
      nome: json['nome'] ?? '',
      cnpj: json['cnpj'] ?? '',
      telefone: json['telefone'] ?? '',
      endereco: json['endereco'] ?? '',
      cidade: json['cidade'] ?? '',
      estado: json['estado'] ?? '',
      cep: json['cep'] ?? '',
      empresaId: json['empresaId'] ?? '',
      sirla: json['sirla'] ?? '',
    );
  }
}