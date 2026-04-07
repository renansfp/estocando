// Arquivo: lib/services/relatorio_os_service.dart
// Monta o objeto completo para o relatório técnico da OS.

import 'package:cloud_firestore/cloud_firestore.dart';
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
  final String tara;              // Tara gravada no cilindro (dadosTH.taraGravada)
  final String pv;                // Peso Vazio medido (dadosTH.pesoVazio_PV ou manutValv)
  final String perdaMassaPct;     // Perda de massa % (dadosTH.perdaMassa_porcento)
  final String pc;                // Peso Cheio — carga registrada (recarga.peso)

  // ── R/S: Volume ─────────────────────────────────────────────────────────────
  final String volumeLts;         // Volume calculado (dadosTH.volumeCalc)
  final String capMaxCarga;       // Cap. máxima de carga: V×0,68 (dadosTH.cargaMaxCo2)

  // ── T/U/V: Pressões TH ──────────────────────────────────────────────────────
  final String pressaoTeste;      // Pressão de ensaio (dadosTH.pressaoEnsaio / _kgf)
  final String et;                // Expansão Total em ml (dadosTH.dvt_ml)
  final String ep;                // EP% — expansão permanente (dadosTH.ep_porcento)

  // ── W: Condenação ───────────────────────────────────────────────────────────
  final String? motivoCondenacao;

  // ── Y: Peças trocadas (futuro — campo ainda não existe no banco) ─────────────
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

  // dataSaida da OS ou, se null, a maior dataExpedicao entre os itens
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
  final _db = FirebaseFirestore.instance;

  Future<DadosRelatorioOS> buscarDados(String osId) async {
    // ── 1. OS ────────────────────────────────────────────────────────────────
    final docOS = await _db.collection('ordens_servico').doc(osId).get();
    if (!docOS.exists) throw Exception('OS "$osId" não encontrada.');
    final os = OrdemServico.fromJson(docOS.data() as Map<String, dynamic>, docOS.id);

    // ── 2. Parceiro (cliente) ────────────────────────────────────────────────
    final docParceiro = await _db.collection('parceiros').doc(os.clienteId).get();
    final Parceiro parceiro;
    if (docParceiro.exists) {
      parceiro = Parceiro.fromJson(docParceiro.data() as Map<String, dynamic>, docParceiro.id);
    } else {
      parceiro = Parceiro(
        id: os.clienteId, codigo: '', tipo: TipoParceiro.cliente,
        nome: os.clienteNome, empresaId: os.empresaId,
      );
    }

    // ── 3. Itens da OS ───────────────────────────────────────────────────────
    final snapItens = await _db
        .collection('itens_os')
        .where('osId', isEqualTo: osId)
        .get();

    if (snapItens.docs.isEmpty) throw Exception('Nenhum item para a OS "$osId".');

    // ── 4. Equipamentos em paralelo ──────────────────────────────────────────
    final futures = snapItens.docs.map((docItem) async {
      final rawItem  = docItem.data();
      final item     = ItemOS.fromJson(rawItem, docItem.id);
      final docEquip = await _db.collection('equipamentos').doc(item.equipamentoId).get();
      if (!docEquip.exists) return null;

      final equipData  = docEquip.data() as Map<String, dynamic>;
      final equipamento = Equipamento.fromJson(equipData, docEquip.id);

      // ── Nível de manutenção ──────────────────────────────────────────────
      final roteiro = List<String>.from(rawItem['roteiro'] ?? []);
      final nivel   = ItemOS.derivarNivel(roteiro);

      // ── Crachá (oculto se OS/item finalizado) ────────────────────────────
      final isFinalizado = item.statusAtual == StatusOS.finalizado ||
          item.statusAtual == StatusOS.emExpedicao ||
          (rawItem['status']?.toString() ?? '').contains('entregue');
      final numeroCracha = isFinalizado ? '' : item.idCrachaTemporario;

      // ── Dados do TH (dadosTH do item) ────────────────────────────────────
      final th = rawItem['dadosTH'] as Map<String, dynamic>?;

      final tara          = _fmt(th?['taraGravada']);
      final pvTH          = _fmt(th?['pesoVazio_PV']);
      final pvManut       = (rawItem['manutencao_valvula'] as Map?)?['pesoVazio']?.toString() ?? '---';
      final pv            = pvTH != '---' ? pvTH : pvManut;
      final perdaMassaPct = th?['perdaMassa_porcento'] != null
          ? '${(th!['perdaMassa_porcento'] as num).toStringAsFixed(1)}%'
          : '---';
      final volumeLts     = _fmt(th?['volumeCalc']);
      final capMaxCarga   = _fmt(th?['cargaMaxCo2']);

      // Pressão de ensaio: alta pressão usa 'pressaoEnsaio', baixa usa 'pressaoEnsaio_kgf'
      final pressaoTeste = th?['pressaoEnsaio'] != null
          ? _fmt(th!['pressaoEnsaio'])
          : _fmt(th?['pressaoEnsaio_kgf']);

      final et = _fmt(th?['dvt_ml']);  // Expansão Total (ml)
      final ep = th?['ep_porcento'] != null
          ? '${(th!['ep_porcento'] as num).toStringAsFixed(1)}%'
          : '---';

      // ── Recarga ──────────────────────────────────────────────────────────
      final recarga = rawItem['recarga'] as Map<String, dynamic>?;
      final pc = recarga?['peso'] != null ? _fmt(recarga!['peso']) : '---';

      // ── Status final ─────────────────────────────────────────────────────
      final thAprovado    = equipData['th_aprovado'] as bool? ?? false;
      final statusFinal   = _resolverStatus(item, equipamento, thAprovado);

      // ── Peças trocadas (futuro) ──────────────────────────────────────────
      // Quando a tela de peças for criada, o campo 'pecasTrocadas' será uma
      // List<int> com os números da legenda. Por ora: '---'
      final pecasRaw = rawItem['pecasTrocadas'];
      final pecasTrocadas = pecasRaw is List && pecasRaw.isNotEmpty
          ? pecasRaw.map((e) => e.toString()).join(', ')
          : '---';

      return DadosItemRelatorio(
        item:             item,
        equipamento:      equipamento,
        nivelManutencao:  nivel,
        numeroCracha:     numeroCracha,
        tara:             tara,
        pv:               pv,
        perdaMassaPct:    perdaMassaPct,
        pc:               pc,
        volumeLts:        volumeLts,
        capMaxCarga:      capMaxCarga,
        pressaoTeste:     pressaoTeste,
        et:               et,
        ep:               ep,
        motivoCondenacao: equipamento.motivoCondenacao,
        pecasTrocadas:    pecasTrocadas,
        statusFinal:      statusFinal,
      );
    });

    final resultados = await Future.wait(futures);
    final itens = resultados.whereType<DadosItemRelatorio>().toList();

    // Ordena por ativo fixo
    itens.sort((a, b) => (a.equipamento.ativoFixo).compareTo(b.equipamento.ativoFixo));

    // Deriva data de finalização: usa dataSaida da OS ou a maior dataExpedicao dos itens
    DateTime? dataFinalizacao = os.dataSaida;
    if (dataFinalizacao == null) {
      for (final doc in snapItens.docs) {
        final ts = doc.data()['dataExpedicao'];
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

  // ─── AUXILIARES ──────────────────────────────────────────────────────────
  String _fmt(dynamic valor) {
    if (valor == null) return '---';
    if (valor is double) return valor.toStringAsFixed(valor.truncateToDouble() == valor ? 0 : 1);
    if (valor is int)    return valor.toString();
    return valor.toString();
  }

  String _resolverStatus(ItemOS item, Equipamento equipamento, bool thAprovado) {
    if (equipamento.status == StatusEquipamento.baixado) return 'C';
    if (thAprovado || item.statusAtual == StatusOS.finalizado) return 'OK';
    return 'NC';
  }
}