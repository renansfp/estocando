import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelaEstacaoPintura extends StatefulWidget {
  final String osId;
  const TelaEstacaoPintura({Key? key, required this.osId}) : super(key: key);

  @override
  _TelaEstacaoPinturaState createState() => _TelaEstacaoPinturaState();
}

class _TelaEstacaoPinturaState extends State<TelaEstacaoPintura> {
  final Color _corSetor = Colors.brown[700]!;

  Future<void> _confirmarPintura(String itemId, String codigo) async {
    try {
      await FirebaseFirestore.instance.collection('itens_os').doc(itemId).update({
        'status': 'aguardando_recarga', // VAI PARA RECARGA
        'pintura': {
          'data': FieldValue.serverTimestamp(),
          'operador': 'operador_pintura',
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item $codigo pintado -> Enviado para RECARGA'),
            duration: const Duration(milliseconds: 800),
            backgroundColor: Colors.green,
          )
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Execução: Pintura'),
        backgroundColor: _corSetor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('osId', isEqualTo: widget.osId)
            .where('status', isEqualTo: 'aguardando_pintura')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final itens = snapshot.data!.docs;

          // Lixeiro Automático
          if (itens.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pintura concluída! Itens enviados para Recarga.'), backgroundColor: Colors.green),
                );
              }
            });
            return Container(color: Colors.white);
          }

          return ListView.builder(
            itemCount: itens.length,
            itemBuilder: (context, index) {
              final item = itens[index];
              final dados = item.data() as Map<String, dynamic>;
              final codigo = dados['idCrachaTemporario'] ?? '???';
              final tipo = dados['tipoAgente'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.brown[100],
                    child: Icon(Icons.format_paint, color: _corSetor),
                  ),
                  title: Text('Extintor: $codigo', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Tipo: ${tipo.toUpperCase()}'),
                  trailing: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _corSetor,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('PINTADO'),
                    onPressed: () => _confirmarPintura(item.id, codigo),
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