// Salve como: lib/telas/producao/estacao/tela_balanco_item.dart
// (VERSÃO v5.0 - Com Rolagem para evitar Overflow "Linha Zebrada")

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
      await FirebaseFirestore.instance
          .collection('itens_os')
          .doc(widget.itemOsId)
          .update({
        'status': 'descarga_concluida',
        'statusAtual': 'emProducao',
        'etapa': 'limpeza',
        'dataDescarga': FieldValue.serverTimestamp(),
        'realizadoPor': 'operador_descarga',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Descarga Confirmada!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );

      Navigator.pop(context); // Volta para a lista

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
      ),
      // LayoutBuilder + SingleChildScrollView = Fim do Overflow!
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

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

                      // --- LÓGICA DO PÓ ---
                      final bool deveDescartar = data['substituirPo'] ?? false;
                      final String t = (data['tipo'] ?? '').toString().toUpperCase();
                      // Só mostra aviso se for PÓ (ABC, BC, PQS)
                      final bool mostrarAvisoPo = t.contains('ABC') || t.contains('BC') || t.contains('PQS') || t.contains('PO');

                      // --- DADOS DO EQUIPAMENTO ---
                      final String cliente = data['clienteNome'] ?? 'Cliente Desconhecido';
                      final String descricao = "${data['tipo'] ?? ''} ${data['capacidade'] ?? ''}";
                      final String detalhes = "${data['fabricante'] ?? ''} | Cil: ${data['numeroCilindro'] ?? '?'}";

                      // Cores (Se você tiver seu widget zebrado, use a lógica aqui)
                      final Color corFundoAviso = deveDescartar ? Colors.red.shade50 : Colors.green.shade50;
                      final Color corTextoAviso = deveDescartar ? Colors.red.shade800 : Colors.green.shade800;
                      final IconData iconeAviso = deveDescartar ? Icons.delete_forever : Icons.recycling;
                      final String textoAviso = deveDescartar ? "DESCARTAR PÓ (LIXO)" : "REUTILIZAR PÓ (PENEIRA)";

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. CARD PRINCIPAL
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                children: [
                                  const Icon(Icons.fire_extinguisher, size: 60, color: Colors.blueGrey),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Rastreio: ${widget.idRastreio}',
                                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(descricao, style: const TextStyle(fontSize: 20, color: Colors.black87, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 5),
                                  Text(detalhes, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                                  const Divider(height: 30),
                                  Text('Proprietário:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                  Text(cliente, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 2. AVISO DE PÓ (Se for aplicável)
                          if (mostrarAvisoPo)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                // Se você quiser o zebrado de volta, substitua este color pelo seu decoration
                                color: corFundoAviso,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: corTextoAviso, width: 2),
                              ),
                              child: Column(
                                children: [
                                  Icon(iconeAviso, size: 50, color: corTextoAviso),
                                  const SizedBox(height: 10),
                                  Text(
                                    "INSTRUÇÃO DO PÓ:",
                                    style: TextStyle(color: corTextoAviso, fontSize: 14, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    textoAviso,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: corTextoAviso,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const Spacer(), // Empurra o botão para o final da rolagem

                          const SizedBox(height: 20),

                          // 3. BOTÃO
                          SizedBox(
                            height: 60,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _confirmarDescarga,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: _isSaving
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.check_circle, color: Colors.white, size: 30),
                              label: Text(
                                _isSaving ? 'SALVANDO...' : 'CONFIRMAR DESCARGA',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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