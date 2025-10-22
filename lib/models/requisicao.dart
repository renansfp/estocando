// CÓDIGO COMPLETO - models/requisicao.dart (v. 22/10/2025 - com nomeCliente)

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
    return ItemRequisicao(
      produtoId: json['produtoId'] as String? ?? 'ID_INVALIDO',
      produtoCodigo: json['produtoCodigo'] as String? ?? 'N/A',
      produtoNome: json['produtoNome'] as String? ?? 'Nome Inválido',
      quantidadeSolicitada: (json['quantidadeSolicitada'] as num? ?? 0).toDouble(),
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
  final String? agencia;

  // ---> MUDANÇA 1: Adicionamos o campo do cliente aqui <---
  final String? nomeCliente;

  // Campos de Atendimento/Cancelamento
  final String? atendidoPorId;
  final String? atendidoPorNome;
  final DateTime? dataAtendimento;
  final String? motivoCancelamento;

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

    // ---> MUDANÇA 2: Adicionamos ao construtor <---
    this.nomeCliente,

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

      // ---> MUDANÇA 3: Adicionamos ao JSON <---
      'nomeCliente': nomeCliente,

      'atendidoPorId': atendidoPorId,
      'atendidoPorNome': atendidoPorNome,
      'dataAtendimento': dataAtendimento != null ? Timestamp.fromDate(dataAtendimento!) : null,
      'motivoCancelamento': motivoCancelamento,
    };
  }

  factory Requisicao.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final List<dynamic> itensData = data['itens'] is List ? data['itens'] as List<dynamic> : [];
    final List<ItemRequisicao> itensLista = itensData
        .where((itemData) => itemData is Map<String, dynamic>)
        .map((itemData) => ItemRequisicao.fromJson(itemData as Map<String, dynamic>))
        .toList();

    return Requisicao(
      id: doc.id,
      empresaId: data['empresaId'] as String? ?? 'EMPRESA_INVALIDA',
      solicitanteId: data['solicitanteId'] as String? ?? 'USER_INVALIDO',
      solicitanteNome: data['solicitanteNome'] as String? ?? 'Nome Inválido',
      dataSolicitacao: (data['dataSolicitacao'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'INVALIDO',
      itens: itensLista,
      subTipo: data['subTipo'] as String? ?? 'OS',
      numeroOS: data['numeroOS'] as String?,
      nomeColaborador: data['nomeColaborador'] as String?,
      centroDeCusto: data['centroDeCusto'] as String?,
      numeroPedido: data['numeroPedido'] as String?,
      numeroNF: data['numeroNF'] as String?,
      agencia: data['agencia'] as String?,

      // ---> MUDANÇA 4: Adicionamos ao FromFirestore <---
      nomeCliente: data['nomeCliente'] as String?,

      atendidoPorId: data['atendidoPorId'] as String?,
      atendidoPorNome: data['atendidoPorNome'] as String?,
      dataAtendimento: (data['dataAtendimento'] as Timestamp?)?.toDate(),
      motivoCancelamento: data['motivoCancelamento'] as String?,
    );
  }
}