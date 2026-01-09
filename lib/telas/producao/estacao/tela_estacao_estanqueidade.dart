import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelaEstacaoEstanqueidade extends StatelessWidget {
  final String osId;
  // NOVOS CAMPOS PARA O FILTRO
  final List<String> filtrosAgente;
  final String titulo;

  const TelaEstacaoEstanqueidade({
    super.key,
    required this.osId,
    required this.filtrosAgente,
    required this.titulo,
  });

  Future<void> _aprovar(BuildContext context, String docId) async {
    await FirebaseFirestore.instance.collection('itens_os').doc(docId).update({
      'status': 'aguardando_premontagem',
      'estanqueidade': {
        'aprovado': true,
        'data': Timestamp.now(),
        'operador': 'operador_teste'
      }
    });
  }

  Future<void> _reprovar(BuildContext context, String docId) async {
    await FirebaseFirestore.instance.collection('itens_os').doc(docId).update({
      'status': 'aguardando_recarga', // Volta para recarga corrigir
      'estanqueidade': {
        'aprovado': false,
        'motivo': 'Vazamento detectado',
        'data': Timestamp.now()
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reprovado! Voltou para Recarga.'), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo), backgroundColor: Colors.lightBlue[800]),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('osId', isEqualTo: osId)
            .where('status', isEqualTo: 'aguardando_estanqueidade')
        // FILTRO DO SETOR
            .where('tipoAgente', whereIn: filtrosAgente)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final itens = snapshot.data!.docs;

          if (itens.isEmpty) {
            // Se acabou os itens DESTE TIPO, volta.
            Future.delayed(Duration.zero, () { if (context.mounted) Navigator.pop(context); });
            return const Center(child: Text('Lote finalizado para este setor!'));
          }

          return ListView.builder(
            itemCount: itens.length,
            itemBuilder: (context, index) {
              final doc = itens[index];
              final data = doc.data() as Map<String, dynamic>;
              final codigo = data['idCrachaTemporario'] ?? 'Item';
              final tipo = data['tipoAgente']?.toString().toUpperCase() ?? '';

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.water_drop, size: 30, color: Colors.blue),
                  title: Text(codigo),
                  subtitle: Text('Tipo: $tipo'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.thumb_down, color: Colors.red),
                        onPressed: () => _reprovar(context, doc.id),
                      ),
                      IconButton(
                        icon: const Icon(Icons.thumb_up, color: Colors.green),
                        onPressed: () => _aprovar(context, doc.id),
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