// lib/repositories/equipamento_repository.dart

import 'package:protecin_producao/models/equipamento.dart';

enum DiagnosticoBloqueio {
  osAberta,       // bloqueio legítimo, OS ainda em andamento
  osFinalizada,   // OS existe mas já foi finalizada — bloqueio fantasma
  osInexistente,  // OS não existe mais no banco
}

abstract class EquipamentoRepository {
  Stream<List<Equipamento>> listarPorEmpresa(String empresaId);
  Stream<List<Equipamento>> listarPorCliente(String clienteId);
  Future<Equipamento?> buscarPorId(String id);
  Future<bool> verificarDisponibilidade(String equipamentoId);
  Future<String> criar(Equipamento equipamento);
  Future<void> atualizar(Equipamento equipamento);
  Future<void> liberarBloqueio(String equipamentoId);
  Future<void> condenar(String equipamentoId, String motivo);
  Future<DiagnosticoBloqueio> diagnosticarBloqueio(String equipamentoId, String osId);

  /// Busca um equipamento pelo ativo fixo ou número de cilindro.
  /// Usado pelo DialogCasamento ao bipar o extintor na entrada da OS.
  /// Retorna null se não encontrado.
  Future<Equipamento?> buscarPorCodigo({
    required String empresaId,
    required String clienteId,
    required String codigo,
  });
}