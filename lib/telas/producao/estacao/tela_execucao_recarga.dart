// lib/telas/producao/estacao/tela_execucao_recarga.dart
// TODO resolvido: _buildSeletorLotes migrado para ProdutoProvider.
// Removido import cloud_firestore — sem acesso direto ao Firestore nesta tela.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/models/equipamento.dart';
import 'package:protecin_producao/provider/equipamento_provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/provider/produto_provider.dart';
import 'package:protecin_producao/utils/mapeador_custos.dart';

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
  final TextEditingController _pesoCo2Controller = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    final String equipId = widget.item['equipamentoId'] ?? '';
    final Color corRecarga = Colors.green.shade700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Execução de Recarga'),
        backgroundColor: corRecarga,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Equipamento?>(
        future: context.read<EquipamentoProvider>().buscarPorId(equipId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final equip = snapshot.data!;
          final String agente = equip.tipo.toUpperCase();
          final double pesoCapacidade = _extrairPeso(equip.capacidade);
          final bool isPo =
              agente.contains('ABC') || agente.contains('BC');
          final bool substituir = equip.substituirPo;
          final String codigoMestre =
          _obterCodigoMestre(agente, pesoCapacidade);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCardInfo(equip, corRecarga),
                const SizedBox(height: 20),
                _buildCardDecisao(substituir, equip.lotePo),
                const SizedBox(height: 20),
                if (isPo && substituir)
                  _buildSeletorLotes(codigoMestre)
                else if (agente.contains('CO2'))
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
                        : () => _processarRecarga(equip, codigoMestre,
                        isPo, substituir, pesoCapacidade, agente),
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

  // Migrado para ProdutoProvider — sem Firestore direto.
  // Usa FutureBuilder para achar o produto pelo código mestre,
  // depois StreamBuilder para os lotes desse produto.
  Widget _buildSeletorLotes(String codigoMestre) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SELECIONE O LOTE DE PÓ QUE ESTÁ USANDO:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        FutureBuilder<Map<String, dynamic>?>(
          future: context
              .read<ProdutoProvider>()
              .buscarPorCodigo(codigoMestre),
          builder: (context, prodSnap) {
            if (prodSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!prodSnap.hasData || prodSnap.data == null) {
              return const Text('Produto não encontrado no estoque.');
            }

            final String produtoId = prodSnap.data!['id'] as String;

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: context
                  .read<ProdutoProvider>()
                  .streamLotesPorProduto(produtoId),
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
                        title: Text(
                            'Lote: ${lote['numero'] ?? 'S/N'}'),
                        subtitle: Text(
                            'Saldo: ${lote['quantidadeAtual'] ?? '0'} kg'),
                        onTap: () => setState(() {
                          _loteSelecionadoId = loteId;
                          _loteSelecionadoNumero =
                              lote['numero']?.toString();
                        }),
                      ),
                    );
                  },
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

      await context.read<ItemOsProvider>().processarRecarga(
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
        codigoMestre: codigoMestre,
        clienteNome: equip.clienteNome,
        cc: MapeadorCustos.obterCC('RECARGA E TESTES EQUIPAMENTOS PQS'),
      );

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