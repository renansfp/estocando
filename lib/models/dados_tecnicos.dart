class DadosTecnicos {
  final String fabricante;
  final String tipo; // AP, PQS, CO2
  final String carga; // Ex: '10 L', '4 KG', '50 KG'
  final String projeto; // O código do projeto
  final String capacidadeExtintora;
  final String norma; // Norma padrão (fallback)
  final String pressaoTrabalho;

  DadosTecnicos({
    required this.fabricante,
    required this.tipo,
    required this.carga,
    required this.projeto,
    required this.capacidadeExtintora,
    required this.norma,
    required this.pressaoTrabalho,
  });

  /// Retorna a norma correta baseada no Ano de Fabricação e no Tipo/Peso
  String getNormaCorreta(int anoFabricacao) {
    // 1. Se não for CO2, retorna a norma que está cadastrada no banco (padrão)
    if (tipo != 'CO2') {
      return this.norma;
    }

    // 2. Lógica temporal para CO2
    if (anoFabricacao < 1991) {
      return 'EB 150'; // Equipamentos muito antigos
    } else if (anoFabricacao >= 1991 && anoFabricacao <= 2010) {
      return 'NBR 11716'; // A norma mais comum para a frota antiga
    } else {
      // 3. Pós-2010: Diferencia Portátil de Sobre Rodas
      // NBR 15808 (Portátil) vs NBR 15809 (Sobre Rodas)
      if (_verificarSeEhSobreRodas()) {
        return 'NBR 15809';
      } else {
        return 'NBR 15808';
      }
    }
  }

  /// Verifica se o extintor é considerado "Sobre Rodas" baseado na carga.
  /// Regra aplicada: Para CO2, geralmente acima de 6kg já é carreta (10kg, 25kg, etc).
  bool _verificarSeEhSobreRodas() {
    try {
      // Remove letras (ex: "10 KG" vira "10")
      String apenasNumeros = carga.replaceAll(RegExp(r'[^0-9]'), '');
      int peso = int.parse(apenasNumeros);

      // Se for CO2 e tiver mais que 6kg, assumimos que é carreta (NBR 15809)
      // Se for outro tipo (Pó/Água), o limite de portátil costuma ser maior,
      // mas aqui o foco é corrigir o CO2.
      if (tipo == 'CO2' && peso > 6) {
        return true;
      }
      return false;
    } catch (e) {
      // Se der erro na conversão (ex: carga vazia), assume portátil por segurança
      return false;
    }
  }
}

