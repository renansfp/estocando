// Salve como: lib/telas/producao/lista/tela_controle_descarga.dart
// (VERSÃO v2.0 - Com Botão de Reversão Admin)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:provider/provider.dart';

class TelaControleDescarga extends StatefulWidget {
  const TelaControleDescarga({super.key});

  @override
  State<TelaControleDescarga> createState() => _TelaControleDescargaState();
}

class _TelaControleDescargaState extends State<TelaControleDescarga> {
  bool _processando = false;

  // --- FUNÇÃO 1: LIBERAR (IDA) ---
  Future<void> _liberarLoteParaLimpeza(String osId, List<DocumentSnapshot> itensDoLote) async {
    setState(() => _processando = true);
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Atualiza Itens
      for (var doc in itensDoLote) {
        batch.update(doc.reference, {
          'status': 'aguardando_limpeza',
          'historico_descarga': FieldValue.serverTimestamp(),
        });
      }

      // Atualiza OS Mãe
      final osRef = FirebaseFirestore.instance.collection('ordens_servico').doc(osId);
      batch.update(osRef, {
        'etapaAtual': 'limpeza',
        'statusLote': 'na_limpeza',
      });

      await batch.commit();

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sucesso! Lote na Limpeza.'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  // --- FUNÇÃO 2: REVERTER (VOLTA) - ADMIN ONLY ---
  Future<void> _executarReversao(String osId) async {
    if (osId.isEmpty) return;
    setState(() => _processando = true);

    try {
      // 1. Busca itens que já estão na limpeza
      final query = await FirebaseFirestore.instance
          .collection('itens_os')
          .where('osId', isEqualTo: osId)
          .where('status', isEqualTo: 'aguardando_limpeza') // Só pega o que já passou
          .get();

      if (query.docs.isEmpty) {
        throw Exception("Nenhum item dessa OS está na Limpeza.");
      }

      final batch = FirebaseFirestore.instance.batch();

      // 2. Joga de volta para 'aguardando_descarga' (Início)
      // Ou use 'descarga_concluida' se quiser voltar para o "limbo".
      // Mas geralmente erro de teste quer voltar pro início:
      for (var doc in query.docs) {
        batch.update(doc.reference, {
          'status': 'aguardando_descarga',
          // Opcional: Limpar histórico se quiser
        });
      }

      // 3. Volta a OS Mãe para Descarga
      final osRef = FirebaseFirestore.instance.collection('ordens_servico').doc(osId);
      batch.update(osRef, {
        'etapaAtual': 'descarga',
        'statusLote': 'em_descarga',
      });

      await batch.commit();

      if (mounted) {
        Navigator.pop(context); // Fecha Dialog
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lote revertido para Descarga!'), backgroundColor: Colors.orange));
      }

    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao reverter: ${e.toString().replaceAll("Exception:", "")}'), backgroundColor: Colors.red));
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
        title: const Text('ADMIN: Reverter Lote', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Isso fará os itens voltarem da Limpeza para a Descarga.'),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => _executarReversao(controllerOs.text.trim()),
            child: const Text('REVERTER AGORA', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = Provider.of<UsuarioProvider>(context, listen: false).usuario;
    if (usuario == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // --- CORREÇÃO AQUI ---
    // Usamos 'permissao' (do seu model) em vez de 'cargo'
    final bool isAdmin = usuario.permissao.toLowerCase() == 'admin' ||
        usuario.permissao.toLowerCase() == 'administrador';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Controle de Descarga'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        actions: [
          // SÓ MOSTRA SE FOR ADMIN
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.history_edu, color: Colors.orangeAccent),
              tooltip: 'Admin: Reverter OS',
              onPressed: _mostrarDialogoReversao,
            )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('empresaId', isEqualTo: usuario.empresaId)
            .where('status', whereIn: ['aguardando_descarga', 'descarga_concluida'])
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text('Nenhuma OS ativa na Descarga.', style: TextStyle(color: Colors.grey)),
            );
          }

          final Map<String, List<DocumentSnapshot>> lotes = {};
          for (var doc in docs) {
            final dados = doc.data() as Map<String, dynamic>;
            final osId = dados['osId'] ?? 'Sem OS';
            if (!lotes.containsKey(osId)) lotes[osId] = [];
            lotes[osId]!.add(doc);
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

              for (var doc in itens) {
                final d = doc.data() as Map<String, dynamic>;
                if (d['status'] == 'descarga_concluida') {
                  concluidos++;
                } else {
                  String tipo = (d['tipoAgente'] ?? '?').toString().toUpperCase();
                  if (tipo.contains('PO') || tipo.contains('ABC') || tipo.contains('BC')) tipo = 'PÓ';
                  else if (tipo.contains('CO2')) tipo = 'CO²';
                  else if (tipo.contains('AGUA') || tipo.contains('ESPUMA')) tipo = 'ÁGUA';
                  tiposPendentes.add(tipo);
                }
              }

              final bool isCompleto = (concluidos == total && total > 0);
              final double progresso = total > 0 ? concluidos / total : 0;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    side: BorderSide(color: isCompleto ? Colors.green : Colors.orange, width: 2),
                    borderRadius: BorderRadius.circular(8)
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('OS: $osId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          if (isCompleto)
                            const Chip(label: Text('PRONTO', style: TextStyle(color: Colors.white, fontSize: 10)), backgroundColor: Colors.green)
                          else
                            const Chip(label: Text('PENDENTE', style: TextStyle(color: Colors.black, fontSize: 10)), backgroundColor: Colors.orange)
                        ],
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: progresso,
                        backgroundColor: Colors.grey[300],
                        color: isCompleto ? Colors.green : Colors.orange,
                        minHeight: 8,
                      ),
                      const SizedBox(height: 5),
                      Text('$concluidos de $total cilindros descarregados', style: TextStyle(color: Colors.grey[600], fontSize: 12)),

                      const SizedBox(height: 10),
                      if (!isCompleto) ...[
                        const Text('Setores Pendentes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Wrap(
                          spacing: 6,
                          children: tiposPendentes.map((t) => Chip(
                            label: Text(t, style: const TextStyle(fontSize: 10)),
                            backgroundColor: Colors.red[50],
                            visualDensity: VisualDensity.compact,
                          )).toList(),
                        )
                      ],

                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCompleto ? Colors.green : Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: (isCompleto && !_processando) ? () => _liberarLoteParaLimpeza(osId, itens) : null,
                          icon: _processando && isCompleto
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_circle),
                          label: const Text('LIBERAR PARA LIMPEZA'),
                        ),
                      )
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