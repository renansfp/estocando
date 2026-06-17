// lib/telas/producao/estacao/tela_controle_descarga.dart
// Migrada para Repository Pattern — sem acesso direto ao Firestore.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';

class TelaControleDescarga extends StatefulWidget {
  const TelaControleDescarga({super.key});

  @override
  State<TelaControleDescarga> createState() => _TelaControleDescargaState();
}

class _TelaControleDescargaState extends State<TelaControleDescarga> {
  bool _processando = false;

  Future<void> _liberarLoteParaLimpeza(
      String osId, List<Map<String, dynamic>> itens) async {
    setState(() => _processando = true);
    try {
      final itemIds = itens.map((i) => i['id'] as String).toList();
      await context
          .read<ItemOsProvider>()
          .liberarLoteParaLimpeza(osId: osId, itemIds: itemIds);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Sucesso! Lote na Limpeza.'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _executarReversao(String osId) async {
    if (osId.isEmpty) return;
    setState(() => _processando = true);
    try {
      final empresaId = context.read<UsuarioProvider>().usuario?.empresaId ?? '';
      await context.read<ItemOsProvider>().reverterParaDescarga(osId, empresaId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Lote revertido para Descarga!'),
            backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Erro ao reverter: ${e.toString().replaceAll("Exception:", "")}'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  void _mostrarDialogoReversao() {
    final controllerOs = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ADMIN: Reverter Lote',
            style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Isso fará os itens voltarem da Limpeza para a Descarga.'),
            const SizedBox(height: 10),
            TextField(
              controller: controllerOs,
              decoration: const InputDecoration(
                labelText: 'Digite o ID ou Número da OS',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => _executarReversao(controllerOs.text.trim()),
            child: const Text('REVERTER AGORA',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario =
        Provider.of<UsuarioProvider>(context, listen: false).usuario;
    if (usuario == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final bool isAdmin = usuario.permissao.toLowerCase() == 'admin' ||
        usuario.permissao.toLowerCase() == 'administrador';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Controle de Descarga'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.history_edu, color: Colors.orangeAccent),
              tooltip: 'Admin: Reverter OS',
              onPressed: _mostrarDialogoReversao,
            ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: context
            .read<ItemOsProvider>()
            .streamItensDescarga(usuario.empresaId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!;
          if (docs.isEmpty) {
            return const Center(
              child: Text('Nenhuma OS ativa na Descarga.',
                  style: TextStyle(color: Colors.grey)),
            );
          }

          // Agrupa itens por OS
          final Map<String, List<Map<String, dynamic>>> lotes = {};
          for (final item in docs) {
            final osId = (item['osId'] ?? 'Sem OS') as String;
            lotes.putIfAbsent(osId, () => []);
            lotes[osId]!.add(item);
          }

          final listaOs = lotes.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: listaOs.length,
            itemBuilder: (context, index) {
              final osId = listaOs[index];
              final itens = lotes[osId]!;

              int total = itens.length;
              int concluidos = 0;
              Set<String> tiposPendentes = {};

              for (final item in itens) {
                if (item['status'] == 'descarga_concluida') {
                  concluidos++;
                } else {
                  String tipo = (item['tipoAgente'] ?? '?')
                      .toString()
                      .toUpperCase();
                  if (tipo.contains('PO') ||
                      tipo.contains('ABC') ||
                      tipo.contains('BC')) {
                    tipo = 'PO';
                  } else if (tipo.contains('CO2')) {
                    tipo = 'CO2';
                  } else if (tipo.contains('AGUA') ||
                      tipo.contains('ESPUMA')) {
                    tipo = 'AGUA';
                  }
                  tiposPendentes.add(tipo);
                }
              }

              final bool isCompleto = (concluidos == total && total > 0);
              final double progresso =
              total > 0 ? concluidos / total : 0;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                      color: isCompleto ? Colors.green : Colors.orange,
                      width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('OS: $osId',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          isCompleto
                              ? const Chip(
                              label: Text('PRONTO',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10)),
                              backgroundColor: Colors.green)
                              : const Chip(
                              label: Text('PENDENTE',
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 10)),
                              backgroundColor: Colors.orange),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: progresso,
                        backgroundColor: Colors.grey[300],
                        color:
                        isCompleto ? Colors.green : Colors.orange,
                        minHeight: 8,
                      ),
                      const SizedBox(height: 5),
                      Text(
                          '$concluidos de $total cilindros descarregados',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 12)),
                      const SizedBox(height: 10),
                      if (!isCompleto) ...[
                        const Text('Setores Pendentes:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                        Wrap(
                          spacing: 6,
                          children: tiposPendentes
                              .map((t) => Chip(
                            label: Text(t,
                                style: const TextStyle(
                                    fontSize: 10)),
                            backgroundColor: Colors.red[50],
                            visualDensity:
                            VisualDensity.compact,
                          ))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            isCompleto ? Colors.green : Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: (isCompleto && !_processando)
                              ? () =>
                              _liberarLoteParaLimpeza(osId, itens)
                              : null,
                          icon: _processando && isCompleto
                              ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2))
                              : const Icon(Icons.check_circle),
                          label: const Text('LIBERAR PARA LIMPEZA'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}