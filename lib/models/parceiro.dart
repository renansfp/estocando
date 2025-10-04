// Arquivo: lib/models/parceiro.dart (VERSÃO ATUALIZADA)

enum TipoParceiro {
  cliente,
  fornecedor,
}

class Parceiro {
  final String codigo;
  final TipoParceiro tipo;
  final String nome;
  final String cnpj;
  final String telefone;
  final String endereco;

  // ---> MUDANÇA 1: Adicionamos o campo para o ID da empresa. <---
  final String empresaId;

  // O "PORQUÊ": Removemos o campo 'id' daqui, pois o Firestore já nos
  // fornece um ID único para cada documento (o ID do documento).
  Parceiro({
    required this.codigo,
    required this.tipo,
    required this.nome,
    this.cnpj = '',
    this.telefone = '',
    this.endereco = '',
    // ---> MUDANÇA 2: Tornamos o campo obrigatório ao criar um novo parceiro. <---
    required this.empresaId,
  });

  Map<String, dynamic> toJson() => {
    'codigo': codigo,
    'tipo': tipo.name,
    'nome': nome,
    'cnpj': cnpj,
    'telefone': telefone,
    'endereco': endereco,
    // ---> MUDANÇA 3: Adicionamos ao "tradutor" para JSON, para salvar no Firebase. <---
    'empresaId': empresaId,
  };

  factory Parceiro.fromJson(Map<String, dynamic> json) {
    return Parceiro(
      codigo: json['codigo'] ?? '',
      tipo: TipoParceiro.values.byName(json['tipo'] ?? 'cliente'),
      nome: json['nome'] ?? '',
      cnpj: json['cnpj'] ?? '',
      telefone: json['telefone'] ?? '',
      endereco: json['endereco'] ?? '',
      // ---> MUDANÇA 4: Adicionamos ao "tradutor" que lê do Firebase. <---
      empresaId: json['empresaId'] ?? '',
    );
  }
}