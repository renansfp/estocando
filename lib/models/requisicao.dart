// CÓDIGO COMPLETO - models/requisicao.dart (v. 20/10/2025 - com motivoCancelamento)

import 'package:cloud_firestore/cloud_firestore.dart';

// Esta classe define UM item dentro da lista de pedidos.
class ItemRequisicao {
  final String produtoId;
  final String produtoCodigo;
  final String produtoNome;
  final double quantidadeSolicitada;

  ItemRequisicao({
    required this.produtoId,
    required this.produtoCodigo,
    required this.produtoNome,
    required this.quantidadeSolicitada,
  });

  Map<String, dynamic> toJson() {
    return {
      'produtoId': produtoId,
      'produtoCodigo': produtoCodigo,
      'produtoNome': produtoNome,
      'quantidadeSolicitada': quantidadeSolicitada,
    };
  }

  factory ItemRequisicao.fromJson(Map<String, dynamic> json) {
    // Adiciona verificação para campos que podem ser nulos em dados antigos
    return ItemRequisicao(
      produtoId: json['produtoId'] as String? ?? 'ID_INVALIDO', // Valor padrão se nulo
      produtoCodigo: json['produtoCodigo'] as String? ?? 'N/A', // Valor padrão se nulo
      produtoNome: json['produtoNome'] as String? ?? 'Nome Inválido', // Valor padrão se nulo
      quantidadeSolicitada: (json['quantidadeSolicitada'] as num? ?? 0).toDouble(), // Valor padrão se nulo
    );
  }
}

// Esta é a classe da Requisição COMPLETA (a "comanda")
class Requisicao {
  final String? id; // O ID do documento no Firebase (opcional)
  final String empresaId;
  final String solicitanteId;
  final String solicitanteNome;
  final DateTime dataSolicitacao;
  final String status; // "PENDENTE", "ATENDIDO", "CANCELADO"
  final List<ItemRequisicao> itens;

  // Campos de Contexto
  final String subTipo;
  final String? numeroOS;
  final String? nomeColaborador;
  final String? centroDeCusto;
  final String? numeroPedido;
  final String? numeroNF;
  final String? agencia; // Renomeado de numeroAG para agencia para consistência

  // Campos de Atendimento/Cancelamento
  final String? atendidoPorId; // Pode ser quem atendeu OU quem cancelou
  final String? atendidoPorNome; // Pode ser quem atendeu OU quem cancelou
  final DateTime? dataAtendimento; // Pode ser a data do atendimento OU do cancelamento
  final String? motivoCancelamento; // Motivo se o status for "CANCELADO"

  Requisicao({
    this.id,
    required this.empresaId,
    required this.solicitanteId,
    required this.solicitanteNome,
    required this.dataSolicitacao,
    required this.status,
    required this.itens,

    required this.subTipo,
    this.numeroOS,
    this.nomeColaborador,
    this.centroDeCusto,
    this.numeroPedido,
    this.numeroNF,
    this.agencia,

    this.atendidoPorId,
    this.atendidoPorNome,
    this.dataAtendimento,
    this.motivoCancelamento,
  });

  Map<String, dynamic> toJson() {
    return {
      'empresaId': empresaId,
      'solicitanteId': solicitanteId,
      'solicitanteNome': solicitanteNome,
      'dataSolicitacao': Timestamp.fromDate(dataSolicitacao),
      'status': status,
      'itens': itens.map((item) => item.toJson()).toList(),

      'subTipo': subTipo,
      'numeroOS': numeroOS,
      'nomeColaborador': nomeColaborador,
      'centroDeCusto': centroDeCusto,
      'numeroPedido': numeroPedido,
      'numeroNF': numeroNF,
      'agencia': agencia,

      'atendidoPorId': atendidoPorId,
      'atendidoPorNome': atendidoPorNome,
      'dataAtendimento': dataAtendimento != null ? Timestamp.fromDate(dataAtendimento!) : null,
      'motivoCancelamento': motivoCancelamento,
    };
  }

  factory Requisicao.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {}; // Garante que data não seja nulo

    // Converte a lista de Maps de volta para uma lista de Objetos ItemRequisicao
    // Adiciona verificação para 'itens' nulo ou não ser uma lista
    final List<dynamic> itensData = data['itens'] is List ? data['itens'] as List<dynamic> : [];
    final List<ItemRequisicao> itensLista = itensData
        .where((itemData) => itemData is Map<String, dynamic>) // Filtra itens inválidos
        .map((itemData) => ItemRequisicao.fromJson(itemData as Map<String, dynamic>))
        .toList();

    return Requisicao(
      id: doc.id,
      // Adiciona valores padrão para campos obrigatórios caso não existam (segurança extra)
      empresaId: data['empresaId'] as String? ?? 'EMPRESA_INVALIDA',
      solicitanteId: data['solicitanteId'] as String? ?? 'USER_INVALIDO',
      solicitanteNome: data['solicitanteNome'] as String? ?? 'Nome Inválido',
      dataSolicitacao: (data['dataSolicitacao'] as Timestamp?)?.toDate() ?? DateTime.now(), // Usa data atual se nulo
      status: data['status'] as String? ?? 'INVALIDO',

      itens: itensLista,

      subTipo: data['subTipo'] as String? ?? 'OS', // Define 'OS' como padrão se não existir
      numeroOS: data['numeroOS'] as String?,
      nomeColaborador: data['nomeColaborador'] as String?,
      centroDeCusto: data['centroDeCusto'] as String?,
      numeroPedido: data['numeroPedido'] as String?,
      numeroNF: data['numeroNF'] as String?,
      agencia: data['agencia'] as String?,

      atendidoPorId: data['atendidoPorId'] as String?,
      atendidoPorNome: data['atendidoPorNome'] as String?,
      dataAtendimento: (data['dataAtendimento'] as Timestamp?)?.toDate(),
      motivoCancelamento: data['motivoCancelamento'] as String?,
    );
  }
}