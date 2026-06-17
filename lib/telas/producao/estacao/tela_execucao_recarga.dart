// lib/telas/producao/estacao/tela_execucao_recarga.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/models/equipamento.dart';
import 'package:protecin_producao/models/usuario.dart';
import 'package:protecin_producao/provider/equipamento_provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/provider/produto_provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/utils/mapeador_custos.dart';
import 'package:protecin_producao/widgets/dialog_pecas_trocadas.dart';
import 'package:protecin_producao/widgets/seletor_operador.dart';

// ── Dossiê com tudo que a tela precisa carregar uma vez ─────────────────────
class _DadosCarregados {
  final Equipamento equipamento;
  final String agente;
  final double pesoCapacidade;
  final bool isPo;
  final bool substituir;
  final String codigoMestre;
  final Map<String, dynamic>? produto;
  final Stream<List<Map<String, dynamic>>>? streamLotes;

  _DadosCarregados({
    required this.equipamento,
    required this.agente,
    required this.pesoCapacidade,
    required this.isPo,
    required this.substituir,
    required this.codigoMestre,
    this.produto,
    this.streamLotes,
  });
}

class TelaExecucaoRecarga extends StatefulWidget {
  final Map<String, dynamic> item;
  final String osId;

  const TelaExecucaoRecarga(
      {super.key, required this.item, required this.osId});

  @override
  State<TelaExecucaoRecarga> createState() => _TelaExecucaoRecargaState();
}

class _TelaExecucaoRecargaState extends State<TelaExecucaoRecarga> {
  bool _carregando = false;
  String? _loteSelecionadoId;
  String? _loteSelecionadoNumero;
  String? _produtoId;
  final TextEditingController _pesoCo2Controller = TextEditingController();

  // Future estável — criado UMA vez em didChangeDependencies.
  // Nullable para evitar uso antes da primeira chamada de didChangeDependencies.
  Future<_DadosCarregados?>? _futureDados;
  bool _dadosIniciados = false;
  bool _erroCarregamento = false;

