import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      // Ao confirmar, o item sai da "represa" da descarga e vai para a limpeza
      await FirebaseFirestore.instance
          .collection('itens_os')
          .doc(widget.itemOsId)
          .update({
        'status': 'descarga_concluida', // Agora ele "some" da lista de pendentes da descarga
        'dataDescarga': FieldValue.serverTimestamp(),
        'realizadoPor': 'operador_descarga',
      });

      if (!mounted) return;
      Navigator.pop(context); // Volta para a lista de execução

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Item: ${widget.idRastreio}'),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
        // PADRÃO: Botão Home
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
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
                  child: FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('equipamentos').doc(widget.equipamentoId).get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                      final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

                      // Lógica do Pó (Mantida conforme sua versão v5.0)
                      final bool deveDescartar = data['substituirPo'] ?? false;
                      final String t = (data['tipo'] ?? '').toString().toUpperCase();
                      final bool mostrarAvisoPo = t.contains('ABC') || t.contains('BC') || t.contains('PQS') || t.contains('PO');

                      final Color corFundoAviso = deveDescartar ? Colors.red.shade50 : Colors.green.shade50;
                      final Color corTextoAviso = deveDescartar ? Colors.red.shade800 : Colors.green.shade800;
                      final String textoAviso = deveDescartar ? "DESCARTAR PÓ (LIXO)" : "REUTILIZAR PÓ (PENEIRA)";

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                children: [
                                  const Icon(Icons.fire_extinguisher, size: 60, color: Colors.blueGrey),
                                  const SizedBox(height: 10),
                                  Text('Rastreio: ${widget.idRastreio}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                                  Text("${data['tipo'] ?? ''} ${data['capacidade'] ?? ''}", style: const TextStyle(fontSize: 18)),
                                  const Divider(height: 30),
                                  Text(data['clienteNome'] ?? 'Cliente N/D', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
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
                                border: Border.all(color: corTextoAviso, width: 2),
                              ),
                              child: Column(
                                children: [
                                  Text("INSTRUÇÃO DO PÓ:", style: TextStyle(color: corTextoAviso, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 5),
                                  Text(textoAviso, textAlign: TextAlign.center, style: TextStyle(color: corTextoAviso, fontSize: 22, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),

                          const Spacer(),
                          const SizedBox(height: 20),

                          SizedBox(
                            height: 60,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _confirmarDescarga,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              icon: _isSaving
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Icon(Icons.check_circle, color: Colors.white),
                              label: const Text('CONFIRMAR DESCARGA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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