// lib/telas/producao/estacao/tela_ensaio_th.dart
// Migrada para Repository Pattern — sem acesso direto ao Firestore.
// Única mudança: _finalizarEnsaio agora usa ItemOsProvider.finalizarEnsaioTH().
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';

class TelaEnsaioTH extends StatefulWidget {
  final String itemOsId;
  final String osId;
  final Map<String, dynamic> dadosItem;

  const TelaEnsaioTH({
    super.key,
    required this.itemOsId,
    required this.osId,
    required this.dadosItem,
  });

  @override
  State<TelaEnsaioTH> createState() => _TelaEnsaioTHState();
}

class _TelaEnsaioTHState extends State<TelaEnsaioTH> {
  bool _processando = false;
  late bool _isAltaPressao;

  static const Map<String, double> _pressaoPorNorma = {
    'NBR 12639 / EB-160': 190,
    'ISO 4705 / NBR ISO 9809': 225,
    'NBR 12790 / EB-926': 210,
    'NBR 12791 / EB-1199': 210,
    'DOT 3A / DOT 3AA / NBR 16357': 210,
  };

  String _normaSelecionada = 'NBR 12639 / EB-160';

  final _pvController = TextEditingController();
  final _pcController = TextEditingController();
  final _dvtController = TextEditingController();
  final _dvpController = TextEditingController();
  final _taraGravadaController = TextEditingController();
  final _pesoRealController = TextEditingController();
  bool _temCorrosao = false;

  double? _volumeCalculado;
  double? _cargaMaxCo2;
  double? _epPorcentagem;

  final _pncController = TextEditingController();
  final _pressaoAtingidaController = TextEditingController();
  final _quedaPressaoController = TextEditingController();
  bool _semVazamento = false;
  bool _semDeformacao = false;

  @override
  void initState() {
    super.initState();
    final agente =
        widget.dadosItem['tipoAgente']?.toString().toUpperCase() ?? '';
    _isAltaPressao = agente.contains('CO2') || agente.contains('CO ');

    final norma = widget.dadosItem['normaFabricacao']?.toString() ?? '';
    final pressao = widget.dadosItem['pressaoTrabalho']?.toString() ?? '';

    if (norma.isNotEmpty) {
      final chave = _pressaoPorNorma.keys.firstWhere(
            (k) => k.toLowerCase().contains(
            norma.toLowerCase().split('/').first.trim().toLowerCase()),
        orElse: () => 'NBR 12639 / EB-160',
      );
      _normaSelecionada = chave;
    }

    if (pressao.isNotEmpty && !_isAltaPressao) {
      final valor = double.tryParse(
          pressao.replaceAll(RegExp(r'[^0-9,.]'), '').replaceAll(',', '.'));
      if (valor != null) {
        final pncKgf = valor >= 1 && valor <= 5 ? valor * 10 : valor;
        _pncController.text = pncKgf.toStringAsFixed(1);
      }
    }
  }

  @override
  void dispose() {
    _pvController.dispose();
    _pcController.dispose();
    _dvtController.dispose();
    _dvpController.dispose();
    _taraGravadaController.dispose();
    _pesoRealController.dispose();
    _pncController.dispose();
    _pressaoAtingidaController.dispose();
    _quedaPressaoController.dispose();
    super.dispose();
  }

  void _recalcularAltaPressao() {
    final pv = double.tryParse(_pvController.text.replaceAll(',', '.'));
    final pc = double.tryParse(_pcController.text.replaceAll(',', '.'));
    final dvt = double.tryParse(_dvtController.text.replaceAll(',', '.'));
    final dvp = double.tryParse(_dvpController.text.replaceAll(',', '.'));
    setState(() {
      if (pv != null && pc != null && pc > pv) {
        _volumeCalculado = pc - pv;
        _cargaMaxCo2 = _volumeCalculado! * 0.68;
      } else {
        _volumeCalculado = null;
        _cargaMaxCo2 = null;
      }
      if (dvt != null && dvp != null && dvt > 0) {
        _epPorcentagem = (dvp / dvt) * 100;
      } else {
        _epPorcentagem = null;
      }
    });
  }

