// lib/telas/producao/estacao/tela_estacao_estanqueidade.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/widgets/botao_condenar.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';

class TelaEstacaoEstanqueidade extends StatefulWidget {
  final String osId;
  final List<String> filtrosAgente;
  const TelaEstacaoEstanqueidade(
      {super.key, required this.osId, required this.filtrosAgente});

  @override
  State<TelaEstacaoEstanqueidade> createState() =>
      _TelaEstacaoEstanqueidadeState();
}

class _TelaEstacaoEstanqueidadeState
    extends State<TelaEstacaoEstanqueidade> {
  final TextEditingController _scannerController = TextEditingController();
  bool _processando = false;

  String _limparCodigo(String valor) {
    String limpo = valor.trim().toUpperCase();
    if (limpo.contains('HTTP')) limpo = limpo.split('/').last;
    return limpo.replaceAll('R-', '');
  }

  Future<void> _aprovarItem(Map<String, dynamic> item) async {
    setState(() => _processando = true);
    try {
      final List<String> roteiro =
      List<String>.from(item['roteiro'] ?? []);
      int indexAtual =
      roteiro.indexWhere((etapa) => etapa.contains('estanqueidade'));
      String proximaEtapa =
      (indexAtual != -1 && indexAtual + 1 < roteiro.length)
          ? roteiro[indexAtual + 1]
          : 'pre_montagem';

      await context.read<ItemOsProvider>().confirmarEtapa(
        itemId: item['id'],
        dadosItem: {
          'estanqueidade': {
            'data': DateTime.now(),
            'resultado': 'APROVADO',
            'operador': 'bancada_estanqueidade',
          }
        },
        osId: widget.osId,
        statusPendente: 'aguardando_estanqueidade',
        proximaEstacao: proximaEtapa,
      );

      _notificar(
          'Aprovado! Segue para: ${proximaEtapa.toUpperCase()}', Colors.green);
    } catch (e) {
      _notificar('Erro no DNA do Roteiro: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  void _escolherMotivoReprovacao(String itemId, String cracha) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Reprovar: $cracha — Voltar para Recarga',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              const Text('Selecione o componente com falha:',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              _itemMotivoRecarga(itemId, 'BICO', Icons.ev_station),
              _itemMotivoRecarga(itemId, 'MANOMETRO', Icons.speed),
              _itemMotivoRecarga(itemId, 'ROSCA', Icons.sync),
            ],
          ),
        );
      },
    );
  }

  Widget _itemMotivoRecarga(String itemId, String motivo, IconData icone) {
    return ListTile(
      leading: Icon(icone, color: Colors.orange),
      title: Text(motivo),
      onTap: () async {
        Navigator.pop(context);
        setState(() => _processando = true);
        await context.read<ItemOsProvider>().reprovarItem(
          itemId: itemId,
          statusDestino: 'aguardando_recarga',
          dadosFalha: {'estanqueidade_falha.motivo': motivo},
        );
        _notificar('Voltou para Recarga! ($motivo)', Colors.orange);
        if (mounted) setState(() => _processando = false);
      },
    );
  }

  Future<void> _processarBipe(String codigo) async {
    if (codigo.isEmpty) return;
    String idCracha = _limparCodigo(codigo);

    final item = await context.read<ItemOsProvider>().buscarItemPorCracha(
      widget.osId,
      idCracha,
      'aguardando_estanqueidade',
    );

    if (item != null) {
      await _aprovarItem(item);
    } else {
      _notificar('Item não pendente neste setor.', Colors.red);
    }
    _scannerController.clear();
  }

  void _notificar(String msg, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: cor,
        duration: const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Estanqueidade: OS ${widget.osId}'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: CampoComScanner(
              controller: _scannerController,
              label: 'Bipar Crachá para Aprovar',
              onSubmitted: _processarBipe,
            ),
          ),
          const Divider(height: 1),
          if (_processando) const LinearProgressIndicator(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: context
                  .read<ItemOsProvider>()
                  .streamItensPorOsEStatus(
                  widget.osId, 'aguardando_estanqueidade'),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final itensDaBancada = snap.data!.where((item) {
                  final agente =
                  (item['tipoAgente'] ?? '').toString().toUpperCase();
                  return widget.filtrosAgente.any((f) {
                    String filtro = f.toUpperCase();
                    if (filtro == 'BC') {
                      return agente == 'BC' ||
                          (agente.contains('BC') &&
                              !agente.contains('ABC'));
                    }
                    return agente.contains(filtro);
                  });
                }).toList();

                if (itensDaBancada.isEmpty) {
                  return const Center(child: Text('Lote concluído!'));
                }

                return ListView.builder(
                  itemCount: itensDaBancada.length,
                  itemBuilder: (context, index) {
                    final item = itensDaBancada[index];
                    final String cracha =
                        item['idCrachaTemporario'] ?? '---';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.water_drop,
                            color: Colors.teal),
                        title: Text('Crachá: $cracha'),
                        subtitle: Text(
                            '${item['tipoAgente']} - ${item['capacidade'] ?? ""}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BotaoCondenar(
                                item: item, etapa: 'estanqueidade'),
                            IconButton(
                              icon: const Icon(Icons.thumb_down,
                                  color: Colors.orange),
                              tooltip: 'Reprovar → volta para recarga',
                              onPressed: () =>
                                  _escolherMotivoReprovacao(item['id'], cracha),
                            ),
                            IconButton(
                              icon: const Icon(Icons.thumb_up,
                                  color: Colors.green),
                              onPressed: () => _aprovarItem(item),
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
}