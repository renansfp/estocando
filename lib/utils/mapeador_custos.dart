// lib/util/mapeador_custos.dart

class MapeadorCustos {
  // Mapa baseado na sua tabela oficial
  static const Map<String, String> _setoresParaCC = {
    // ADMINISTRAÇÃO
    'ADMINISTRAÇÃO DA PRODUÇÃO': '4210',
    'QUALIDADE E AUDITORIA': '4211',
    'MANUTENÇÃO MAQUINAS': '4212',
    'MANUTENÇÃO PREDIAL': '4213',

    // PRODUÇÃO BASE
    'DESCARGA E PREPARAÇÃO': '4221',
    'LIXAMENTO': '4222',
    'PINTURA': '4223',
    'MONTAGEM': '4224',
    'MANUTENÇÃO DE COMPONENTES': '4224',

    // TESTES E RECARGA
    'TESTE HIDROSTÁTICO EXTINTORES': '4231',
    'TESTE HIDROSTÁTICO MANGUEIRAS': '4232',
    'RECARGA E TESTES EQUIPAMENTOS CO2': '4233',
    'RECARGA E TESTES EQUIPAMENTOS AP': '4234',
    'RECARGA E TESTES EQUIPAMENTOS PQS': '4235',
    'RECARGA E TESTES EQUIPAMENTOS EM': '4236',
  };

  /// Retorna o código do Centro de Custo com base no nome do setor.
  /// Se não encontrar, retorna vazio para que o usuário possa preencher manualmente.
  static String obterCC(String nomeSetor) {
    return _setoresParaCC[nomeSetor.toUpperCase()] ?? '';
  }
}