// Salve como: lib/models/equipamento.dart
// (VERSÃO v6.0 - Com Origem do Selo e Última Troca de Pó)

import 'package:cloud_firestore/cloud_firestore.dart';

enum StatusEquipamento {
  ativo,
  emManutencao,
  baixado, // Condenado
}

class Equipamento {
  final String id;
  final String empresaId;
  final String clienteId;
  final String clienteNome;

  // Identificação
  final String numeroCilindro;
  final String ativoFixo;
  final String? numeroPintura;

  // Dados Técnicos
  final String tipo;
  final bool isAbcPremium;
  final String capacidade;
  final String capacidadeExtintora;
  final String? projeto;
  final String? pressaoTrabalho;

  // Dados de Manutenção / Histórico
  final String fabricante;
  final String normaFabricacao;
  final String anoFabricacao; // MM/AAAA
  final String? anoUltimoTH;  // MM/AAAA
  final String? ultimaRecarga; // MM/AAAA

  // Controle de Pó Químico
  final String? lotePo;       // 6 dígitos
  final bool substituirPo;    // Flag para indicar troca imediata

  // --- NOVOS CAMPOS ADICIONADOS ---
  final String? ultimaTrocaPo; // MM/AAAA (Data da troca física do pó)
  final String? origemSelo;    // 'TERCEIROS', 'NOSSA', 'FABRICA'

  // Controle de Condenação
  final String? motivoCondenacao;

  final StatusEquipamento status;

  Equipamento({
    required this.id,
    required this.empresaId,
    required this.clienteId,
    required this.clienteNome,
    required this.numeroCilindro,
    required this.ativoFixo,
    this.numeroPintura,
    required this.tipo,
    this.isAbcPremium = false,
    required this.capacidade,
    required this.capacidadeExtintora,
    this.projeto,
    this.pressaoTrabalho,
    required this.fabricante,
    required this.normaFabricacao,
    required this.anoFabricacao,
    this.anoUltimoTH,
    this.ultimaRecarga,
    this.lotePo,
    this.substituirPo = false,
    // --- Novos no Construtor ---
    this.ultimaTrocaPo,
    this.origemSelo,

    this.motivoCondenacao,
    this.status = StatusEquipamento.ativo,
  });

  Map<String, dynamic> toJson() => {
    'empresaId': empresaId,
    'clienteId': clienteId,
    'clienteNome': clienteNome,
    'numeroCilindro': numeroCilindro,
    'ativoFixo': ativoFixo,
    'numeroPintura': numeroPintura,
    'tipo': tipo,
    'isAbcPremium': isAbcPremium,
    'capacidade': capacidade,
    'capacidadeExtintora': capacidadeExtintora,
    'projeto': projeto,
    'pressaoTrabalho': pressaoTrabalho,
    'fabricante': fabricante,
    'normaFabricacao': normaFabricacao,
    'anoFabricacao': anoFabricacao,
    'anoUltimoTH': anoUltimoTH,
    'ultimaRecarga': ultimaRecarga,
    'lotePo': lotePo,
    'substituirPo': substituirPo,
    // --- Novos no JSON ---
    'ultimaTrocaPo': ultimaTrocaPo,
    'origemSelo': origemSelo,

    'motivoCondenacao': motivoCondenacao,
    'status': status.name,
  };

  factory Equipamento.fromJson(Map<String, dynamic> json, String docId) {
    return Equipamento(
      id: docId,
      empresaId: json['empresaId'] ?? '',
      clienteId: json['clienteId'] ?? '',
      clienteNome: json['clienteNome'] ?? '',
      numeroCilindro: json['numeroCilindro'] ?? '',
      ativoFixo: json['ativoFixo'] ?? '',
      numeroPintura: json['numeroPintura'],
      tipo: json['tipo'] ?? 'PQS',
      isAbcPremium: json['isAbcPremium'] ?? false,
      capacidade: json['capacidade'] ?? '',
      capacidadeExtintora: json['capacidadeExtintora'] ?? '',
      projeto: json['projeto'],
      pressaoTrabalho: json['pressaoTrabalho'],
      fabricante: json['fabricante'] ?? '',
      normaFabricacao: json['normaFabricacao'] ?? '',
      anoFabricacao: json['anoFabricacao'] ?? '',
      anoUltimoTH: json['anoUltimoTH']?.toString(),
      ultimaRecarga: json['ultimaRecarga'],
      lotePo: json['lotePo'],
      substituirPo: json['substituirPo'] ?? false,

      // --- Novos na Leitura ---
      ultimaTrocaPo: json['ultimaTrocaPo'],
      origemSelo: json['origemSelo'],

      motivoCondenacao: json['motivoCondenacao'],
      status: StatusEquipamento.values.firstWhere(
              (e) => e.name == (json['status'] ?? 'ativo'),
          orElse: () => StatusEquipamento.ativo),
    );
  }
}