// lib/services/relatorio_os_service.dart
// Migrado para Repository Pattern — sem acesso direto ao Firestore.
// Recebe 4 funções de busca via construtor, sem depender de nenhum repositório
// ou provider diretamente. Isso facilita testes e mantém o serviço desacoplado.

import 'package:protecin_producao/models/equipamento.dart';
import 'package:protecin_producao/models/item_os.dart';
import 'package:protecin_producao/models/ordem_servico.dart';
import 'package:protecin_producao/models/parceiro.dart';

// =============================================================================
// ESTRUTURA DE DADOS DE UM ITEM NO RELATÓRIO
// =============================================================================
class DadosItemRelatorio {
  final ItemOS item;
  final Equipamento equipamento;

  // ── D: Nível ────────────────────────────────────────────────────────────────
  final String nivelManutencao;   // N2 | N2P | N3 | N3P

  // ── H: Crachá (só aparece se a OS não está finalizada) ──────────────────────
  final String numeroCracha;

  // ── N/O/P/Q: Pesos ──────────────────────────────────────────────────────────
  final String tara;
  final String pv;
  final String perdaMassaPct;
  final String pc;

  // ── R/S: Volume ─────────────────────────────────────────────────────────────
  final String volumeLts;
  final String capMaxCarga;

  // ── T/U/V: Pressões TH ──────────────────────────────────────────────────────
  final String pressaoTeste;
  final String et;
  final String ep;

  // ── W: Condenação ───────────────────────────────────────────────────────────
  final String? motivoCondenacao;

  // ── Y: Peças trocadas ────────────────────────────────────────────────────────
  // Quando a tela de peças for criada, o campo 'pecasTrocadas' será uma
  // List<int> com os números da legenda. Por ora: '---'
  final String pecasTrocadas;

  // ── AB: Status final ─────────────────────────────────────────────────────────
  final String statusFinal;       // OK | NC | C

  DadosItemRelatorio({
    required this.item,
    required this.equipamento,
    required this.nivelManutencao,
    required this.numeroCracha,
    required this.tara,
    required this.pv,
    required this.perdaMassaPct,
    required this.pc,
    required this.volumeLts,
    required this.capMaxCarga,
    required this.pressaoTeste,
    required this.et,
    required this.ep,
    this.motivoCondenacao,
    required this.pecasTrocadas,
    required this.statusFinal,
  });
}

// =============================================================================
// OBJETO COMPLETO DO RELATÓRIO
// =============================================================================
class DadosRelatorioOS {
  final OrdemServico os;
  final Parceiro parceiro;
  final List<DadosItemRelatorio> itens;
  final DateTime? dataFinalizacao;

  DadosRelatorioOS({
    required this.os,
    required this.parceiro,
    required this.itens,
    this.dataFinalizacao,
  });
}

// =============================================================================
// SERVIÇO
// =============================================================================
class RelatorioOsService {
  final Future<OrdemServico?> Function(String osId) _buscarOS;
  final Future<Map<String, dynamic>?> Function(String parceiroId) _buscarParceiro;
  final Future<List<Map<String, dynamic>>> Function(String osId) _buscarItens;
  final Future<Equipamento?> Function(String equipId) _buscarEquipamento;

  RelatorioOsService({
    required Future<OrdemServico?> Function(String) buscarOS,
    required Future<Map<String, dynamic>?> Function(String) buscarParceiro,
    required Future<List<Map<String, dynamic>>> Function(String) buscarItens,
    required Future<Equipamento?> Function(String) buscarEquipamento,
  })  : _buscarOS = buscarOS,
        _buscarParceiro = buscarParceiro,
        _buscarItens = buscarItens,
        _buscarEquipamento = buscarEquipamento;

