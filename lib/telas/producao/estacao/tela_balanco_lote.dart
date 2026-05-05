// lib/telas/producao/estacao/tela_balanco_lote.dart
// Migrada para Repository Pattern — sem acesso direto ao Firestore.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/models/equipamento.dart';
import 'package:protecin_producao/provider/equipamento_provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';

class TelaBalancoLote extends StatefulWidget {
  final String osId;
  final List<String> filtrosAgente;

  const TelaBalancoLote({
    super.key,
    required this.osId,
    required this.filtrosAgente,
  });

  @override
  State<TelaBalancoLote> createState() => _TelaBalancoLoteState();
}

class _TelaBalancoLoteState extends State<TelaBalancoLote> {
  final TextEditingController _scannerController = TextEditingController();
  bool _processandoBipe = false;
  bool _prioridadeDescarte = true;

  String _limparCodigo(String valor) {
    String limpo = valor.trim().toUpperCase();
    if (limpo.contains('HTTP')) limpo = limpo.split('/').last;
    return limpo.replaceAll('R-', '');
  }

  Future<void> _processarBipeAutomatico(String codigo) async {
    if (codigo.isEmpty || _processandoBipe) return;
    setState(() => _processandoBipe = true);

    final idCracha = _limparCodigo(codigo);

    try {
      await context
          .read<ItemOsProvider>()
          .confirmarDescargaPorCracha(widget.osId, idCracha);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Cilindro $idCracha processado!'),
          backgroundColor: Colors.green,
          duration: const Duration(milliseconds: 700),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.orange,
        ));
      }
    } finally {
      _scannerController.clear();
      if (mounted) setState(() => _processandoBipe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Execucao de Descarga'),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            color: Colors.blueGrey.shade50,
            child: CampoComScanner(
              controller: _scannerController,
              label: 'Bipar Cracha do Cilindro',
              onSubmitted: _processarBipeAutomatico,
            ),
          ),
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Modo de Trabalho:',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
                ActionChip(
                  avatar: Icon(
                      _prioridadeDescarte
                          ? Icons.delete_outline
                          : Icons.recycling,
                      size: 16),
                  label: Text(_prioridadeDescarte
                      ? 'FOCO: LIXO'
                      : 'FOCO: REUSO'),
                  onPressed: () =>
                      setState(() => _prioridadeDescarte = !_prioridadeDescarte),
                  backgroundColor: _prioridadeDescarte
                      ? Colors.red[50]
                      : Colors.green[50],
                ),
              ],
            ),
          ),
          if (_processandoBipe) const LinearProgressIndicator(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: context
                  .read<ItemOsProvider>()
                  .streamItensDescargaOsPorAgente(
                  widget.osId, widget.filtrosAgente),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final itens = snapshot.data!;
                if (itens.isEmpty) return _buildTelaConclusao();

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: itens.length,
                  itemBuilder: (context, index) {
                    final item = itens[index];
                    final equipId =
                    (item['equipamentoId'] ?? '') as String;

                    return FutureBuilder<Equipamento?>(
                      future: context
                          .read<EquipamentoProvider>()
                          .buscarPorId(equipId),
                      builder: (context, snapEquip) {
                        if (!snapEquip.hasData || snapEquip.data == null) {
                          return const SizedBox.shrink();
                        }

                        final equip = snapEquip.data!;
                        final String tipoAgente =
                        (item['tipoAgente'] ?? '').toString().toUpperCase();
                        final bool deveDescartar = equip.substituirPo;

                        // Filtragem por modo de trabalho
                        if (tipoAgente != 'CO2' &&
                            tipoAgente != 'AGUA' &&
                            tipoAgente != 'ESPUMA') {
                          if (_prioridadeDescarte != deveDescartar) {
                            return const SizedBox.shrink();
                          }
                        } else {
                          if (!_prioridadeDescarte) {
                            return const SizedBox.shrink();
                          }
                        }

                        String labelStatus;
                        Color corAviso;
                        IconData icone;

                        if (tipoAgente == 'CO2') {
                          labelStatus = 'DESCARGA DE GAS (PESAGEM)';
                          corAviso = Colors.blue.shade700;
                          icone = Icons.air;
                        } else if (tipoAgente == 'AGUA' ||
                            tipoAgente == 'ESPUMA') {
                          labelStatus = 'DESCARTAR LIQUIDO (ESGOTO)';
                          corAviso = Colors.orange.shade800;
                          icone = Icons.waves;
                        } else {
                          labelStatus = deveDescartar
                              ? 'DESCARTAR PO (LIXO)'
                              : 'REUTILIZAR PO (PENEIRA)';
                          corAviso = deveDescartar
                              ? Colors.red
                              : Colors.green.shade700;
                          icone = deveDescartar
                              ? Icons.delete_forever
                              : Icons.recycling;
                        }

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: corAviso,
                              child:
                              Icon(icone, color: Colors.white),
                            ),
                            title: Text(
                              'Cracha: ${item['idCrachaTemporario'] ?? "N/D"}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              labelStatus,
                              style: TextStyle(
                                  color: corAviso,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ),
                        );
                      },
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

  Widget _buildTelaConclusao() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text('OS Finalizada neste Setor!',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              'O lote foi movido automaticamente para a Limpeza.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('VOLTAR PARA A FILA'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}