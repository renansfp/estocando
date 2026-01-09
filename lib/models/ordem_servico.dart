import 'package:cloud_firestore/cloud_firestore.dart';

// -----------------------------------------------------------------------------
// 1. O ENUM DE LOTE (STATUS DA CAIXA)
// -----------------------------------------------------------------------------
enum StatusLoteOS {
  emCadastro,
  emProducao,              // Status Genérico para quando está na fábrica
  aguardandoSincronizacao, // Opcional
  finalizada,              // Saiu da fábrica
  cancelada,
}

// -----------------------------------------------------------------------------
// 2. A ORDEM DE SERVIÇO (A CAIXA)
// -----------------------------------------------------------------------------
class OrdemServico {
  final String id;
  final String? numeroOS;
  final String empresaId;
  final String clienteId;
  final String clienteNome;

  final StatusLoteOS statusLote; // Onde a caixa está

  final DateTime dataEntrada;
  final DateTime? dataSaida;
  final String usuarioNomeEntrada;

  OrdemServico({
    required this.id,
    this.numeroOS,
    required this.empresaId,
    required this.clienteId,
    required this.clienteNome,
    required this.statusLote,
    required this.dataEntrada,
    this.dataSaida,
    required this.usuarioNomeEntrada,
  });

  Map<String, dynamic> toJson() {
    return {
      'numeroOS': numeroOS,
      'empresaId': empresaId,
      'clienteId': clienteId,
      'clienteNome': clienteNome,
      'statusLote': statusLote.name,
      'dataEntrada': Timestamp.fromDate(dataEntrada),
      'dataSaida': dataSaida != null ? Timestamp.fromDate(dataSaida!) : null,
      'usuarioNomeEntrada': usuarioNomeEntrada,
    };
  }

  // --- O "TRADUTOR" DA OS (BLINDADO) ---
  factory OrdemServico.fromJson(Map<String, dynamic> json, String id) {

    // 1. Pega o texto cru do banco
    String statusTexto = (json['statusLote'] ?? '').toString();
    StatusLoteOS statusSeguro;

    try {
      // 2. Tenta encontrar o nome exato no Enum
      statusSeguro = StatusLoteOS.values.byName(statusTexto);
    } catch (e) {
      // 3. SE DER ERRO (ex: "na_descarga"), FAZ A TRADUÇÃO MANUAL:

      String s = statusTexto.toLowerCase();

      if (s == 'finalizado' || s == 'pronto' || s == 'entregue') {
        statusSeguro = StatusLoteOS.finalizada;
      }
      else if (s == 'cancelado') {
        statusSeguro = StatusLoteOS.cancelada;
      }
      else if (s == 'em_cadastro' || s == 'criado') {
        statusSeguro = StatusLoteOS.emCadastro;
      }
      // Qualquer coisa relacionada a produção ("na_descarga", "aguardando_limpeza", etc)
      // vira "Em Produção" para a OS (Lote).
      else {
        // Log para você saber o que aconteceu (opcional)
        // print("⚠️ Status de Lote '$statusTexto' convertido para 'emProducao'");
        statusSeguro = StatusLoteOS.emProducao;
      }
    }

    return OrdemServico(
      id: id,
      numeroOS: json['numeroOS'],
      empresaId: json['empresaId'] ?? '',
      clienteId: json['clienteId'] ?? '',
      clienteNome: json['clienteNome'] ?? 'Cliente não identificado',
      statusLote: statusSeguro,
      dataEntrada: (json['dataEntrada'] as Timestamp? ?? Timestamp.now()).toDate(),
      dataSaida: (json['dataSaida'] as Timestamp?)?.toDate(),
      usuarioNomeEntrada: json['usuarioNomeEntrada'] ?? '---',
    );
  }
}