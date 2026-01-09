import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelaEstacaoPremontagem extends StatefulWidget {
  final String osId;
  const TelaEstacaoPremontagem({super.key, required this.osId});

  @override
  State<TelaEstacaoPremontagem> createState() => _TelaEstacaoPremontagemState();
}

class _TelaEstacaoPremontagemState extends State<TelaEstacaoPremontagem> {

  Future<void> _enviarParaMontagem(String docId, String codigo) async {
    await FirebaseFirestore.instance.collection('itens_os').doc(docId).update({
      'status': 'aguardando_montagem', // PRÓXIMA ETAPA
      'premontagem': {
        'data': Timestamp.now(),
        'operador': 'operador_premontagem'
      }
    });

    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item $codigo liberado para Montagem!'), backgroundColor: Colors.indigo)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Execução: Pré-Montagem'), backgroundColor: Colors.indigo[700]),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('osId', isEqualTo: widget.osId)
            .where('status', isEqualTo: 'aguardando_premontagem')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final itens = snapshot.data!.docs;

          if (itens.isEmpty) {
            Future.delayed(Duration.zero, () { if (mounted) Navigator.pop(context); });
            return const Center(child: Text('Todos enviados para Montagem!'));
          }

          return ListView.builder(
            itemCount: itens.length,
            itemBuilder: (context, index) {
              final doc = itens[index];
              final data = doc.data() as Map<String, dynamic>;
              final codigo = data['idCrachaTemporario'] ?? 'Item';
              final tipo = data['tipoAgente'] ?? '';

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.group_work, color: Colors.indigo), // Ícone de reunião/grupo
                  title: Text(codigo, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Tipo: $tipo'),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[700]),
                    onPressed: () => _enviarParaMontagem(doc.id, codigo),
                    child: const Text('LIBERAR'),
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