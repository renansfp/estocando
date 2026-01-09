import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelaEstacaoValvula extends StatefulWidget {
  final String osId;
  const TelaEstacaoValvula({Key? key, required this.osId}) : super(key: key);

  @override
  _TelaEstacaoValvulaState createState() => _TelaEstacaoValvulaState();
}

class _TelaEstacaoValvulaState extends State<TelaEstacaoValvula> {
  // Cor do setor Válvula (Teal)
  final Color _corSetor = Colors.teal[700]!;

  Future<void> _confirmarManutencao(String itemId, String codigo) async {
    try {
      await FirebaseFirestore.instance.collection('itens_os').doc(itemId).update({
        'status': 'aguardando_saque_valvula', // PRÓXIMO PASSO OBRIGATÓRIO (Passo 6)
        'valvula_manutencao': {
          'data': FieldValue.serverTimestamp(),
          'operador': 'operador_valvula',
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item $codigo enviado para SAQUE DE VÁLVULA'),
            duration: const Duration(milliseconds: 800),
            backgroundColor: Colors.indigo,
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
        title: const Text('Execução: Manutenção de Válvula'),
        backgroundColor: _corSetor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('osId', isEqualTo: widget.osId)
            .where('status', isEqualTo: 'aguardando_manutencao_valvula')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final itens = snapshot.data!.docs;

          // Lixeiro Automático (Fecha a tela quando o lote acaba)
          if (itens.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Manutenção concluída! Lote enviado para Saque.'), backgroundColor: Colors.green),
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
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal[100],
                    child: Icon(Icons.settings_applications, color: _corSetor),
                  ),
                  title: Text('Extintor: $codigo', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Tipo: ${tipo.toUpperCase()}'),
                  trailing: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _corSetor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('CONCLUÍDO'),
                    onPressed: () => _confirmarManutencao(item.id, codigo),
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