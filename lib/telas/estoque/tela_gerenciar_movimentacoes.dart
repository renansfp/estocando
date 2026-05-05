import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/provider/movimentacao_provider.dart';
import 'package:protecin_producao/telas/estoque/tela_movimentacao.dart';

class TelaGerenciarMovimentacoes extends StatefulWidget {
  const TelaGerenciarMovimentacoes({super.key});

  @override
  State<TelaGerenciarMovimentacoes> createState() =>
      _TelaGerenciarMovimentacoesState();
}

class _TelaGerenciarMovimentacoesState
    extends State<TelaGerenciarMovimentacoes> {

  void _mostrarDialogoConfirmacao(
      BuildContext context, Map<String, dynamic> mov) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: const Text(
              'Você tem certeza? Esta ação irá estornar o valor no estoque e não pode ser desfeita.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.of(ctx).pop();
                _excluirMovimentacao(mov);
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _excluirMovimentacao(Map<String, dynamic> mov) async {
    final usuario =
        Provider.of<UsuarioProvider>(context, listen: false).usuario;
    if (usuario == null) return;
    try {
      await context.read<MovimentacaoProvider>().excluirComEstorno(
        movimentacaoId: mov['id'],
        dadosMovimentacao: mov,
        usuarioId: usuario.uid,
        usuarioNome: usuario.nome,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Movimentação excluída com sucesso!'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<UsuarioProvider>().usuario;
    final empresaId = usuario?.empresaId;
    final isAdmin = usuario?.permissao == 'admin';

    if (empresaId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar Movimentações')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: context
            .read<MovimentacaoProvider>()
            .streamMovimentacoesPorEmpresa(empresaId, limit: 50),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text('Ocorreu um erro: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhuma movimentação encontrada.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final mov = snapshot.data![index];
              final bool isEntrada = mov['tipo'] == 'entrada';

              DateTime dataMov;
              final dataValue = mov['data'];
              if (dataValue is Timestamp) {
                dataMov = dataValue.toDate();
              } else if (dataValue is String) {
                dataMov = DateTime.tryParse(dataValue) ?? DateTime.now();
              } else {
                dataMov = DateTime.now();
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: Icon(
                    isEntrada ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isEntrada ? Colors.green : Colors.red,
                  ),
                  title: Text(mov['produtoNome'] ?? 'Produto não informado'),
                  subtitle: Text(
                      'Qtd: ${mov['quantidade']} | ${DateFormat('dd/MM/yyyy HH:mm').format(dataMov)}'),
                  trailing: isAdmin
                      ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TelaMovimentacao(
                              movimentacaoParaEditar: mov,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            _mostrarDialogoConfirmacao(context, mov),
                      ),
                    ],
                  )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}