// lib/utils/mapeador_pecas_producao.dart
//
// Dado um equipamento (tipo, capacidade, fabricante) e um número de legenda,
// retorna o(s) código(s) de produto do almoxarifado a debitar.
//
// Retorno null    → item não rastreado / não aplicável para este equipamento
// Lista 1 item    → débito automático
// Lista 2+ itens  → operador precisa escolher (ex: difusor CO₂)

class MapeadorPecasProducao {
  // ─── Helpers ────────────────────────────────────────────────────────────────

  static double _cap(String capacidade) {
    final limpo =
    capacidade.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(limpo) ?? 0;
  }

  static bool _isCO2(String tipo) {
    final t = tipo.toUpperCase();
    return t.contains('CO2') || t.contains('CO ');
  }

  static bool _isPo(String tipo) {
    final t = tipo.toUpperCase();
    return t.contains('ABC') || t.contains('PQS') || t.contains('BC');
  }

  static bool _isAgua(String tipo) {
    final t = tipo.toUpperCase();
    return t.contains('AGUA') || t.contains('ÁGUA') || t.contains(' AP');
  }

  static bool _isEspuma(String tipo) {
    final t = tipo.toUpperCase();
    return t.contains('ESPUMA') || t.contains(' EM') || t.contains('LGE');
  }

  static bool _isKidde(String fabricante) =>
      fabricante.toUpperCase().contains('KIDDE');

  // ─── API principal ───────────────────────────────────────────────────────────

  /// Retorna os códigos de produto para a peça [legendaNumero] do equipamento.
  /// null → não rastrear agora
  /// 1 elemento → debitar automaticamente
  /// 2+ elementos → operador escolhe qual foi usado
  static List<String>? resolverCodigos({
    required String tipo,
    required String capacidade,
    required String fabricante,
    required int legendaNumero,
  }) {
    final cap     = _cap(capacidade);
    final isCO2   = _isCO2(tipo);
    final isPo    = _isPo(tipo);
    final isAgua  = _isAgua(tipo);
    final isEsp   = _isEspuma(tipo);
    final isKidde = _isKidde(fabricante);

    switch (legendaNumero) {
    // ── 1. VÁLVULA DESC. ────────────────────────────────────────────────────
      case 1:
        if (isCO2) return cap >= 10 ? ['1508'] : ['1507'];
        if (isPo) {
          if (isKidde) {
            if (cap <= 2.4) return ['2174'];
            if (cap <= 9)   return ['909'];
          }
          if (cap <= 2)  return ['1203'];
          if (cap <= 12) return ['1759'];
          if (cap <= 30) return ['2226'];  // carretas 20-30 kg
          return ['1523'];                 // carreta 50 kg Bucka
        }
        if (isAgua) return cap <= 10 ? ['1759'] : ['3669'];
        if (isEsp)  return cap <= 10 ? ['1759'] : ['1523'];
        return null;

    // ── 2. MANGUEIRA ────────────────────────────────────────────────────────
      case 2:
        if (isCO2) return cap >= 25 ? ['7790'] : ['5147'];
        if (isPo) {
          if (isKidde) {
            if (cap <= 2.4) return ['4871'];
            if (cap <= 4.5) return ['4872'];
            return ['957'];              // 9 kg Kidde
          }
          if (cap <= 6) return ['2169'];
          return ['2168'];               // 8-12 kg
        }
        if (isAgua) return ['1512'];
        if (isEsp)  return ['4952'];
        return null;

    // ── 3. DIFUSOR ─────────────────────────────────────────────────────────
      case 3:
        if (isCO2) return ['231', '912']; // operador escolhe
        return null;

    // ── 9. SIFÃO ───────────────────────────────────────────────────────────
      case 9:
        if (isCO2 && cap <= 6) return ['10512'];
        return null; // outros tipos: rastrear depois

    // ── 13. PERA ───────────────────────────────────────────────────────────
      case 13:
        return ['851']; // sempre M-30

    // ── 15. O-RING ─────────────────────────────────────────────────────────
      case 15:
        if (isCO2) return ['766'];
        return ['850']; // pó, água, espuma → M-30

    // ── 26. BUCHA ──────────────────────────────────────────────────────────
      case 26:
        if (isPo && cap <= 2) return ['8729']; // P1/P2
        return ['3507'];                        // M30 e demais

      default:
        return null;
    }
  }

  // ─── Nome legível para exibir na UI ─────────────────────────────────────────
  static String nomeDaPeca(int legendaNumero) {
    const nomes = {
      1:  'VÁLVULA DESC.',
      2:  'MANGUEIRA',
      3:  'DIFUSOR',
      4:  'MANÔMETRO',
      5:  'PISTOLA',
      6:  'PUNHO',
      7:  'TRAVA',
      8:  'CORRENTE',
      9:  'SIFÃO',
      11: 'NYLON VÁLV.',
      12: 'CUPILHA',
      13: 'PERA',
      15: 'O-RING',
      16: 'TAMPA',
      19: 'RODA',
      20: 'REP. TAMPA',
      22: 'VOLANTE VÁLV.',
      26: 'BUCHA',
      27: 'ADAP. AMPOLA',
    };
    return nomes[legendaNumero] ?? 'PEÇA $legendaNumero';
  }
}