  String? _validar(bool aprovado) {
    if (!aprovado) return null;
    if (_isAltaPressao) {
      final pv = double.tryParse(_pvController.text.replaceAll(',', '.'));
      final pc = double.tryParse(_pcController.text.replaceAll(',', '.'));
      final dvt = double.tryParse(_dvtController.text.replaceAll(',', '.'));
      final dvp = double.tryParse(_dvpController.text.replaceAll(',', '.'));
      if (pv == null || pv <= 0) return 'Informe o Peso Vazio (PV).';
      if (pc == null || pc <= pv) {
        return 'Peso com Água (PC) deve ser maior que PV.';
      }
      if (dvt == null || dvt <= 0) return 'Informe a DVT.';
      if (dvp == null || dvp < 0) return 'Informe a DVP.';
      final ep = (dvp / dvt) * 100;
      if (ep > 10) {
        return 'EP% = ${ep.toStringAsFixed(1)}% — acima de 10%. REPROVAR.';
      }
      if (_temCorrosao) {
        final tara = double.tryParse(
            _taraGravadaController.text.replaceAll(',', '.'));
        final real =
        double.tryParse(_pesoRealController.text.replaceAll(',', '.'));
        if (tara == null || tara <= 0) return 'Informe a Tara Gravada.';
        if (real == null || real <= 0) return 'Informe o Peso Real Medido.';
        if (tara > real) {
          final perda = ((tara - real) / tara) * 100;
          if (perda > 6) {
            return 'Perda de massa = ${perda.toStringAsFixed(1)}% — acima de 6%. CONDENAR.';
          }
        }
      }
    } else {
      final pnc =
      double.tryParse(_pncController.text.replaceAll(',', '.'));
      if (pnc == null || pnc <= 0) return 'Informe a PNC.';
      final atingida = double.tryParse(
          _pressaoAtingidaController.text.replaceAll(',', '.'));
      if (atingida == null || atingida <= 0) {
        return 'Informe a pressão real atingida.';
      }
      final queda = double.tryParse(
          _quedaPressaoController.text.replaceAll(',', '.'));
      if (queda == null) return 'Informe a queda de pressão.';
      if (queda > 1.0) {
        return 'Queda de pressão (${queda.toStringAsFixed(2)} kgf/cm²) acima de 1,0. REPROVAR.';
      }
      if (!_semVazamento) return 'Confirme que não há vazamentos.';
      if (!_semDeformacao) return 'Confirme que não há deformação permanente.';
    }
    return null;
  }