  // CORREÇÃO DA SESSÃO 20:
  // Antes: _futureDados era inicializado no initState com context.read<>().
  // No Flutter Web, initState roda antes da árvore de providers estar estável,
  // então context.read<>() podia falhar silenciosamente.
  // Agora: didChangeDependencies garante que os providers estão prontos.
  //
  // CORREÇÃO DA SESSÃO 22:
  // _dadosIniciados evita recargas desnecessárias, mas se _carregarDados()
  // retorna null (ex: timeout de rede), a tela ficava presa sem retry.
  // Adicionado botão de tentar novamente via _tentarNovamente().
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dadosIniciados) {
      _dadosIniciados = true;
      _futureDados = _carregarDados();
    }
  }

  void _tentarNovamente() {
    setState(() {
      _erroCarregamento = false;
      _futureDados = _carregarDados();
    });
  }

  Future<_DadosCarregados?> _carregarDados() async {
    final equipId = widget.item['equipamentoId'] as String? ?? '';
    if (equipId.isEmpty) return null;

    final equip =
    await context.read<EquipamentoProvider>().buscarPorId(equipId);
    if (equip == null || !mounted) return null;

    final agente = equip.tipo.toUpperCase();
    final pesoCapacidade = _extrairPeso(equip.capacidade);
    final isPo = agente.contains('ABC') || agente.contains('BC');
    final substituir = equip.substituirPo;
    final codigoMestre = _obterCodigoMestre(agente, pesoCapacidade);

    Map<String, dynamic>? produto;
    Stream<List<Map<String, dynamic>>>? streamLotes;

    if (isPo && substituir && codigoMestre.isNotEmpty) {
      final empresaId =
          context.read<UsuarioProvider>().usuario?.empresaId ?? '';
      produto = await context
          .read<ProdutoProvider>()
          .buscarPorCodigo(empresaId, codigoMestre);

      if (produto != null && mounted) {
        streamLotes = context
            .read<ProdutoProvider>()
            .streamLotesPorProduto(produto['id'] as String);
      }
    }

    return _DadosCarregados(
      equipamento: equip,
      agente: agente,
      pesoCapacidade: pesoCapacidade,
      isPo: isPo,
      substituir: substituir,
      codigoMestre: codigoMestre,
      produto: produto,
      streamLotes: streamLotes,
    );
  }

  double _extrairPeso(String? capacidade) {
    if (capacidade == null || capacidade.isEmpty) return 0.0;
    String limpo = capacidade
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(limpo) ?? 0.0;
  }

  String _obterCodigoMestre(String agente, double peso) {
    String a = agente.toUpperCase();
    if (a.contains('ABC')) {
      return [2.3, 4.5, 9.0, 55.0].contains(peso) ? '911' : '910';
    }
    if (a.contains('BC')) return '2504';
    return '';
  }

  bool _isAguaOuEspuma(String agente) {
    final a = agente.toUpperCase();
    return a.contains('AGUA') ||
        a.contains('ÁGUA') ||
        a.contains('AP') ||
        a.contains('ESPUMA') ||
        a.contains('EM') ||
        a.contains('LGE');
  }

  @override
  Widget build(BuildContext context) {
    final Color corRecarga = Colors.green.shade700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Execução de Recarga'),
        backgroundColor: corRecarga,
        foregroundColor: Colors.white,
        actions: const [
          SeletorOperador(estacao: EstacaoProducao.recarga),
        ],
      ),
      body: FutureBuilder<_DadosCarregados?>(
        future: _futureDados,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Não foi possível carregar os dados do equipamento.',
                      textAlign: TextAlign.center,
                    ),
                    if (snapshot.hasError) ...[
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('TENTAR NOVAMENTE'),
                      onPressed: _tentarNovamente,
                    ),
                  ],
                ),
              ),
            );
          }

          final dados = snapshot.data!;
          final equip = dados.equipamento;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCardInfo(equip, corRecarga),
                const SizedBox(height: 20),
                _buildCardDecisao(dados.substituir, equip.lotePo),
                const SizedBox(height: 20),
                if (dados.isPo && dados.substituir)
                  _buildSeletorLotes(dados.produto, dados.streamLotes)
                else if (dados.agente.contains('CO2'))
                  _buildCampoPesoCO2(),
                const SizedBox(height: 40),
                SizedBox(
                  height: 60,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: Text(_carregando
                        ? 'PROCESSANDO...'
                        : 'CONFIRMAR E BAIXAR'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: corRecarga,
                        foregroundColor: Colors.white),
                    onPressed: _carregando
                        ? null
                        : () => _processarRecarga(
                      equip,
                      dados.codigoMestre,
                      dados.isPo,
                      dados.substituir,
                      dados.pesoCapacidade,
                      dados.agente,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardInfo(Equipamento equip, Color cor) {
    return Card(
      elevation: 4,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('CRACHÁ: ${widget.item['idCrachaTemporario']}',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: cor)),
            const Divider(),
            Text('${equip.tipo} - ${equip.capacidade}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w500)),
            Text('Fabricante: ${equip.fabricante}',
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildCardDecisao(bool substituir, String? loteAtual) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: substituir ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: substituir ? Colors.orange : Colors.green),
      ),
      child: Row(
        children: [
          Icon(substituir ? Icons.swap_horiz : Icons.refresh,
              color: substituir ? Colors.orange : Colors.green),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  substituir ? 'CARGA NOVA (TROCA)' : 'REAPROVEITAMENTO',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: substituir
                          ? Colors.orange.shade900
                          : Colors.green.shade900),
                ),
                Text(substituir
                    ? 'Baixar do estoque'
                    : 'Lote original: ${loteAtual ?? 'N/D'}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeletorLotes(
      Map<String, dynamic>? produto,
      Stream<List<Map<String, dynamic>>>? streamLotes,
      ) {
    if (produto == null || streamLotes == null) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('Produto não encontrado no estoque.'),
      );
    }

    final String produtoId = produto['id'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SELECIONE O LOTE DE PÓ QUE ESTÁ USANDO:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: streamLotes,
          builder: (context, loteSnap) {
            if (loteSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final lotes = loteSnap.data ?? [];
            if (lotes.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Nenhum lote encontrado.'),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: lotes.length,
              itemBuilder: (context, index) {
                final lote = lotes[index];
                final loteId = lote['id'] as String;
                final bool selecionado = _loteSelecionadoId == loteId;

                return Card(
                  color: selecionado
                      ? Colors.green.shade50
                      : Colors.white,
                  child: ListTile(
                    leading: Icon(Icons.layers,
                        color: selecionado
                            ? Colors.green
                            : Colors.grey),
                    title: Text('Lote: ${lote['numero'] ?? 'S/N'}'),
                    subtitle: Text(
                        'Saldo: ${lote['quantidadeAtual'] ?? '0'} kg'),
                    onTap: () => setState(() {
                      _loteSelecionadoId = loteId;
                      _loteSelecionadoNumero =
                          lote['numero']?.toString();
                      _produtoId = produtoId;
                    }),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCampoPesoCO2() {
    return TextFormField(
      controller: _pesoCo2Controller,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Peso Final da Carga (kg)',
        border: OutlineInputBorder(),
        suffixText: 'kg',
      ),
    );
  }

  Future<void> _processarRecarga(
      Equipamento equip,
      String codigoMestre,
      bool isPo,
      bool substituirPo,
      double pesoCarga,
      String agente,
      ) async {
    if (isPo && substituirPo && _loteSelecionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecione um lote de pó!'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    // ── Captura providers ANTES de qualquer await ──────────────────────────
    final itemOsProvider = context.read<ItemOsProvider>();
    final usuario = context.read<UsuarioProvider>().operadorAtivo;
    final empresaId = usuario?.empresaId ??
        context.read<UsuarioProvider>().usuario?.empresaId ??
        '';
    final operador = usuario?.nome ?? 'Operador';

    // ── Dialog de peças — apenas para Água e Espuma ────────────────────────
    Map<int, String> pecasSelecionadas = {};
    if (_isAguaOuEspuma(agente)) {
      final resultado = await mostrarDialogPecasTrocadas(
        context: context,
        legendasDisponiveis: [1, 4, 9, 13, 15, 16, 20, 26],
        legendasObrigatorias: [13, 15],
        tipoEquipamento: equip.tipo,
        capacidadeEquipamento: equip.capacidade,
        fabricanteEquipamento: equip.fabricante,
      );

      if (resultado == null) return;
      pecasSelecionadas = resultado;
    }

    setState(() => _carregando = true);

    try {
      double pesoFinalRegistrado = pesoCarga;
      if (agente.contains('CO2') && _pesoCo2Controller.text.isNotEmpty) {
        pesoFinalRegistrado =
            double.tryParse(_pesoCo2Controller.text.replaceAll(',', '.')) ??
                pesoCarga;
      }

      final String loteFinal =
      substituirPo && _loteSelecionadoNumero != null
          ? _loteSelecionadoNumero!
          : (equip.lotePo ?? 'N/A');

      final String tipoRegistro =
      isPo && substituirPo ? 'CARGA NOVA' : 'REAPROVEITAMENTO';

      await itemOsProvider.processarRecarga(
        itemId: widget.item['id'],
        osId: widget.osId,
        equipamentoId: widget.item['equipamentoId'] ?? '',
        idCrachaTemporario: widget.item['idCrachaTemporario'] ?? '',
        substituirPo: substituirPo,
        isPo: isPo,
        pesoCarga: pesoCarga,
        pesoFinalRegistrado: pesoFinalRegistrado,
        agente: agente,
        loteFinal: loteFinal,
        tipoRegistro: tipoRegistro,
        loteSelecionadoId: _loteSelecionadoId,
        produtoId: _produtoId,
        clienteNome: equip.clienteNome,
        cc: MapeadorCustos.obterCC('RECARGA E TESTES EQUIPAMENTOS PQS'),
        operador: operador,
        statusAtualItem: widget.item['status'] as String? ?? '',
      );

      if (pecasSelecionadas.isNotEmpty) {
        await itemOsProvider.registrarPecasTrocadas(
          itemId: widget.item['id'],
          osId: widget.osId,
          empresaId: empresaId,
          pecas: pecasSelecionadas,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Recarga confirmada!'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }
}