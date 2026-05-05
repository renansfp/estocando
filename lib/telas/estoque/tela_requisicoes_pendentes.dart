// lib/telas/estoque/tela_requisicoes_pendentes.dart
// Migrada para Repository Pattern — sem acesso direto ao Firestore.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/models/requisicao.dart';
import 'package:protecin_producao/models/usuario.dart';
import 'package:protecin_producao/provider/requisicao_provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';

class TelaRequisicoesPendentes extends StatelessWidget {
  const TelaRequisicoesPendentes({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<UsuarioProvider>().usuario;

    if (usuario == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Requisições Pendentes')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: context
            .read<RequisicaoProvider>()
            .streamRequisicoesPendentes(usuario.empresaId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            String msg = 'Erro ao carregar as requisições.';
            final erro = snapshot.error.toString();
            if (erro.contains('requires an index')) {
              msg = 'Erro: índice necessário no Firestore. Verifique o console do Firebase.';
            } else if (erro.contains('permission-denied')) {
              msg = 'Erro: permissão negada. Contate o administrador.';
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(msg,
                    style: TextStyle(color: Colors.red.shade700)),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma requisição pendente.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final requisicoes = <Requisicao>[];
          for (final map in snapshot.data!) {
            try {
              final req = Requisicao.fromMap(map, map['id'] as String);
              if (req.status != 'INVALIDO' &&
                  req.empresaId != 'EMPRESA_INVALIDA') {
                requisicoes.add(req);
              }
            } catch (e) {
              debugPrint('Erro ao mapear requisição ${map['id']}: $e');
            }
          }

          if (requisicoes.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma requisição pendente válida.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: requisicoes.length,
            itemBuilder: (context, index) => _CardRequisicao(
              requisicao: requisicoes[index],
              usuario: usuario,
            ),
          );
        },
      ),
    );
  }
}

// ─── Card ────────────────────────────────────────────────────────────────────

class _CardRequisicao extends StatelessWidget {
  final Requisicao requisicao;
  final Usuario usuario;

  const _CardRequisicao({required this.requisicao, required this.usuario});

  String get _titulo {
    final prefixo = switch (requisicao.subTipo) {
      'OS'             => 'OS: ${requisicao.numeroOS ?? "N/A"}',
      'Colaborador'    => 'Colaborador: ${requisicao.nomeColaborador ?? "N/A"}',
      'Venda (Pedido)' => 'Pedido: ${requisicao.numeroPedido ?? "N/A"}',
      'Venda (NF)'     => 'NF: ${requisicao.numeroNF ?? "N/A"}',
      'Itau'           => 'AG: ${requisicao.agencia ?? "N/A"}',
      _                => requisicao.subTipo,
    };
    final cliente = requisicao.nomeCliente;
    return (cliente != null && cliente.isNotEmpty)
        ? '$prefixo - ($cliente)'
        : prefixo;
  }

  // ── Diálogo de detalhes ──────────────────────────────────────────────────

  void _abrirDetalhes(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_titulo),
        contentPadding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.4,
          child: ListView.builder(
            itemCount: requisicao.itens.length,
            itemBuilder: (_, i) {
              final item = requisicao.itens[i];
              return Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.produtoNome,
                              style: const TextStyle(fontSize: 15)),
                          Text('Cód: ${item.produtoCodigo}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Text(
                      'Qtd: ${item.quantidadeSolicitada.toString().replaceAll('.', ',')}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actionsPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              _abrirDialogoReprovar(context);
            },
            child: const Text('Reprovar'),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Voltar',
                    style: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _atender(context);
                },
                child: const Text('Atender Requisição'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Diálogo de reprovação ────────────────────────────────────────────────

  void _abrirDialogoReprovar(BuildContext context) {
    final motivoController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reprovar Requisição'),
        content: TextField(
          controller: motivoController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo (opcional)',
            hintText: 'Ex: Material em falta, pedido incorreto...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Voltar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final motivo = motivoController.text;
              Navigator.of(ctx).pop();
              _reprovar(context, motivo);
            },
            child: const Text('Confirmar Reprovação'),
          ),
        ],
      ),
    );
  }

  // ── Ações ────────────────────────────────────────────────────────────────

  Future<void> _atender(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        title: Text('Processando...'),
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Flexible(child: Text('Verificando estoque e atualizando...')),
        ]),
      ),
    );

    try {
      await context.read<RequisicaoProvider>().atenderRequisicao(
        requisicao: requisicao,
        atendidoPorId: usuario.uid,
        atendidoPorNome: usuario.nome,
      );
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
            Text('Requisição atendida com sucesso! Estoque atualizado.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Erro: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  Future<void> _reprovar(BuildContext context, String motivo) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Text('Cancelando...'),
        ]),
      ),
    );

    try {
      await context.read<RequisicaoProvider>().reprovarRequisicao(
        requisicaoId: requisicao.id!,
        atendidoPorId: usuario.uid,
        atendidoPorNome: usuario.nome,
        motivo: motivo,
      );
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Requisição cancelada.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao cancelar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 3,
      child: InkWell(
        onTap: () => _abrirDetalhes(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_titulo,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Por: ${requisicao.solicitanteNome}',
                      style: const TextStyle(
                          fontSize: 14, color: Colors.black54),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    DateFormat('dd/MM/yy HH:mm')
                        .format(requisicao.dataSolicitacao),
                    style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${requisicao.itens.length} '
                    '${requisicao.itens.length == 1 ? "item" : "itens"} solicitados',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}