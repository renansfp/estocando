import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';

class TelaEstacaoExpedicao extends StatefulWidget {
  final String osId;
  const TelaEstacaoExpedicao({super.key, required this.osId});

  @override
  State<TelaEstacaoExpedicao> createState() => _TelaEstacaoExpedicaoState();
}

class _TelaEstacaoExpedicaoState extends State<TelaEstacaoExpedicao> {
  final TextEditingController _scannerController = TextEditingController();
  bool _carregando = false;

  String _limparCodigo(String valor) {
    String limpo = valor.trim().toUpperCase();
    if (limpo.contains('HTTP')) limpo = limpo.split('/').last;
    return limpo.replaceAll('R-', '');
  }

  Future<void> _processarBipe(String codigo) async {
    if (codigo.isEmpty || _carregando) return;
    setState(() => _carregando = true);

    String idCracha = _limparCodigo(codigo);

    try {
      final item = await context.read<ItemOsProvider>().buscarItemPorCracha(
        widget.osId,
        idCracha,
        'aguardando_expedicao',
      );

      if (item != null) {
        await context.read<ItemOsProvider>().expedirItem(
          itemId: item['id'],
          osId: widget.osId,
          idCracha: idCracha,
          equipId: item['equipamentoId'],
        );
        _notificar('Item $idCracha carregado!', Colors.green);
      } else {
        _notificar('Crachá inválido ou já expedido.', Colors.orange);
      }
    } catch (e) {
      _notificar('Erro: $e', Colors.red);
    } finally {
      _scannerController.clear();
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _notificar(String msg, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: cor,
        duration: const Duration(milliseconds: 700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Expedição: OS ${widget.osId}'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            color: Colors.grey.shade200,
            child: CampoComScanner(
              controller: _scannerController,
              label: 'Bipar para Carregamento no Veículo',
              onSubmitted: _processarBipe,
            ),
          ),
          if (_carregando) const LinearProgressIndicator(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              // Busca todos os itens da OS — sem filtro de status
              stream: context
                  .read<ItemOsProvider>()
                  .streamItensPorOs(widget.osId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final totalItens = snapshot.data!;
                final expedidos = totalItens
                    .where((d) => d['status'] == 'entregue')
                    .toList();
                final pendentes = totalItens
                    .where((d) => d['status'] == 'aguardando_expedicao')
                    .toList();

                if (totalItens.isNotEmpty && pendentes.isEmpty) {
                  return _buildSucessoTotal();
                }

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Carregados: ${expedidos.length} de ${totalItens.length}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: pendentes.length,
                        itemBuilder: (context, index) {
                          final item = pendentes[index];
                          return ListTile(
                            leading: const Icon(Icons.inventory_2_outlined),
                            title:
                            Text('Crachá: ${item['idCrachaTemporario']}'),
                            subtitle: Text(
                                '${item['tipoAgente']} ${item['capacidade']}'),
                            trailing: const Text('PENDENTE',
                                style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSucessoTotal() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_shipping, size: 100, color: Colors.green),
          const SizedBox(height: 20),
          const Text('VEÍCULO CARREGADO!',
              style:
              TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text('Todos os itens foram expedidos com sucesso.'),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('FINALIZAR E VOLTAR'),
          ),
        ],
      ),
    );
  }
}