  Future<DadosRelatorioOS> buscarDados(String osId) async {
    // ── 1. OS ────────────────────────────────────────────────────────────────
    final os = await _buscarOS(osId);
    if (os == null) throw Exception('OS "$osId" não encontrada.');

    // ── 2. Parceiro (cliente) ────────────────────────────────────────────────
    final parceiroMap = await _buscarParceiro(os.clienteId);
    final Parceiro parceiro;
    if (parceiroMap != null) {
      parceiro = Parceiro.fromJson(parceiroMap, parceiroMap['id'] as String);
    } else {
      parceiro = Parceiro(
        id: os.clienteId,
        codigo: '',
        tipo: TipoParceiro.cliente,
        nome: os.clienteNome,
        empresaId: os.empresaId,
      );
    }

    // ── 3. Itens + Equipamentos em paralelo ──────────────────────────────────
    final rawItens = await _buscarItens(osId);
    if (rawItens.isEmpty) throw Exception('Nenhum item para a OS "$osId".');

    final futures = rawItens.map((rawItem) async {
      final item = ItemOS.fromJson(rawItem, rawItem['id'] as String);
      final equipamento = await _buscarEquipamento(item.equipamentoId);
      if (equipamento == null) return null;

      // ── Nível de manutenção ──────────────────────────────────────────────
      final roteiro = List<String>.from(rawItem['roteiro'] ?? []);
      final nivel = ItemOS.derivarNivel(roteiro);

      // ── Crachá (oculto se item finalizado) ──────────────────────────────
      final isFinalizado = item.statusAtual == StatusOS.finalizado ||
          item.statusAtual == StatusOS.emExpedicao ||
          (rawItem['status']?.toString() ?? '').contains('entregue');
      final numeroCracha = isFinalizado ? '' : item.idCrachaTemporario;

      // ── Dados do TH ──────────────────────────────────────────────────────
      final th = rawItem['dadosTH'] as Map<String, dynamic>?;
      final tara = _fmt(th?['taraGravada']);
      final pvTH = _fmt(th?['pesoVazio_PV']);
      final pvManut =
          (rawItem['manutencao_valvula'] as Map?)?['pesoVazio']?.toString() ??
              '---';
      final pv = pvTH != '---' ? pvTH : pvManut;
      final perdaMassaPct = th?['perdaMassa_porcento'] != null
          ? '${(th!['perdaMassa_porcento'] as num).toStringAsFixed(1)}%'
          : '---';
      final volumeLts = _fmt(th?['volumeCalc']);
      final capMaxCarga = _fmt(th?['cargaMaxCo2']);
      final pressaoTeste = th?['pressaoEnsaio'] != null
          ? _fmt(th!['pressaoEnsaio'])
          : _fmt(th?['pressaoEnsaio_kgf']);
      final et = _fmt(th?['dvt_ml']);
      final ep = th?['ep_porcento'] != null
          ? '${(th!['ep_porcento'] as num).toStringAsFixed(1)}%'
          : '---';

      // ── Recarga ──────────────────────────────────────────────────────────
      final recarga = rawItem['recarga'] as Map<String, dynamic>?;
      final pc = recarga?['peso'] != null ? _fmt(recarga!['peso']) : '---';

      // ── Status final ─────────────────────────────────────────────────────
      final thAprovado =
          (equipamento.toJson()['th_aprovado'] as bool?) ?? false;
      final statusFinal = _resolverStatus(item, equipamento, thAprovado);

      // ── Peças trocadas ───────────────────────────────────────────────────
      final pecasRaw = rawItem['pecasTrocadas'];
      final pecasTrocadas = pecasRaw is List && pecasRaw.isNotEmpty
          ? pecasRaw.map((e) => e.toString()).join(', ')
          : '---';

      return DadosItemRelatorio(
        item: item,
        equipamento: equipamento,
        nivelManutencao: nivel,
        numeroCracha: numeroCracha,
        tara: tara,
        pv: pv,
        perdaMassaPct: perdaMassaPct,
        pc: pc,
        volumeLts: volumeLts,
        capMaxCarga: capMaxCarga,
        pressaoTeste: pressaoTeste,
        et: et,
        ep: ep,
        motivoCondenacao: equipamento.motivoCondenacao,
        pecasTrocadas: pecasTrocadas,
        statusFinal: statusFinal,
      );
    });

    final resultados = await Future.wait(futures);
    final itens = resultados.whereType<DadosItemRelatorio>().toList();
    itens.sort(
            (a, b) => a.equipamento.ativoFixo.compareTo(b.equipamento.ativoFixo));

    // ── Data de finalização ──────────────────────────────────────────────────
    DateTime? dataFinalizacao = os.dataSaida;
    if (dataFinalizacao == null) {
      for (final raw in rawItens) {
        final ts = raw['dataExpedicao'];
        if (ts != null) {
          final dt = (ts as dynamic).toDate() as DateTime;
          if (dataFinalizacao == null || dt.isAfter(dataFinalizacao)) {
            dataFinalizacao = dt;
          }
        }
      }
    }

    return DadosRelatorioOS(
      os: os,
      parceiro: parceiro,
      itens: itens,
      dataFinalizacao: dataFinalizacao,
    );
  }

  // ─── AUXILIARES ────────────────────────────────────────────────────────────
  String _fmt(dynamic valor) {
    if (valor == null) return '---';
    if (valor is double) {
      return valor.toStringAsFixed(valor.truncateToDouble() == valor ? 0 : 1);
    }
    if (valor is int) return valor.toString();
    return valor.toString();
  }

  String _resolverStatus(
      ItemOS item, Equipamento equipamento, bool thAprovado) {
    if (equipamento.status == StatusEquipamento.baixado) return 'C';
    if (thAprovado || item.statusAtual == StatusOS.finalizado) return 'OK';
    return 'NC';
  }
}