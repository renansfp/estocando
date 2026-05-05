// lib/widgets/botao_condenar.dart
// Migrado para Repository Pattern:
//   - Recebe Map<String, dynamic> em vez de DocumentSnapshot
//   - Usa ItemOsProvider.condenarItem() em vez de Firestore direto

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';

class BotaoCondenar extends StatelessWidget {
  /// Dados do item da OS (Map com 'id', 'equipamentoId', etc.)
  final Map<String, dynamic> item;

  /// Nome da etapa para registrar no histórico (ex: 'lixa', 'pintura')
  final String etapa;

  /// Callback opcional após condenação bem-sucedida
  final VoidCallback? onCondenado;

  const BotaoCondenar({
    super.key,
    required this.item,
    required this.etapa,
    this.onCondenado,
  });

  Future<void> _executarCondenacao(BuildContext context, String motivo) async {
    try {
      await context.read<ItemOsProvider>().condenarItem(
        itemId: item['id'] as String,
        item: item,
        etapa: etapa,
        motivo: motivo,
      );
      onCondenado?.call();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Equipamento condenado.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao condenar: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _mostrarDialogo(BuildContext context) {
    final cracha = item['idCrachaTemporario'] ?? '???';
    final agente = item['tipoAgente'] ?? '';
    final motivoController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text('Condenar $cracha',
                style: const TextStyle(color: Colors.red, fontSize: 18)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(children: [
                  const Icon(Icons.fire_extinguisher, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '$agente ${item['capacidade'] ?? item['carga'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: motivoController,
                maxLines: 2,
                autofocus: true,
                onChanged: (_) => setStateDialog(() {}),
                decoration: const InputDecoration(
                  labelText: 'Motivo da Condenação *',
                  hintText: 'Ex: Corrosão no casco, rosca danificada...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_note),
                ),
              ),
              const SizedBox(height: 6),
              const Text('* Campo obrigatório',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever),
              label: const Text('CONDENAR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: motivoController.text.trim().isEmpty
                  ? null
                  : () {
                Navigator.pop(ctx);
                _executarCondenacao(context, motivoController.text.trim());
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.delete_forever, color: Colors.red),
      tooltip: 'Condenar equipamento',
      onPressed: () => _mostrarDialogo(context),
    );
  }
}