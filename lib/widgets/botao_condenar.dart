// lib/widgets/botao_condenar.dart
// Widget reutilizável de condenação — usado em qualquer estação da produção.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BotaoCondenar extends StatelessWidget {
  final DocumentSnapshot itemDoc;
  final String etapa; // Nome da etapa para registrar no histórico (ex: 'lixa', 'pintura')
  final VoidCallback? onCondenado; // Callback opcional após condenação

  const BotaoCondenar({
    super.key,
    required this.itemDoc,
    required this.etapa,
    this.onCondenado,
  });

  Future<void> _executarCondenacao(BuildContext context, String motivo) async {
    try {
      final dados = itemDoc.data() as Map<String, dynamic>;
      final batch = FirebaseFirestore.instance.batch();

      // 1. Condena o item da OS
      batch.update(itemDoc.reference, {
        'status'           : 'condenado',
        'statusAtual'      : 'condenado',
        'motivoCondenacao' : motivo,
        etapa              : {
          'data'      : FieldValue.serverTimestamp(),
          'resultado' : 'CONDENADO',
          'motivo'    : motivo,
        },
      });

      // 2. Baixa o equipamento
      final equipId = dados['equipamentoId'];
      if (equipId != null && equipId.toString().isNotEmpty) {
        batch.update(
          FirebaseFirestore.instance.collection('equipamentos').doc(equipId),
          {
            'status'           : 'baixado',
            'motivoCondenacao' : motivo,
            'dataBaixa'        : FieldValue.serverTimestamp(),
            'osIdAtual'        : FieldValue.delete(),
            'itemIdAtual'      : FieldValue.delete(),
          },
        );
      }

      await batch.commit();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao condenar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _mostrarDialogo(BuildContext context) {
    final dados = itemDoc.data() as Map<String, dynamic>;
    final cracha = dados['idCrachaTemporario'] ?? '???';
    final agente = dados['tipoAgente'] ?? '';
    final motivoController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text('Condenar $cracha', style: const TextStyle(color: Colors.red, fontSize: 18)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info do item
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
                  Text('$agente ${dados['capacidade'] ?? dados['carga'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(height: 16),
              // Motivo obrigatório
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