// --- BANCO DE DADOS LIMPO E PADRONIZADO ---
final List<DadosTecnicos> TABELA_TECNICA = [
  // ACEPEX
  DadosTecnicos(
      fabricante: 'ACEPEX',
      tipo: 'AP',
      carga: '10 L',
      projeto: 'MC10AG',
      capacidadeExtintora: '2-A',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ACEPEX',
      tipo: 'AP',
      carga: '75 L',
      projeto: 'MC75AG',
      capacidadeExtintora: '10-A',
      norma: 'NBR 15809',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ACEPEX',
      tipo: 'ESP',
      carga: '10 L',
      projeto: 'EM10AB',
      capacidadeExtintora: '2A-10B',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ACEPEX',
      tipo: 'ESP',
      carga: '50 L',
      projeto: 'EM50AB',
      capacidadeExtintora: '6A-40B',
      norma: 'NBR 15809',
      pressaoTrabalho: '12 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ACEPEX',
      tipo: 'ABC',
      carga: '50 KG',
      projeto: 'MC50ABC',
      capacidadeExtintora: '20A-80BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '13 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ACEPEX',
      tipo: 'ABC',
      carga: '20 KG',
      projeto: 'MC20ABC',
      capacidadeExtintora: '10A-80BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '13 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ACEPEX',
      tipo: 'ABC',
      carga: '30 KG',
      projeto: 'MC30ABC',
      capacidadeExtintora: '10A-80BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '13 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ACEPEX',
      tipo: 'ABC',
      carga: '12 KG',
      projeto: 'MC12ABC',
      capacidadeExtintora: '6A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ACEPEX',
      tipo: 'ABC',
      carga: '4 KG',
      projeto: 'MC4ABC',
      capacidadeExtintora: '2A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ACEPEX',
      tipo: 'ABC',
      carga: '6 KG',
      projeto: 'MC6ABC',
      capacidadeExtintora: '4A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '13 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ACEPEX',
      tipo: 'ABC',
      carga: '8 KG',
      projeto: 'MC8ABC',
      capacidadeExtintora: '4A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ACEPEX',
      tipo: 'ABC',
      carga: '9 KG',
      projeto: 'MC9ABC90',
      capacidadeExtintora: '6A-80BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ACEPEX',
      tipo: 'BC',
      carga: '12 KG',
      projeto: 'MC12BC',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ACEPEX',
      tipo: 'BC',
      carga: '20 KG',
      projeto: 'MC20BC',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ACEPEX',
      tipo: 'BC',
      carga: '30 KG',
      projeto: 'MC30BC',
      capacidadeExtintora: '80BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '30 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ACEPEX',
      tipo: 'BC',
      carga: '4 KG',
      projeto: 'MC4BC',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ACEPEX',
      tipo: 'BC',
      carga: '50 KG',
      projeto: 'MC50BC',
      capacidadeExtintora: '80BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '13 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ACEPEX',
      tipo: 'BC',
      carga: '6 KG',
      projeto: 'MC6BC',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ACEPEX',
      tipo: 'BC',
      carga: '8 KG',
      projeto: 'MC8BC',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),

  // BUCKA
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'AP',
      carga: '10 L',
      projeto: 'EC142',
      capacidadeExtintora: '2A',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'AP',
      carga: '75 L',
      projeto: '4850-EC367',
      capacidadeExtintora: '10A',
      norma: 'NBR 15809',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'CO2',
      carga: '10 KG',
      projeto: '4077/10',
      capacidadeExtintora: '5BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'CO2',
      carga: '2 KG',
      projeto: 'EC-152',
      capacidadeExtintora: '2BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'CO2',
      carga: '25 KG',
      projeto: '4822',
      capacidadeExtintora: '10BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'CO2',
      carga: '4 KG',
      projeto: 'EC-153',
      capacidadeExtintora: '5BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'CO2',
      carga: '50 KG',
      projeto: '4825',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'CO2',
      carga: '6 KG',
      projeto: 'EC-154',
      capacidadeExtintora: '5BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'ESP',
      carga: '50 L',
      projeto: 'EC366',
      capacidadeExtintora: '10A-80B',
      norma: 'NBR 15809',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'ESP',
      carga: '9 L',
      projeto: 'EC238',
      capacidadeExtintora: '2A-10B',
      norma: 'NBR 15808',
      pressaoTrabalho: '13 kgf'
  ),
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'ABC',
      carga: '50 KG',
      projeto: '4840/1',
      capacidadeExtintora: '10A-120BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '18 kgf'
  ),
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'ABC',
      carga: '20 KG',
      projeto: '4830/3',
      capacidadeExtintora: '10A-80BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'BC',
      carga: '50 KG',
      projeto: '4840',
      capacidadeExtintora: '80BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '15 kgf'
  ),
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'BC',
      carga: '70 KG',
      projeto: '4840/3',
      capacidadeExtintora: '120BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '18 kgf'
  ),
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'ABC',
      carga: '12 KG',
      projeto: 'R919/1',
      capacidadeExtintora: '6A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'ABC',
      carga: '2.5 KG',
      projeto: '4850/1',
      capacidadeExtintora: '2A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'ABC',
      carga: '4 KG',
      projeto: '4315/4ABC',
      capacidadeExtintora: '2A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'ABC',
      carga: '6 KG',
      projeto: 'R917/2',
      capacidadeExtintora: '3A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'ABC',
      carga: '8 KG',
      projeto: 'R918/1',
      capacidadeExtintora: '4A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'BC',
      carga: '12 KG',
      projeto: 'R959/1',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'BC',
      carga: '20 KG',
      projeto: '4830/1',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'BC',
      carga: '4 KG',
      projeto: '4315/4',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'BC',
      carga: '50 KG',
      projeto: '4840/2',
      capacidadeExtintora: '80BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '15 kgf'
  ),
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'BC',
      carga: '6 KG',
      projeto: 'R957/2',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'BUCKA',
      tipo: 'BC',
      carga: '8 KG',
      projeto: 'R958/2',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),

  // CAEX
  DadosTecnicos(
      fabricante: 'CAEX',
      tipo: 'AP',
      carga: '10 L',
      projeto: 'C010-PCE010',
      capacidadeExtintora: '2A',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'CAEX',
      tipo: 'BC',
      carga: '12 KG',
      projeto: 'C012-PCE012',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'CAEX',
      tipo: 'BC',
      carga: '4 KG',
      projeto: 'C004-PCE004',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'CAEX',
      tipo: 'BC',
      carga: '6 KG',
      projeto: 'C006-PCE006',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'CAEX',
      tipo: 'BC',
      carga: '8 KG',
      projeto: 'C008-PCE008',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),

  // DELTA
  DadosTecnicos(
      fabricante: 'DELTA',
      tipo: 'AP',
      carga: '10 L',
      projeto: 'DPAG10L',
      capacidadeExtintora: '2A',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'DELTA',
      tipo: 'ABC',
      carga: '4 KG',
      projeto: 'DP4ABC',
      capacidadeExtintora: '2A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'DELTA',
      tipo: 'BC',
      carga: '4 KG',
      projeto: 'DP4BC',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),

  // EMBRASEG
  DadosTecnicos(
      fabricante: 'EMBRASEG',
      tipo: 'ABC',
      carga: '12 KG',
      projeto: 'EMBP12ABC',
      capacidadeExtintora: '3A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EMBRASEG',
      tipo: 'ABC',
      carga: '4 KG',
      projeto: 'EMBP4ABC',
      capacidadeExtintora: '2A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EMBRASEG',
      tipo: 'ABC',
      carga: '6 KG',
      projeto: 'EMBP6ABC',
      capacidadeExtintora: '2A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EMBRASEG',
      tipo: 'ABC',
      carga: '8 KG',
      projeto: 'EMBP8ABC',
      capacidadeExtintora: '3A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EMBRASEG',
      tipo: 'BC',
      carga: '12 KG',
      projeto: 'EMBP12BC',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EMBRASEG',
      tipo: 'BC',
      carga: '4 KG',
      projeto: 'EMBP4BC',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EMBRASEG',
      tipo: 'BC',
      carga: '6 KG',
      projeto: 'EMBP6BC',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EMBRASEG',
      tipo: 'BC',
      carga: '8 KG',
      projeto: 'EMBP8BC',
      capacidadeExtintora: '30BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),

  // ESPERANÇA MINAS
  DadosTecnicos(
      fabricante: 'ESPERANÇA MINAS',
      tipo: 'AP',
      carga: '10 L',
      projeto: 'E10',
      capacidadeExtintora: '2A',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ESPERANÇA MINAS',
      tipo: 'ABC',
      carga: '12 KG',
      projeto: 'E12A',
      capacidadeExtintora: '6A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ESPERANÇA MINAS',
      tipo: 'ABC',
      carga: '2 KG',
      projeto: 'E02A',
      capacidadeExtintora: '2A-10BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ESPERANÇA MINAS',
      tipo: 'ABC',
      carga: '4 KG',
      projeto: 'E04A',
      capacidadeExtintora: '2A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ESPERANÇA MINAS',
      tipo: 'ABC',
      carga: '6 KG',
      projeto: 'E06A',
      capacidadeExtintora: '3A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ESPERANÇA MINAS',
      tipo: 'ABC',
      carga: '8 KG',
      projeto: 'E08A',
      capacidadeExtintora: '4A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ESPERANÇA MINAS',
      tipo: 'BC',
      carga: '12 KG',
      projeto: 'E12',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ESPERANÇA MINAS',
      tipo: 'BC',
      carga: '4 KG',
      projeto: 'E04',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'ESPERANÇA MINAS',
      tipo: 'BC',
      carga: '6 KG',
      projeto: 'E06',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),

  // EXTANG
  DadosTecnicos(
      fabricante: 'EXTANG',
      tipo: 'AP',
      carga: '10 L',
      projeto: '1100',
      capacidadeExtintora: '2A',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTANG',
      tipo: 'ABC',
      carga: '12 KG',
      projeto: '1122',
      capacidadeExtintora: '6A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTANG',
      tipo: 'ABC',
      carga: '2 KG',
      projeto: 'C40',
      capacidadeExtintora: '2A-10BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTANG',
      tipo: 'ABC',
      carga: '4 KG',
      projeto: 'I40',
      capacidadeExtintora: '2A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '12.7 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTANG',
      tipo: 'ABC',
      carga: '6 KG',
      projeto: 'I60',
      capacidadeExtintora: '4A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '12.7 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTANG',
      tipo: 'ABC',
      carga: '8 KG',
      projeto: 'I80',
      capacidadeExtintora: '4A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTANG',
      tipo: 'BC',
      carga: '12 KG',
      projeto: 'I120',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTANG',
      tipo: 'BC',
      carga: '4 KG',
      projeto: 'I42',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '12.7 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTANG',
      tipo: 'BC',
      carga: '6 KG',
      projeto: 'I62',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '12.7 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTANG',
      tipo: 'BC',
      carga: '8 KG',
      projeto: 'I82',
      capacidadeExtintora: '30BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '12.7 kgf'
  ),

  // EXTINPEL
  DadosTecnicos(
      fabricante: 'EXTINPEL',
      tipo: 'AP',
      carga: '10 L',
      projeto: '105.199.550',
      capacidadeExtintora: '2A',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINPEL',
      tipo: 'ESP',
      carga: '10 L',
      projeto: '105.199.560',
      capacidadeExtintora: '2A-10B',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINPEL',
      tipo: 'ABC',
      carga: '12 KG',
      projeto: '12FCVABC',
      capacidadeExtintora: '6A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINPEL',
      tipo: 'ABC',
      carga: '2 KG',
      projeto: '02FCVABC',
      capacidadeExtintora: '1A-10BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINPEL',
      tipo: 'ABC',
      carga: '20 KG',
      projeto: '2.060.901.110',
      capacidadeExtintora: '6A-40BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINPEL',
      tipo: 'ABC',
      carga: '4 KG',
      projeto: '04FCVABC',
      capacidadeExtintora: '2A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINPEL',
      tipo: 'ABC',
      carga: '6 KG',
      projeto: '06FCVABC',
      capacidadeExtintora: '4A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINPEL',
      tipo: 'ABC',
      carga: '8 KG',
      projeto: '08FCVABC',
      capacidadeExtintora: '4A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINPEL',
      tipo: 'BC',
      carga: '12 KG',
      projeto: '125.095.550',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINPEL',
      tipo: 'BC',
      carga: '4 KG',
      projeto: '45.095.351',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINPEL',
      tipo: 'BC',
      carga: '6 KG',
      projeto: '65.095.410',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINPEL',
      tipo: 'BC',
      carga: '8 KG',
      projeto: '85.095.495',
      capacidadeExtintora: '30BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),

  // EXTINLIGHT
  DadosTecnicos(
      fabricante: 'EXTINLIGHT',
      tipo: 'AP',
      carga: '10 L',
      projeto: 'EFE10',
      capacidadeExtintora: '2A',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINLIGHT',
      tipo: 'BC',
      carga: '12 KG',
      projeto: 'EFE12',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINLIGHT',
      tipo: 'BC',
      carga: '4 KG',
      projeto: 'EFE4',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINLIGHT',
      tipo: 'BC',
      carga: '6 KG',
      projeto: 'EFE6',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINLIGHT',
      tipo: 'BC',
      carga: '8 KG',
      projeto: 'EFE8',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),

  // EXTINORPI
  DadosTecnicos(
      fabricante: 'EXTINORPI',
      tipo: 'AP',
      carga: '10 L',
      projeto: 'EIC10L',
      capacidadeExtintora: '2A',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINORPI',
      tipo: 'ABC',
      carga: '12 KG',
      projeto: 'EIC12ABC',
      capacidadeExtintora: '6A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINORPI',
      tipo: 'ABC',
      carga: '2 KG',
      projeto: 'EIC02ABC',
      capacidadeExtintora: '2A-10BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINORPI',
      tipo: 'ABC',
      carga: '4 KG',
      projeto: 'EIC04ABC',
      capacidadeExtintora: '2A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINORPI',
      tipo: 'ABC',
      carga: '6 KG',
      projeto: 'EIC06ABC',
      capacidadeExtintora: '4A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINORPI',
      tipo: 'ABC',
      carga: '8 KG',
      projeto: 'EIC08ABC',
      capacidadeExtintora: '4A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINORPI',
      tipo: 'BC',
      carga: '12 KG',
      projeto: 'EIC12BC',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINORPI',
      tipo: 'BC',
      carga: '4 KG',
      projeto: 'EIC04BC',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINORPI',
      tipo: 'BC',
      carga: '6 KG',
      projeto: 'EIC06BC',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINORPI',
      tipo: 'BC',
      carga: '8 KG',
      projeto: 'EIC08BC',
      capacidadeExtintora: '30BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),

  // EXTINPAG
  DadosTecnicos(
      fabricante: 'EXTINPAG',
      tipo: 'ABC',
      carga: '12 KG',
      projeto: 'PE008',
      capacidadeExtintora: '6A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINPAG',
      tipo: 'ABC',
      carga: '4 KG',
      projeto: 'PE005',
      capacidadeExtintora: '2A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINPAG',
      tipo: 'ABC',
      carga: '6 KG',
      projeto: 'PE006',
      capacidadeExtintora: '3A-30BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),

  // EXTINSUL
  DadosTecnicos(
      fabricante: 'EXTINSUL',
      tipo: 'ABC',
      carga: '8 KG',
      projeto: 'P007',
      capacidadeExtintora: '4A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINSUL',
      tipo: 'ABC',
      carga: '12 KG',
      projeto: 'P008',
      capacidadeExtintora: '6A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINSUL',
      tipo: 'ABC',
      carga: '4 KG',
      projeto: 'P005',
      capacidadeExtintora: '2A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'EXTINSUL',
      tipo: 'ABC',
      carga: '6 KG',
      projeto: 'P006',
      capacidadeExtintora: '3A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),

  // FERCAM
  DadosTecnicos(
      fabricante: 'FERCAM',
      tipo: 'AP',
      carga: '10 L',
      projeto: 'A5',
      capacidadeExtintora: '2A',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'FERCAM',
      tipo: 'ABC',
      carga: '12 KG',
      projeto: 'A9',
      capacidadeExtintora: '3A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'FERCAM',
      tipo: 'ABC',
      carga: '4 KG',
      projeto: 'A6',
      capacidadeExtintora: '2A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '12 kgf'
  ),
  DadosTecnicos(
      fabricante: 'FERCAM',
      tipo: 'ABC',
      carga: '6 KG',
      projeto: 'A7',
      capacidadeExtintora: '3A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '12 kgf'
  ),
  DadosTecnicos(
      fabricante: 'FERCAM',
      tipo: 'ABC',
      carga: '8 KG',
      projeto: 'A8',
      capacidadeExtintora: '4A-30BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'FERCAM',
      tipo: 'BC',
      carga: '12 KG',
      projeto: 'A4',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'FERCAM',
      tipo: 'BC',
      carga: '4 KG',
      projeto: 'A1',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '12 kgf'
  ),
  DadosTecnicos(
      fabricante: 'FERCAM',
      tipo: 'BC',
      carga: '6 KG',
      projeto: 'A2',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '12 kgf'
  ),
  DadosTecnicos(
      fabricante: 'FERCAM',
      tipo: 'BC',
      carga: '8 KG',
      projeto: 'A3',
      capacidadeExtintora: '30BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),

  // FM
  DadosTecnicos(
      fabricante: 'FM',
      tipo: 'AP',
      carga: '10 L',
      projeto: 'FAP10',
      capacidadeExtintora: '2A',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'FM',
      tipo: 'BC',
      carga: '4 KG',
      projeto: 'FPQ04',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'FM',
      tipo: 'BC',
      carga: '6 KG',
      projeto: 'FPQ06',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),

  // IMASTER
  DadosTecnicos(
      fabricante: 'IMASTER',
      tipo: 'AP',
      carga: '10 L',
      projeto: 'EC142',
      capacidadeExtintora: '2A',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'IMASTER',
      tipo: 'AP',
      carga: '75 L',
      projeto: 'EC367',
      capacidadeExtintora: '10A',
      norma: 'NBR 15809',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'IMASTER',
      tipo: 'CO2',
      carga: '10 KG',
      projeto: '4077/10',
      capacidadeExtintora: '5BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'IMASTER',
      tipo: 'CO2',
      carga: '2 KG',
      projeto: 'EC152',
      capacidadeExtintora: '5BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'IMASTER',
      tipo: 'CO2',
      carga: '25 KG',
      projeto: '4822',
      capacidadeExtintora: '10BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'IMASTER',
      tipo: 'CO2',
      carga: '4 KG',
      projeto: 'EC153',
      capacidadeExtintora: '5BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'IMASTER',
      tipo: 'CO2',
      carga: '6 KG',
      projeto: 'EC154',
      capacidadeExtintora: '5BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'IMASTER',
      tipo: 'ESP',
      carga: '50 L',
      projeto: 'EC366',
      capacidadeExtintora: '6A-40BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'IMASTER',
      tipo: 'ESP',
      carga: '9 L',
      projeto: 'EC238',
      capacidadeExtintora: '2A-10BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '13 kgf'
  ),
  DadosTecnicos(
      fabricante: 'IMASTER',
      tipo: 'ABC',
      carga: '12 KG',
      projeto: 'EC081',
      capacidadeExtintora: '6A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'IMASTER',
      tipo: 'ABC',
      carga: '4 KG',
      projeto: 'EC078',
      capacidadeExtintora: '2A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'IMASTER',
      tipo: 'ABC',
      carga: '6 KG',
      projeto: 'EC079',
      capacidadeExtintora: '3A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'IMASTER',
      tipo: 'ABC',
      carga: '8 KG',
      projeto: 'EC080',
      capacidadeExtintora: '4A-30BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'IMASTER',
      tipo: 'BC',
      carga: '12 KG',
      projeto: 'EC147',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'IMASTER',
      tipo: 'BC',
      carga: '4 KG',
      projeto: 'EC144',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'IMASTER',
      tipo: 'BC',
      carga: '6 KG',
      projeto: 'EC145',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'IMASTER',
      tipo: 'BC',
      carga: '8 KG',
      projeto: 'EC146',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),

  // KIDDE
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'AP',
      carga: '10 L',
      projeto: 'KBAP10',
      capacidadeExtintora: '2A',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'AP',
      carga: '75 L',
      projeto: 'KBAP75',
      capacidadeExtintora: '10A',
      norma: 'NBR 15809',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'CO2',
      carga: '10 KG',
      projeto: 'KBCO210',
      capacidadeExtintora: '5BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'CO2',
      carga: '25 KG',
      projeto: 'KBCO225',
      capacidadeExtintora: '10BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'CO2',
      carga: '2 KG',
      projeto: 'KBCO2-4',
      capacidadeExtintora: '5BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'CO2',
      carga: '4 KG',
      projeto: 'KBCO24',
      capacidadeExtintora: '5BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'CO2',
      carga: '6 KG',
      projeto: 'KBCO26',
      capacidadeExtintora: '5BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'ESP',
      carga: '10 L',
      projeto: 'KBEM10',
      capacidadeExtintora: '2A-10BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'ESP',
      carga: '50 L',
      projeto: 'KBEM50',
      capacidadeExtintora: '6A-80BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'ABC',
      carga: '12 KG',
      projeto: 'KBP12ABC55',
      capacidadeExtintora: '6A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'ABC',
      carga: '2 KG',
      projeto: 'KBP2ABC55',
      capacidadeExtintora: '2A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'ABC',
      carga: '20 KG',
      projeto: 'KBP20ABC55',
      capacidadeExtintora: '6A-30BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'ABC',
      carga: '4 KG',
      projeto: 'KBP4ABC55',
      capacidadeExtintora: '2A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'ABC',
      carga: '6 KG',
      projeto: 'KBP6ABC55',
      capacidadeExtintora: '4A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'ABC',
      carga: '8 KG',
      projeto: 'KBP8ABC55',
      capacidadeExtintora: '4A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'BC',
      carga: '12 KG',
      projeto: 'KBP12BCK95',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'BC',
      carga: '2 KG',
      projeto: 'KBP2BCK95',
      capacidadeExtintora: '10BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'BC',
      carga: '20 KG',
      projeto: 'KBP20BCK95',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'BC',
      carga: '30 KG',
      projeto: 'KBP30BCK95',
      capacidadeExtintora: '80BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'BC',
      carga: '4 KG',
      projeto: 'KBP4BCK95',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'BC',
      carga: '50 KG',
      projeto: 'KBP50BCK95',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'BC',
      carga: '6 KG',
      projeto: 'KBP6BCK95',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'BC',
      carga: '8 KG',
      projeto: 'KBP8BCK95',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'ABC',
      carga: '9 KG',
      projeto: 'KBP9ABC90',
      capacidadeExtintora: '6A-120BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'ABC',
      carga: '2.3 KG',
      projeto: 'KBP2.3ABC90',
      capacidadeExtintora: '2A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'ABC',
      carga: '4.5 KG',
      projeto: 'KBP4.5ABC90',
      capacidadeExtintora: '4A-80BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'ABC',
      carga: '25 KG',
      projeto: 'KBP25ABC90',
      capacidadeExtintora: '20A-120BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '16 kgf'
  ),
  DadosTecnicos(
      fabricante: 'KIDDE',
      tipo: 'ABC',
      carga: '55 KG',
      projeto: 'KBP55ABC90',
      capacidadeExtintora: '30A-160BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '16 kgf'
  ),

  // MANGFLEX
  DadosTecnicos(
      fabricante: 'MANGFLEX',
      tipo: 'AP',
      carga: '10 L',
      projeto: 'MF1500',
      capacidadeExtintora: '2A',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MANGFLEX',
      tipo: 'ABC',
      carga: '4 KG',
      projeto: 'MF2500',
      capacidadeExtintora: '2A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MANGFLEX',
      tipo: 'ABC',
      carga: '6 KG',
      projeto: 'MF3000',
      capacidadeExtintora: '2A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MANGFLEX',
      tipo: 'BC',
      carga: '4 KG',
      projeto: 'MF1000',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MANGFLEX',
      tipo: 'BC',
      carga: '6 KG',
      projeto: 'MF2000',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),

  // MARDAN FIRE
  DadosTecnicos(
      fabricante: 'MARDAN FIRE',
      tipo: 'AP',
      carga: '10 L',
      projeto: 'MAP 10',
      capacidadeExtintora: '2A',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MARDAN FIRE',
      tipo: 'BC',
      carga: '12 KG',
      projeto: 'MPQ 12',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MARDAN FIRE',
      tipo: 'BC',
      carga: '4 KG',
      projeto: 'MPQ 04',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MARDAN FIRE',
      tipo: 'BC',
      carga: '6 KG',
      projeto: 'MPQ 06',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MARDAN FIRE',
      tipo: 'BC',
      carga: '8 KG',
      projeto: 'MPQ 08',
      capacidadeExtintora: '30BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),

  // METALCASTY
  DadosTecnicos(
      fabricante: 'METALCASTY',
      tipo: 'AP',
      carga: '10 L',
      projeto: 'GD01',
      capacidadeExtintora: '2A',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'METALCASTY',
      tipo: 'CO2',
      carga: '4 KG',
      projeto: 'EXTC0004',
      capacidadeExtintora: '5BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'METALCASTY',
      tipo: 'CO2',
      carga: '6 KG',
      projeto: 'EXTC0006',
      capacidadeExtintora: '5BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'METALCASTY',
      tipo: 'ABC',
      carga: '12 KG',
      projeto: 'EXTABC012',
      capacidadeExtintora: '6A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'METALCASTY',
      tipo: 'ABC',
      carga: '2 KG',
      projeto: 'EXTABC002',
      capacidadeExtintora: '2A-10BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'METALCASTY',
      tipo: 'ABC',
      carga: '4 KG',
      projeto: 'EXTABC004',
      capacidadeExtintora: '2A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'METALCASTY',
      tipo: 'ABC',
      carga: '6 KG',
      projeto: 'EXTABC006',
      capacidadeExtintora: '3A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'METALCASTY',
      tipo: 'ABC',
      carga: '8 KG',
      projeto: 'EXTABC008',
      capacidadeExtintora: '4A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'METALCASTY',
      tipo: 'BC',
      carga: '12 KG',
      projeto: 'EXTBC012',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'METALCASTY',
      tipo: 'BC',
      carga: '4 KG',
      projeto: 'GD02',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'METALCASTY',
      tipo: 'BC',
      carga: '6 KG',
      projeto: 'EXTBC006',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'METALCASTY',
      tipo: 'BC',
      carga: '8 KG',
      projeto: 'EXTBC008',
      capacidadeExtintora: '30BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '14 kgf'
  ),

  // MOCELIN
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'AP',
      carga: '10 L',
      projeto: 'EM10AG',
      capacidadeExtintora: '3A',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'AP',
      carga: '75 L',
      projeto: 'EM75AG',
      capacidadeExtintora: '10A',
      norma: 'NBR 15809',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'ESP',
      carga: '10 L',
      projeto: 'EM10ESM',
      capacidadeExtintora: '2A-10B',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'ESP',
      carga: '50 L',
      projeto: 'EM50ESM',
      capacidadeExtintora: '10A-80B',
      norma: 'NBR 15809',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'CO2',
      carga: '10 KG',
      projeto: 'EM10CO',
      capacidadeExtintora: '10BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'CO2',
      carga: '4 KG',
      projeto: 'EM04CO',
      capacidadeExtintora: '2BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'CO2',
      carga: '6 KG',
      projeto: 'EM06CO',
      capacidadeExtintora: '5BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'ABC',
      carga: '12 KG',
      projeto: 'EM12ABC',
      capacidadeExtintora: '6A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'ABC',
      carga: '20 KG',
      projeto: 'EM20ABC',
      capacidadeExtintora: '10A-80BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '12 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'ABC',
      carga: '50 KG',
      projeto: 'EM50ABC',
      capacidadeExtintora: '10A-80BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '12 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'ABC',
      carga: '2 KG',
      projeto: 'EM02ABC',
      capacidadeExtintora: '2A-10BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'ABC',
      carga: '4 KG',
      projeto: 'EM04ABC',
      capacidadeExtintora: '3A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'ABC',
      carga: '6 KG',
      projeto: 'EM06ABC',
      capacidadeExtintora: '3A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'ABC',
      carga: '8 KG',
      projeto: 'EM08ABC',
      capacidadeExtintora: '4A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'BC',
      carga: '12 KG',
      projeto: 'EM12BC',
      capacidadeExtintora: '30BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'BC',
      carga: '20 KG',
      projeto: 'EM20BC',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '12 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'BC',
      carga: '50 KG',
      projeto: 'EM50BC',
      capacidadeExtintora: '80BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '12 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'BC',
      carga: '4 KG',
      projeto: 'EM04BC',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'BC',
      carga: '6 KG',
      projeto: 'EM06BC',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'BC',
      carga: '8 KG',
      projeto: 'EM08BC',
      capacidadeExtintora: '30BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'AP',
      carga: '10 L',
      projeto: 'R6',
      capacidadeExtintora: '2A',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'CO2',
      carga: '6 KG',
      projeto: 'R8',
      capacidadeExtintora: '5BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'BC',
      carga: '12 KG',
      projeto: 'R5',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'BC',
      carga: '4 KG',
      projeto: 'R2',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'BC',
      carga: '6 KG',
      projeto: 'R3',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'MOCELIN',
      tipo: 'BC',
      carga: '8 KG',
      projeto: 'R4',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),

  // PREVENCAO
  DadosTecnicos(
      fabricante: 'PREVENCAO',
      tipo: 'AP',
      carga: '10 L',
      projeto: 'E',
      capacidadeExtintora: '2A',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PREVENCAO',
      tipo: 'BC',
      carga: '12 KG',
      projeto: 'D',
      capacidadeExtintora: '30BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PREVENCAO',
      tipo: 'BC',
      carga: '4 KG',
      projeto: 'A',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PREVENCAO',
      tipo: 'BC',
      carga: '6 KG',
      projeto: 'B',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),

  // PROTEÇÃO
  DadosTecnicos(
      fabricante: 'PROTEÇÃO',
      tipo: 'AP',
      carga: '10 L',
      projeto: 'PÇAP',
      capacidadeExtintora: '2A',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEÇÃO',
      tipo: 'ABC',
      carga: '4 KG',
      projeto: 'PÇA4',
      capacidadeExtintora: '2A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEÇÃO',
      tipo: 'ABC',
      carga: '6 KG',
      projeto: 'PÇA6',
      capacidadeExtintora: '2A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEÇÃO',
      tipo: 'BC',
      carga: '12 KG',
      projeto: 'PÇP12',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEÇÃO',
      tipo: 'BC',
      carga: '4 KG',
      projeto: 'PÇP4',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEÇÃO',
      tipo: 'BC',
      carga: '6 KG',
      projeto: 'PÇP6',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEÇÃO',
      tipo: 'BC',
      carga: '8 KG',
      projeto: 'PÇP8',
      capacidadeExtintora: '30BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),

  // PROTEGE
  DadosTecnicos(
      fabricante: 'PROTEGE',
      tipo: 'AP',
      carga: '10 L',
      projeto: 'E001',
      capacidadeExtintora: '2A',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEGE',
      tipo: 'AP',
      carga: '75 L',
      projeto: 'E025',
      capacidadeExtintora: '10A',
      norma: 'NBR 15809',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEGE',
      tipo: 'CO2',
      carga: '10 KG',
      projeto: 'E021',
      capacidadeExtintora: '5BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEGE',
      tipo: 'CO2',
      carga: '25 KG',
      projeto: 'E046',
      capacidadeExtintora: '10BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEGE',
      tipo: 'CO2',
      carga: '4 KG',
      projeto: 'E016',
      capacidadeExtintora: '5BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEGE',
      tipo: 'CO2',
      carga: '50 KG',
      projeto: 'E048',
      capacidadeExtintora: '10BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEGE',
      tipo: 'CO2',
      carga: '6 KG',
      projeto: 'E017',
      capacidadeExtintora: '5BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEGE',
      tipo: 'ESP',
      carga: '10 L',
      projeto: 'E111',
      capacidadeExtintora: '2A-20B',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEGE',
      tipo: 'ESP',
      carga: '50 L',
      projeto: 'E108',
      capacidadeExtintora: '10A-80B',
      norma: 'NBR 15809',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEGE',
      tipo: 'ABC',
      carga: '12 KG',
      projeto: 'E015',
      capacidadeExtintora: '6A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEGE',
      tipo: 'ABC',
      carga: '2 KG',
      projeto: 'E103',
      capacidadeExtintora: '2A-10BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEGE',
      tipo: 'ABC',
      carga: '20 KG',
      projeto: 'E078',
      capacidadeExtintora: '10A-40BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEGE',
      tipo: 'ABC',
      carga: '4 KG',
      projeto: 'E012-E055',
      capacidadeExtintora: '2A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEGE',
      tipo: 'ABC',
      carga: '30 KG',
      projeto: 'E030',
      capacidadeExtintora: '10A-80BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEGE',
      tipo: 'ABC',
      carga: '50 KG',
      projeto: 'E062',
      capacidadeExtintora: '10A-80BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEGE',
      tipo: 'ABC',
      carga: '6 KG',
      projeto: 'E013-E056',
      capacidadeExtintora: '3A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEGE',
      tipo: 'ABC',
      carga: '8 KG',
      projeto: 'E014',
      capacidadeExtintora: '4A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEGE',
      tipo: 'BC',
      carga: '12 KG',
      projeto: 'E006-E052',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEGE',
      tipo: 'BC',
      carga: '20 KG',
      projeto: 'E022',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEGE',
      tipo: 'BC',
      carga: '4 KG',
      projeto: 'E003',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEGE',
      tipo: 'BC',
      carga: '50 KG',
      projeto: 'E024',
      capacidadeExtintora: '80BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEGE',
      tipo: 'BC',
      carga: '6 KG',
      projeto: 'E004-E050-E054',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'PROTEGE',
      tipo: 'BC',
      carga: '8 KG',
      projeto: 'E005-E051',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),

  // RESIL
  DadosTecnicos(
      fabricante: 'RESIL',
      tipo: 'AP',
      carga: '10 L',
      projeto: 'R960-R960/1',
      capacidadeExtintora: '2A',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'RESIL',
      tipo: 'AP',
      carga: '50 L',
      projeto: 'R926',
      capacidadeExtintora: '10A',
      norma: 'NBR 15809',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'RESIL',
      tipo: 'AP',
      carga: '75 L',
      projeto: 'R925',
      capacidadeExtintora: '10A',
      norma: 'NBR 15809',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'RESIL',
      tipo: 'CO2',
      carga: '10 KG',
      projeto: 'R938',
      capacidadeExtintora: '5BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'RESIL',
      tipo: 'CO2',
      carga: '25 KG',
      projeto: 'R965',
      capacidadeExtintora: '10BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'RESIL',
      tipo: 'CO2',
      carga: '4 KG',
      projeto: 'R936-R963',
      capacidadeExtintora: '5BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'RESIL',
      tipo: 'CO2',
      carga: '6 KG',
      projeto: 'R937',
      capacidadeExtintora: '5BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'RESIL',
      tipo: 'ESP',
      carga: '10 L',
      projeto: 'R929',
      capacidadeExtintora: '2A-10B',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'RESIL',
      tipo: 'ESP',
      carga: '50 L',
      projeto: 'R927',
      capacidadeExtintora: '10A-80B',
      norma: 'NBR 15809',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'RESIL',
      tipo: 'ABC',
      carga: '12 KG',
      projeto: 'R919/1',
      capacidadeExtintora: '6A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'RESIL',
      tipo: 'ABC',
      carga: '2 KG',
      projeto: 'R954',
      capacidadeExtintora: '2A-10BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'RESIL',
      tipo: 'ABC',
      carga: '20 KG',
      projeto: 'R921',
      capacidadeExtintora: '6A-40BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'RESIL',
      tipo: 'ABC',
      carga: '30 KG',
      projeto: 'R923',
      capacidadeExtintora: '10A-80BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'RESIL',
      tipo: 'ABC',
      carga: '4 KG',
      projeto: 'R916/1',
      capacidadeExtintora: '2A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'RESIL',
      tipo: 'ABC',
      carga: '6 KG',
      projeto: 'R917',
      capacidadeExtintora: '4A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'RESIL',
      tipo: 'ABC',
      carga: '8 KG',
      projeto: 'R918/1',
      capacidadeExtintora: '4A-40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'RESIL',
      tipo: 'BC',
      carga: '12 KG',
      projeto: 'R959/1',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'RESIL',
      tipo: 'BC',
      carga: '2 KG',
      projeto: 'R902',
      capacidadeExtintora: '2BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'RESIL',
      tipo: 'BC',
      carga: '20 KG',
      projeto: 'R920',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'RESIL',
      tipo: 'BC',
      carga: '4 KG',
      projeto: 'R956/3',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'RESIL',
      tipo: 'BC',
      carga: '50 KG',
      projeto: 'R950',
      capacidadeExtintora: '80BC',
      norma: 'NBR 15809',
      pressaoTrabalho: '14 kgf'
  ),
  DadosTecnicos(
      fabricante: 'RESIL',
      tipo: 'BC',
      carga: '6 KG',
      projeto: 'R957/2',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'RESIL',
      tipo: 'BC',
      carga: '8 KG',
      projeto: 'R958/1',
      capacidadeExtintora: '40BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),

  // TOTAL
  DadosTecnicos(
      fabricante: 'TOTAL',
      tipo: 'AP',
      carga: '10 L',
      projeto: 'PROJA5',
      capacidadeExtintora: '2A',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'TOTAL',
      tipo: 'CO2',
      carga: '4 KG',
      projeto: 'TTCO24',
      capacidadeExtintora: '5BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'TOTAL',
      tipo: 'CO2',
      carga: '6 KG',
      projeto: 'TTCO26',
      capacidadeExtintora: '5BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '126 kgf'
  ),
  DadosTecnicos(
      fabricante: 'TOTAL',
      tipo: 'ABC',
      carga: '4 KG',
      projeto: 'PROJA1',
      capacidadeExtintora: '2A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'TOTAL',
      tipo: 'ABC',
      carga: '6 KG',
      projeto: 'PROJA3',
      capacidadeExtintora: '3A-20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'TOTAL',
      tipo: 'BC',
      carga: '4 KG',
      projeto: 'PROJA2',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
  DadosTecnicos(
      fabricante: 'TOTAL',
      tipo: 'BC',
      carga: '6 KG',
      projeto: 'PROJA4',
      capacidadeExtintora: '20BC',
      norma: 'NBR 15808',
      pressaoTrabalho: '10 kgf'
  ),
];