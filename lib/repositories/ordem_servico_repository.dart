// lib/repositories/ordem_servico_repository.dart

import 'package:protecin_producao/models/item_os.dart';
import 'package:protecin_producao/models/ordem_servico.dart';
import 'package:protecin_producao/models/parceiro.dart';

abstract class OrdemServicoRepository {
  Future<String> criarOS({
    required OrdemServico os,
    required List<ItemOS> itens,
    required Parceiro cliente,
    required String observacoes,
  });

  Stream<List<OrdemServico>> listarPorEmpresa(String empresaId);
  Stream<List<Map<String, dynamic>>> streamTodasOrdenadas();

  Future<Map<String, dynamic>?> buscarPorNumero(
      String empresaId, String numeroOS);

  // ─── Novo método ─────────────────────────────────────────────────────────

  /// Stream reativo de uma OS específica pelo ID.
  /// Emite null se o documento não existir.
  Stream<Map<String, dynamic>?> streamPorId(String osId);


  /// Busca uma OS pelo ID. Retorna null se não encontrada.
  Future<OrdemServico?> buscarPorId(String osId);
}