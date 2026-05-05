// lib/models/requisicao.dart

import 'package:cloud_firestore/cloud_firestore.dart';

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

  Map<String, dynamic> toJson() => {
    'produtoId': produtoId,
    'produtoCodigo': produtoCodigo,
    'produtoNome': produtoNome,
    'quantidadeSolicitada': quantidadeSolicitada,
  };

  factory ItemRequisicao.fromJson(Map<String, dynamic> json) {
    return ItemRequisicao(
      produtoId: json['produtoId'] as String? ?? 'ID_INVALIDO',
      produtoCodigo: json['produtoCodigo'] as String? ?? 'N/A',
      produtoNome: json['produtoNome'] as String? ?? 'Nome Inválido',
      quantidadeSolicitada:
      (json['quantidadeSolicitada'] as num? ?? 0).toDouble(),
    );
  }
}

class Requisicao {
  final String? id;
  final String empresaId;
  final String solicitanteId;
  final String solicitanteNome;
  final DateTime dataSolicitacao;
  final String status;
  final List<ItemRequisicao> itens;

  final String subTipo;
  final String? numeroOS;
  final String? nomeColaborador;
  final String? centroDeCusto;
  final String? numeroPedido;
  final String? numeroNF;
  final String? agencia;
  final String? nomeCliente;

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
    this.nomeCliente,
    this.atendidoPorId,
    this.atendidoPorNome,
    this.dataAtendimento,
    this.motivoCancelamento,
  });

  Map<String, dynamic> toJson() => {
    'empresaId': empresaId,
    'solicitanteId': solicitanteId,
    'solicitanteNome': solicitanteNome,
    'dataSolicitacao': Timestamp.fromDate(dataSolicitacao),
    'status': status,
    'itens': itens.map((i) => i.toJson()).toList(),
    'subTipo': subTipo,
    'numeroOS': numeroOS,
    'nomeColaborador': nomeColaborador,
    'centroDeCusto': centroDeCusto,
    'numeroPedido': numeroPedido,
    'numeroNF': numeroNF,
    'agencia': agencia,
    'nomeCliente': nomeCliente,
    'atendidoPorId': atendidoPorId,
    'atendidoPorNome': atendidoPorNome,
    'dataAtendimento':
    dataAtendimento != null ? Timestamp.fromDate(dataAtendimento!) : null,
    'motivoCancelamento': motivoCancelamento,
  };

  /// Usado pelo repository — converte Map<String, dynamic> (com 'id' incluso) em Requisicao.
  factory Requisicao.fromMap(Map<String, dynamic> data, String id) {
    final itensData =
    data['itens'] is List ? data['itens'] as List<dynamic> : [];
    final itensLista = itensData
        .whereType<Map<String, dynamic>>()
        .map((m) => ItemRequisicao.fromJson(m))
        .toList();

    return Requisicao(
      id: id,
      empresaId: data['empresaId'] as String? ?? 'EMPRESA_INVALIDA',
      solicitanteId: data['solicitanteId'] as String? ?? 'USER_INVALIDO',
      solicitanteNome: data['solicitanteNome'] as String? ?? 'Nome Inválido',
      dataSolicitacao:
      (data['dataSolicitacao'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'INVALIDO',
      itens: itensLista,
      subTipo: data['subTipo'] as String? ?? 'OS',
      numeroOS: data['numeroOS'] as String?,
      nomeColaborador: data['nomeColaborador'] as String?,
      centroDeCusto: data['centroDeCusto'] as String?,
      numeroPedido: data['numeroPedido'] as String?,
      numeroNF: data['numeroNF'] as String?,
      agencia: data['agencia'] as String?,
      nomeCliente: data['nomeCliente'] as String?,
      atendidoPorId: data['atendidoPorId'] as String?,
      atendidoPorNome: data['atendidoPorNome'] as String?,
      dataAtendimento: (data['dataAtendimento'] as Timestamp?)?.toDate(),
      motivoCancelamento: data['motivoCancelamento'] as String?,
    );
  }

  /// Mantido para compatibilidade com código existente.
  factory Requisicao.fromFirestore(DocumentSnapshot doc) {
    return Requisicao.fromMap(
      doc.data() as Map<String, dynamic>? ?? {},
      doc.id,
    );
  }
}