  Future<void> _finalizarEnsaio(bool aprovado) async {
    final erro = _validar(aprovado);
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(erro), backgroundColor: Colors.orange.shade800));
      return;
    }

    setState(() => _processando = true);
    try {
      final List<String> roteiro =
      List<String>.from(widget.dadosItem['roteiro'] ?? []);
      final index = roteiro.indexOf('th');
      final proximaEtapa = (index != -1 && index + 1 < roteiro.length)
          ? roteiro[index + 1]
          : 'pintura';

      // Monta dadosTH localmente e passa para o provider.
      // O timestamp ('data') é injetado pelo repositório — não pela tela.
      Map<String, dynamic> dadosTH = {
        'resultado': aprovado ? 'APROVADO' : 'REPROVADO',
      };

      Map<String, dynamic>? updatesEquipamento;

      if (_isAltaPressao) {
        final pv = double.parse(_pvController.text.replaceAll(',', '.'));
        final pc = double.parse(_pcController.text.replaceAll(',', '.'));
        final dvt = double.parse(_dvtController.text.replaceAll(',', '.'));
        final dvp = double.parse(_dvpController.text.replaceAll(',', '.'));
        final ep = (dvp / dvt) * 100;
        dadosTH.addAll({
          'tipo': 'alta_pressao',
          'norma': _normaSelecionada,
          'pressaoEnsaio': _pressaoPorNorma[_normaSelecionada],
          'pesoVazio_PV': pv,
          'pesoAgua_PC': pc,
          'volumeCalc': pc - pv,
          'cargaMaxCo2': (pc - pv) * 0.68,
          'dvt_ml': dvt,
          'dvp_ml': dvp,
          'ep_porcento': double.parse(ep.toStringAsFixed(2)),
        });
        if (_temCorrosao) {
          final tara = double.tryParse(
              _taraGravadaController.text.replaceAll(',', '.')) ??
              0;
          final real = double.tryParse(
              _pesoRealController.text.replaceAll(',', '.')) ??
              0;
          final perda = tara > 0 && tara > real
              ? ((tara - real) / tara) * 100
              : 0.0;
          dadosTH.addAll({
            'corrosao': true,
            'taraGravada': tara,
            'pesoRealMedido': real,
            'perdaMassa_porcento': double.parse(perda.toStringAsFixed(2)),
          });
        }

        updatesEquipamento = {
          'status': aprovado ? 'em_manutencao' : 'baixado',
          if (!aprovado)
            'motivoCondenacao': 'Reprovado no Teste Hidrostático',
          if (aprovado) ...{
            'anoUltimoTH': DateFormat('MM/yyyy').format(DateTime.now()),
            // motivoCondenacao é apagado via FieldValue.delete() no repositório
            'taraGravada': pv,
            'pesoVazio': pv,
            'volumeHidraulico': pc - pv,
            'cargaMaxCo2': (pc - pv) * 0.68,
          },
        };
      } else {
        final pnc =
        double.parse(_pncController.text.replaceAll(',', '.'));
        final atingida = double.parse(
            _pressaoAtingidaController.text.replaceAll(',', '.'));
        final queda = double.tryParse(
            _quedaPressaoController.text.replaceAll(',', '.')) ??
            0;
        dadosTH.addAll({
          'tipo': 'baixa_pressao',
          'pnc_kgf': pnc,
          'pressaoEnsaio_kgf': pnc * 2.5,
          'pressaoAtingida': atingida,
          'quedaPressao_kgf': queda,
          'semVazamento': _semVazamento,
          'semDeformacao': _semDeformacao,
        });

        updatesEquipamento = {
          'status': aprovado ? 'em_manutencao' : 'baixado',
          if (!aprovado)
            'motivoCondenacao': 'Reprovado no Teste Hidrostático',
          if (aprovado) ...{
            'anoUltimoTH': DateFormat('MM/yyyy').format(DateTime.now()),
            // motivoCondenacao é apagado via FieldValue.delete() no repositório
          },
        };
      }

      await context.read<ItemOsProvider>().finalizarEnsaioTH(
        itemId: widget.itemOsId,
        equipamentoId: widget.dadosItem['equipamentoId'] as String?,
        aprovado: aprovado,
        proximaEtapa: proximaEtapa,
        dadosTH: dadosTH,
        updatesEquipamento: updatesEquipamento,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              aprovado ? 'Ensaio APROVADO!' : 'Equipamento CONDENADO.'),
          backgroundColor: aprovado ? Colors.green : Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'TH — ${widget.dadosItem['idCrachaTemporario'] ?? widget.itemOsId}'),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
      body: _processando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCabecalho(),
          const SizedBox(height: 20),
          _isAltaPressao
              ? _buildFormAltaPressao()
              : _buildFormBaixaPressao(),
          const SizedBox(height: 30),
          _buildBotoes(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCabecalho() {
    final d = widget.dadosItem;
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child:
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.science, color: Colors.blue.shade900, size: 26),
            const SizedBox(width: 8),
            Text('TESTE HIDROSTÁTICO',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.blue.shade900)),
            const Spacer(),
            Chip(
              label: Text(
                  _isAltaPressao
                      ? 'ALTA PRESSAO (CO2)'
                      : 'BAIXA PRESSAO',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11)),
              backgroundColor:
              _isAltaPressao ? Colors.red.shade700 : Colors.teal,
            ),
          ]),
          const Divider(height: 18),
          _infoRow('Agente', d['tipoAgente'] ?? '-'),
          _infoRow('Capacidade', d['capacidade'] ?? '-'),
          _infoRow('Norma', d['normaFabricacao'] ?? '-'),
          _infoRow('Fabricante', d['fabricante'] ?? '-'),
          _infoRow('No Cilindro', d['numeroCilindro'] ?? '-'),
          if (d['anoFabricacao'] != null)
            _infoRow('Ano Fab.', d['anoFabricacao']),
        ]),
      ),
    );
  }

  Widget _infoRow(String label, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      SizedBox(
          width: 100,
          child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13))),
      Expanded(child: Text(valor, style: const TextStyle(fontSize: 13))),
    ]),
  );

  Widget _buildFormAltaPressao() {
    final pressaoEnsaio = _pressaoPorNorma[_normaSelecionada] ?? 190;
    final epColor = _epPorcentagem == null
        ? Colors.grey
        : (_epPorcentagem! <= 10 ? Colors.green : Colors.red);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _secao('1. Norma e Pressao de Ensaio'),
      DropdownButtonFormField<String>(
        value: _normaSelecionada,
        decoration: const InputDecoration(
            labelText: 'Norma de Fabricacao',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.rule)),
        items: _pressaoPorNorma.keys
            .map((n) => DropdownMenuItem(
            value: n,
            child: Text(n, style: const TextStyle(fontSize: 13))))
            .toList(),
        onChanged: (v) => setState(() => _normaSelecionada = v!),
      ),
      const SizedBox(height: 8),
      _infoDestaque('Pressao de Ensaio: $pressaoEnsaio kgf/cm2'),
      const SizedBox(height: 20),
      _secao('2. Avaliacao do Volume Interno'),
      Row(children: [
        Expanded(
            child: _campo(
                controller: _pvController,
                label: 'Peso Vazio - PV (kg)',
                hint: 'Ex: 7,340',
                icon: Icons.monitor_weight_outlined,
                onChanged: (_) => _recalcularAltaPressao())),
        const SizedBox(width: 12),
        Expanded(
            child: _campo(
                controller: _pcController,
                label: 'Peso c/ Agua - PC (kg)',
                hint: 'Ex: 11,860',
                icon: Icons.water_drop_outlined,
                onChanged: (_) => _recalcularAltaPressao())),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: _resultadoCard(
                'Volume (PC - PV)',
                _volumeCalculado != null
                    ? '${_volumeCalculado!.toStringAsFixed(3)} L'
                    : '-',
                Colors.blueGrey)),
        const SizedBox(width: 12),
        Expanded(
            child: _resultadoCard(
                'Carga Max. CO2 (x0,68)',
                _cargaMaxCo2 != null
                    ? '${_cargaMaxCo2!.toStringAsFixed(2)} kg'
                    : '-',
                Colors.teal)),
      ]),
      const SizedBox(height: 20),
      _secao('3. Deformacoes (ml)'),
      Row(children: [
        Expanded(
            child: _campo(
                controller: _dvtController,
                label: 'DVT - Total (sob pressao)',
                hint: 'ml',
                icon: Icons.compress,
                onChanged: (_) => _recalcularAltaPressao())),
        const SizedBox(width: 12),
        Expanded(
            child: _campo(
                controller: _dvpController,
                label: 'DVP - Permanente (apos aliviar)',
                hint: 'ml',
                icon: Icons.expand,
                onChanged: (_) => _recalcularAltaPressao())),
      ]),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _epPorcentagem == null
              ? Colors.grey.shade100
              : (_epPorcentagem! <= 10
              ? Colors.green.shade50
              : Colors.red.shade50),
          border: Border.all(color: epColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(
              _epPorcentagem == null
                  ? Icons.calculate
                  : (_epPorcentagem! <= 10 ? Icons.check_circle : Icons.cancel),
              color: epColor,
              size: 32),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('EP% = DVP / DVT x 100',
                style:
                TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            Text(
                _epPorcentagem != null
                    ? '${_epPorcentagem!.toStringAsFixed(2)}%'
                    : '-',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: epColor)),
            Text(
              _epPorcentagem == null
                  ? 'Preencha DVT e DVP'
                  : (_epPorcentagem! <= 10
                  ? 'Dentro do limite (<= 10%)'
                  : 'Acima do limite - REPROVAR'),
              style: TextStyle(color: epColor, fontSize: 13),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 20),
      _secao('4. Perda de Massa (se houver corrosao > Ri1)'),
      SwitchListTile(
        value: _temCorrosao,
        onChanged: (v) => setState(() => _temCorrosao = v),
        title: const Text('Cilindro apresenta corrosao > Ri1?'),
        subtitle:
        const Text('Ativa o calculo de perda de massa'),
        activeColor: Colors.red,
      ),
      if (_temCorrosao) ...[
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: _campo(
                  controller: _taraGravadaController,
                  label: 'Tara Gravada (kg)',
                  hint: 'Valor puncionado',
                  icon: Icons.archive_outlined,
                  onChanged: (_) => setState(() {}))),
          const SizedBox(width: 12),
          Expanded(
              child: _campo(
                  controller: _pesoRealController,
                  label: 'Peso Real Medido (kg)',
                  hint: 'Na balanca agora',
                  icon: Icons.balance,
                  onChanged: (_) => setState(() {}))),
        ]),
        const SizedBox(height: 8),
        Builder(builder: (_) {
          final tara = double.tryParse(
              _taraGravadaController.text.replaceAll(',', '.'));
          final real = double.tryParse(
              _pesoRealController.text.replaceAll(',', '.'));
          if (tara == null || real == null || tara <= 0) {
            return const SizedBox();
          }
          final perda =
          tara > real ? ((tara - real) / tara) * 100 : 0.0;
          final ok = perda <= 6;
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ok ? Colors.green.shade50 : Colors.red.shade50,
              border: Border.all(color: ok ? Colors.green : Colors.red),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Perda de massa: ${perda.toStringAsFixed(2)}% — ${ok ? "Dentro do limite (<= 6%)" : "Acima de 6% - CONDENAR"}',
              style: TextStyle(
                  color: ok
                      ? Colors.green.shade800
                      : Colors.red.shade800,
                  fontWeight: FontWeight.bold),
            ),
          );
        }),
      ],
    ]);
  }

  Widget _buildFormBaixaPressao() {
    final pnc =
    double.tryParse(_pncController.text.replaceAll(',', '.'));
    final pressaoEnsaio = pnc != null ? pnc * 2.5 : null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _secao('1. Pressao de Ensaio'),
      _campo(
        controller: _pncController,
        label: 'PNC - Pressao Normal de Carregamento (kgf/cm2)',
        hint: 'Ex: 10',
        icon: Icons.speed,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      if (pressaoEnsaio != null)
        _infoDestaque(
            'Pressao de Ensaio: ${pressaoEnsaio.toStringAsFixed(1)} kgf/cm2 (2,5 x PNC)'),
      const SizedBox(height: 20),
      _secao('2. Execucao do Ensaio'),
      _campo(
          controller: _pressaoAtingidaController,
          label: 'Pressao Real Atingida (kgf/cm2)',
          hint: 'Leitura do manometro',
          icon: Icons.compress),
      const SizedBox(height: 10),
      _campo(
        controller: _quedaPressaoController,
        label: 'Queda de Pressao (kgf/cm2)',
        hint: 'Limite: 1,0 kgf/cm2',
        icon: Icons.trending_down,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      Builder(builder: (_) {
        final queda = double.tryParse(
            _quedaPressaoController.text.replaceAll(',', '.'));
        if (queda == null) return const SizedBox();
        final ok = queda <= 1.0;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ok ? Colors.green.shade50 : Colors.red.shade50,
            border: Border.all(color: ok ? Colors.green : Colors.red),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            ok
                ? 'Queda dentro do limite (<= 1,0 kgf/cm2)'
                : 'Queda acima do limite - REPROVAR',
            style: TextStyle(
                color:
                ok ? Colors.green.shade800 : Colors.red.shade800,
                fontWeight: FontWeight.bold),
          ),
        );
      }),
      const SizedBox(height: 20),
      _secao('3. Inspecao Visual (apos aliviar pressao)'),
      Card(
        child: Column(children: [
          CheckboxListTile(
            value: _semVazamento,
            onChanged: (v) => setState(() => _semVazamento = v!),
            title: const Text('Sem vazamentos durante o ensaio?'),
            subtitle: const Text('Nenhuma bolha ou escape observado'),
            activeColor: Colors.green,
          ),
          const Divider(height: 1),
          CheckboxListTile(
            value: _semDeformacao,
            onChanged: (v) => setState(() => _semDeformacao = v!),
            title: const Text('Sem deformacao permanente visivel?'),
            subtitle:
            const Text('Verificado apos aliviar a pressao'),
            activeColor: Colors.green,
          ),
        ]),
      ),
    ]);
  }

  Widget _buildBotoes() {
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          icon: const Icon(Icons.close),
          label: const Text('REPROVAR / CONDENAR'),
          onPressed: _confirmarReprovacao,
          style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 18)),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('APROVAR'),
          onPressed: () => _finalizarEnsaio(true),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18)),
        ),
      ),
    ]);
  }

  void _confirmarReprovacao() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar Reprovacao'),
        content: const Text(
            'O equipamento sera marcado como CONDENADO.\nEsta acao nao pode ser desfeita.\n\nDeseja confirmar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _finalizarEnsaio(false);
            },
            style:
            ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('CONDENAR',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _secao(String titulo) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(titulo,
        style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Colors.blue.shade900)),
  );

  Widget _infoDestaque(String texto) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.orange.shade50,
      border: Border.all(color: Colors.orange),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(children: [
      const Icon(Icons.info_outline, color: Colors.orange),
      const SizedBox(width: 10),
      Expanded(
          child: Text(texto,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14))),
    ]),
  );

  Widget _campo({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    void Function(String)? onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: TextField(
          controller: controller,
          keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
            prefixIcon: Icon(icon),
          ),
        ),
      );

  Widget _resultadoCard(String label, String valor, Color cor) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: cor.withOpacity(0.08),
            border: Border.all(color: cor),
            borderRadius: BorderRadius.circular(8)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: cor,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(valor,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cor)),
            ]),
      );
}