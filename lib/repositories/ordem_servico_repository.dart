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

  /// Stream reativo de todas as OS da empresa, ordenadas por data de entrada.
  ///
  /// [somentAbertas] = true → filtra no Firestore (`dataEncerramento` ausente),
  /// eliminando leituras desnecessárias de OS já entregues.
  /// Padrão false mantém o comportamento anterior (lê tudo).
  Stream<List<Map<String, dynamic>>> streamTodasOrdenadas(
      String empresaId, {
        bool somentAbertas = false,
      });

  /// Busca pontual (Future) das OS abertas da empresa.
  ///
  /// Retorna apenas OS onde `dataEncerramento` ainda não foi gravado.
  /// Use para montar mapas de lookup (ex.: osId → clienteNome) sem
  /// manter uma stream permanente aberta.
  Future<List<Map<String, dynamic>>> buscarOSAbertas(String empresaId);

  Future<Map<String, dynamic>?> buscarPorNumero(
      String empresaId, String numeroOS);

  // ─── Novo método ─────────────────────────────────────────────────────────

  /// Stream reativo de uma OS específica pelo ID.
  /// Emite null se o documento não existir.
  Stream<Map<String, dynamic>?> streamPorId(String osId);


  /// Busca uma OS pelo ID. Retorna null se não encontrada.
  Future<OrdemServico?> buscarPorId(String osId);
}