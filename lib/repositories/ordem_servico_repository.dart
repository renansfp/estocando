// lib/repositories/ordem_servico_repository.dart

import 'package:protecin_producao/models/item_os.dart';
import 'package:protecin_producao/models/ordem_servico.dart';
import 'package:protecin_producao/models/parceiro.dart';

abstract class OrdemServicoRepository {
  /// Cria uma OS completa com todos os itens em uma operação atômica.
  /// Retorna o número da OS gerada (ex: "00006").
  Future<String> criarOS({
    required OrdemServico os,
    required List<ItemOS> itens,
    required Parceiro cliente,
    required String observacoes,
  });

  /// Retorna stream com todas as OS da empresa.
  Stream<List<OrdemServico>> listarPorEmpresa(String empresaId);
}