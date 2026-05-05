// lib/telas/producao/estacao/tela_estacao_pintura.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/widgets/botao_condenar.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';

class TelaEstacaoPintura extends StatefulWidget {
  final String osId;
  const TelaEstacaoPintura({super.key, required this.osId});

  @override
  State<TelaEstacaoPintura> createState() => _TelaEstacaoPinturaState();
}

class _TelaEstacaoPinturaState extends State<TelaEstacaoPintura> {
  final TextEditingController _scannerController = TextEditingController();
  bool _processandoBipe = false;

  String _limparCodigo(String valor) {
    String limpo = valor.trim().toUpperCase();
    if (limpo.contains('HTTP')) limpo = limpo.split('/').last;
    return limpo.replaceAll('R-', '');
  }

  Future<void> _concluirPintura(Map<String, dynamic> item) async {
    setState(() => _processandoBipe = true);
    try {
      final List<String> roteiro = List<String>.from(item['roteiro'] ?? []);
      final int index = roteiro.indexOf('pintura');
      final String proxima = (index != -1 && index + 1 < roteiro.length)
          ? roteiro[index + 1]
          : 'recarga_abc';

      await context.read<ItemOsProvider>().confirmarEtapa(
        itemId: item['id'],
        dadosItem: {'dataPintura': DateTime.now()},
        osId: widget.osId,
        statusPendente: 'aguardando_pintura',
        proximaEstacao: proxima,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pintura finalizada!'),
          duration: Duration(seconds: 1),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _processandoBipe = false);
    }
  }

  Future<void> _processarBipe(String codigo) async {
    if (codigo.isEmpty) return;
    final idCracha = _limparCodigo(codigo);

    final item = await context.read<ItemOsProvider>().buscarItemPorCracha(
      widget.osId,
      idCracha,
      'aguardando_pintura',
    );

    if (item != null) {
      await _concluirPintura(item);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Cilindro não encontrado ou já pintado.')),
        );
      }
    }
    _scannerController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pintura: OS ${widget.osId}'),
        backgroundColor: Colors.brown.shade700,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () =>
              Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            color: Colors.brown.shade50,
            child: CampoComScanner(
              controller: _scannerController,
              label: 'Bipar Crachá para Concluir Pintura',
              onSubmitted: _processarBipe,
            ),
          ),
          if (_processandoBipe) const LinearProgressIndicator(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: context
                  .read<ItemOsProvider>()
                  .streamItensPorOsEStatus(widget.osId, 'aguardando_pintura'),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final itens = snapshot.data!;
                if (itens.isEmpty) return _buildConcluido();

                return ListView.builder(
                  itemCount: itens.length,
                  itemBuilder: (context, index) {
                    final item = itens[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      elevation: 2,
                      child: ListTile(
                        leading: const Icon(Icons.format_paint,
                            color: Colors.brown),
                        title: Text(
                          'Crachá: ${item['idCrachaTemporario']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                            '${item['tipoAgente']} - ${item['capacidade'] ?? item['carga'] ?? ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BotaoCondenar(item: item, etapa: 'pintura'),
                            ElevatedButton(
                              onPressed: () => _concluirPintura(item),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('CONCLUIR'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConcluido() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: Colors.green),
          const SizedBox(height: 20),
          const Text('OS Totalmente Pintada!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('VOLTAR'),
          ),
        ],
      ),
    );
  }
}