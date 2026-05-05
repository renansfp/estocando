import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';

class TelaEstacaoValvula extends StatefulWidget {
  final String osId;
  const TelaEstacaoValvula({Key? key, required this.osId}) : super(key: key);

  @override
  _TelaEstacaoValvulaState createState() => _TelaEstacaoValvulaState();
}

class _TelaEstacaoValvulaState extends State<TelaEstacaoValvula> {
  final Color _corSetor = Colors.teal[700]!;

  Future<void> _confirmarManutencao(Map<String, dynamic> item) async {
    try {
      await context.read<ItemOsProvider>().confirmarEtapa(
        itemId: item['id'],
        dadosItem: {
          'valvula_manutencao': {
            'data': DateTime.now(),
            'operador': 'operador_valvula',
          }
        },
        osId: widget.osId,
        statusPendente: 'aguardando_manutencao_valvula',
        proximaEstacao: 'saque_valvula',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Item ${item['idCrachaTemporario']} enviado para SAQUE DE VÁLVULA'),
          duration: const Duration(milliseconds: 800),
          backgroundColor: Colors.indigo,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Erro ao salvar')));
      }
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
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: context
            .read<ItemOsProvider>()
            .streamItensPorOsEStatus(widget.osId, 'aguardando_manutencao_valvula'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final itens = snapshot.data!;

          // Fecha automaticamente quando o lote acaba
          if (itens.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Manutenção concluída! Lote enviado para Saque.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            });
            return Container(color: Colors.white);
          }

          return ListView.builder(
            itemCount: itens.length,
            itemBuilder: (context, index) {
              final item = itens[index];
              final codigo = item['idCrachaTemporario'] ?? '???';
              final tipo = item['tipoAgente'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal[100],
                    child: Icon(Icons.settings_applications, color: _corSetor),
                  ),
                  title: Text('Extintor: $codigo',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Tipo: ${tipo.toUpperCase()}'),
                  trailing: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _corSetor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('CONCLUÍDO'),
                    onPressed: () => _confirmarManutencao(item),
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