// lib/telas/producao/estacao/tela_balanco_item.dart
// Migrada para Repository Pattern — sem acesso direto ao Firestore.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/models/equipamento.dart';
import 'package:protecin_producao/provider/equipamento_provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';

class TelaBalancoItem extends StatefulWidget {
  final String idRastreio;
  final String itemOsId;
  final String equipamentoId;
  final String tipoAgente;

  const TelaBalancoItem({
    super.key,
    required this.idRastreio,
    required this.itemOsId,
    required this.equipamentoId,
    required this.tipoAgente,
  });

  @override
  State<TelaBalancoItem> createState() => _TelaBalancoItemState();
}

class _TelaBalancoItemState extends State<TelaBalancoItem> {
  bool _isSaving = false;

  Future<void> _confirmarDescarga() async {
    setState(() => _isSaving = true);
    try {
      await context
          .read<ItemOsProvider>()
          .confirmarDescargaItem(widget.itemOsId);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Item: ${widget.idRastreio}'),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: FutureBuilder<Equipamento?>(
                    future: context
                        .read<EquipamentoProvider>()
                        .buscarPorId(widget.equipamentoId),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }

                      final equip = snapshot.data;
                      final bool deveDescartar =
                          equip?.substituirPo ?? false;
                      final String t =
                      (equip?.tipo ?? widget.tipoAgente).toUpperCase();
                      final bool mostrarAvisoPo = t.contains('ABC') ||
                          t.contains('BC') ||
                          t.contains('PQS') ||
                          t.contains('PO');

                      final Color corFundoAviso = deveDescartar
                          ? Colors.red.shade50
                          : Colors.green.shade50;
                      final Color corTextoAviso = deveDescartar
                          ? Colors.red.shade800
                          : Colors.green.shade800;
                      final String textoAviso = deveDescartar
                          ? 'DESCARTAR PO (LIXO)'
                          : 'REUTILIZAR PO (PENEIRA)';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                children: [
                                  const Icon(Icons.fire_extinguisher,
                                      size: 60, color: Colors.blueGrey),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Rastreio: ${widget.idRastreio}',
                                    style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${equip?.tipo ?? ''} ${equip?.capacidade ?? ''}',
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  const Divider(height: 30),
                                  Text(
                                    equip?.clienteNome ?? 'Cliente N/D',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (mostrarAvisoPo)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: corFundoAviso,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: corTextoAviso, width: 2),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'INSTRUCAO DO PO:',
                                    style: TextStyle(
                                        color: corTextoAviso,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    textoAviso,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: corTextoAviso,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                          const Spacer(),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 60,
                            child: ElevatedButton.icon(
                              onPressed:
                              _isSaving ? null : _confirmarDescarga,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green),
                              icon: _isSaving
                                  ? const CircularProgressIndicator(
                                  color: Colors.white)
                                  : const Icon(Icons.check_circle,
                                  color: Colors.white),
                              label: const Text(
                                'CONFIRMAR DESCARGA',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}