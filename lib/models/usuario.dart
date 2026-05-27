// lib/models/usuario.dart

class Usuario {
  final String uid;
  final String email;
  final String nome;
  final String empresaId;
  final String permissao;
  final String? status;

  // Lista de estações liberadas para operadores.
  // Admin e líder têm acesso implícito a tudo — este campo é ignorado para eles.
  // Operadores começam com lista vazia e vão desbloqueando conforme são treinados.
  final List<String> estacoesLiberadas;

  Usuario({
    required this.uid,
    required this.email,
    required this.nome,
    required this.empresaId,
    required this.permissao,
    this.status,
    this.estacoesLiberadas = const [],
  });

  // ── HELPERS DE PERFIL ─────────────────────────────────────────────────────
  //
  // Use sempre esses getters no app em vez de comparar string diretamente.
  // Ex: if (usuario.isAdmin) { ... }  em vez de  if (usuario.permissao == 'admin')

  bool get isAdmin     => permissao == 'admin';
  bool get isLider     => permissao == 'lider';
  bool get isOperador  => permissao == 'operador';
  bool get isAlmoxarife => permissao == 'almoxarife';
  bool get isVendedor  => permissao == 'vendedor';

  // Admin e líder têm acesso total à produção sem precisar de lista
  bool get acessoTotalProducao => isAdmin || isLider;

  // Verifica se o usuário pode acessar uma estação específica
  // Ex: usuario.podeAcessarEstacao('limpeza')
  bool podeAcessarEstacao(String estacao) {
    if (acessoTotalProducao) return true;
    if (!isOperador) return false;
    return estacoesLiberadas.contains(estacao);
  }

  // Verifica se pode liberar/revogar estações de outros operadores
  bool get podeGerenciarEstacoes => isAdmin || isLider;

  // Verifica se pode aprovar/recusar usuários
  bool get podeAprovarUsuarios => isAdmin;

  // Verifica se tem acesso ao módulo de estoque
  bool get acessoEstoque => isAdmin || isLider || isAlmoxarife || isVendedor;

  // Verifica se pode editar estoque (criar movimentações, produtos, etc.)
  bool get podeEditarEstoque => isAdmin || isAlmoxarife;

  // ── SERIALIZAÇÃO ──────────────────────────────────────────────────────────

  factory Usuario.fromMap(Map<String, dynamic> data, String uid) {
    // Lê estacoesLiberadas com segurança — campo pode não existir em docs antigos
    final estacoesRaw = data['estacoesLiberadas'];
    final estacoes = estacoesRaw is List
        ? List<String>.from(estacoesRaw.map((e) => e.toString()))
        : <String>[];

    return Usuario(
      uid: uid,
      email: data['email'] as String? ?? '',
      nome: data['nome'] as String? ?? '',
      empresaId: data['empresaId'] as String? ?? '',
      permissao: data['permissao'] as String? ?? 'operador',
      status: data['status'] as String?,
      estacoesLiberadas: estacoes,
    );
  }

  factory Usuario.fromFirestore(Map<String, dynamic> data, String uid) {
    return Usuario.fromMap(data, uid);
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'nome': nome,
      'empresaId': empresaId,
      'permissao': permissao,
      if (status != null) 'status': status,
      'estacoesLiberadas': estacoesLiberadas,
    };
  }

  // Cria uma cópia com campos alterados — útil ao salvar atualizações
  Usuario copyWith({
    String? permissao,
    String? status,
    List<String>? estacoesLiberadas,
  }) {
    return Usuario(
      uid: uid,
      email: email,
      nome: nome,
      empresaId: empresaId,
      permissao: permissao ?? this.permissao,
      status: status ?? this.status,
      estacoesLiberadas: estacoesLiberadas ?? this.estacoesLiberadas,
    );
  }
}

// ── CONSTANTES DAS ESTAÇÕES ───────────────────────────────────────────────
//
// Use EstacaoProducao.todas para montar a tela de gestão de acesso.
// Use EstacaoProducao.nomeExibicao para mostrar o label ao usuário.

abstract class EstacaoProducao {
  static const criarOS       = 'criar_os';
  static const descarga      = 'descarga';
  static const limpeza       = 'limpeza';
  static const lixa          = 'lixa';
  static const saque         = 'saque';
  static const manutencao    = 'manutencao';
  static const valvulaPo     = 'valvula_po';
  static const premontagem   = 'premontagem';
  static const th            = 'th';
  static const recarga       = 'recarga';
  static const estanqueidade = 'estanqueidade';
  static const pintura       = 'pintura';
  static const montagem      = 'montagem';
  static const expedicao     = 'expedicao';

  static const todas = [
    criarOS,
    descarga,
    limpeza,
    lixa,
    saque,
    manutencao,
    valvulaPo,
    premontagem,
    th,
    recarga,
    estanqueidade,
    pintura,
    montagem,
    expedicao,
  ];

  static const nomeExibicao = {
    criarOS:       'Criar Ordem de Serviço',
    descarga:      'Descarga',
    limpeza:       'Limpeza',
    lixa:          'Lixa',
    saque:         'Saque de Válvula',
    manutencao:    'Manutenção de Componentes',
    valvulaPo:     'Válvula Pó Químico',
    premontagem:   'Pré-Montagem',
    th:            'Teste Hidrostático',
    recarga:       'Recarga',
    estanqueidade: 'Estanqueidade',
    pintura:       'Pintura',
    montagem:      'Montagem',
    expedicao:     'Expedição',
  };
}