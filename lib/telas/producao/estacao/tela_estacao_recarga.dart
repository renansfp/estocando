import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_execucao_recarga.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';

class TelaEstacaoRecarga extends StatefulWidget {
  final String osId;
  final List<String> filtrosAgente;
  final String statusRecarga;

  const TelaEstacaoRecarga({
    super.key,
    required this.osId,
    required this.filtrosAgente,
    required this.statusRecarga,
  });

  @override
  State<TelaEstacaoRecarga> createState() => _TelaEstacaoRecargaState();
}

class _TelaEstacaoRecargaState extends State<TelaEstacaoRecarga> {
  final TextEditingController _scannerController = TextEditingController();

  // Stream estável — criada UMA vez em didChangeDependencies.
  Stream<List<Map<String, dynamic>>>? _streamItens;
  String? _empresaIdEscutando;
  List<Map<String, dynamic>> _itensSnapshot = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final empresaId = context.watch<UsuarioProvider>().usuario?.empresaId;
    if (empresaId != null &&
        empresaId.isNotEmpty &&
        empresaId != _empresaIdEscutando) {
      _empresaIdEscutando = empresaId;
      _streamItens = context
          .read<ItemOsProvider>()
          .streamItensPorOsEStatus(widget.osId, widget.statusRecarga, empresaId);
    }
  }

  String _limparCodigo(String valor) {
    String limpo = valor.trim().toUpperCase();
    if (limpo.contains('HTTP')) limpo = limpo.split('/').last;
    return limpo.replaceAll('R-', '');
  }

  Future<void> _processarBipe(String codigo) async {
    if (codigo.isEmpty) return;
    String idCracha = _limparCodigo(codigo);

    // Busca local — scan instantâneo (sem round-trip Firestore)
    Map<String, dynamic>? item;
    if (_itensSnapshot.isNotEmpty) {
      try {
        item = _itensSnapshot.firstWhere(
              (i) => i['idCrachaTemporario']?.toString() == idCracha,
        );
      } catch (_) {
        item = null;
      }
    }
    // Fallback ao Firestore apenas se o snapshot ainda não chegou
    if (item == null && _itensSnapshot.isEmpty) {
      final empresaId = context.read<UsuarioProvider>().usuario?.empresaId ?? '';
      item = await context.read<ItemOsProvider>().buscarItemPorCracha(
        widget.osId, idCracha, widget.statusRecarga, empresaId,
      );
    }


    if (item != null) {
      String ag = item['tipoAgente']?.toString().toUpperCase() ?? '';
      bool agenteBate = widget.filtrosAgente.any((f) {
        if (f.toUpperCase() == 'BC') return ag == 'BC';
        return ag.contains(f.toUpperCase());
      });

      if (agenteBate) {
        _irParaExecucao(item);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Agente incorreto para esta bancada.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Crachá não encontrado nesta bancada de recarga.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    _scannerController.clear();
  }

  void _irParaExecucao(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaExecucaoRecarga(item: item, osId: widget.osId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Recarga: OS ${widget.osId}'),
        backgroundColor: Colors.green.shade900,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            child: CampoComScanner(
              controller: _scannerController,
              label: 'Bipar para Recarregar',
              onSubmitted: _processarBipe,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _streamItens,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                _itensSnapshot = snapshot.data!;
                final itens = snapshot.data!.where((item) {
                  String ag = item['tipoAgente']?.toString().toUpperCase() ?? '';
                  return widget.filtrosAgente.any((f) {
                    if (f.toUpperCase() == 'BC') return ag == 'BC';
                    return ag.contains(f.toUpperCase());
                  });
                }).toList();

                if (itens.isEmpty) {
                  return const Center(
                      child: Text('Nenhum item pronto para esta bancada.'));
                }

                return ListView.builder(
                  itemCount: itens.length,
                  itemBuilder: (context, index) {
                    final item = itens[index];
                    return Card(
                      child: ListTile(
                        leading:
                        const Icon(Icons.ev_station, color: Colors.green),
                        title: Text('Crachá: ${item['idCrachaTemporario']}'),
                        subtitle: Text(
                            '${item['tipoAgente']} ${item['capacidade'] ?? item['carga'] ?? ''}'),
                        onTap: () => _irParaExecucao(item),
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
