// lib/telas/producao/estacao/tela_estacao_valvula_po.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/widgets/botao_condenar.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';

class TelaEstacaoValvulaPo extends StatefulWidget {
  final String osId;
  const TelaEstacaoValvulaPo({super.key, required this.osId});

  @override
  State<TelaEstacaoValvulaPo> createState() => _TelaEstacaoValvulaPoState();
}

class _TelaEstacaoValvulaPoState extends State<TelaEstacaoValvulaPo> {
  final Color _corSetor = Colors.deepOrange.shade700;
  final TextEditingController _scannerController = TextEditingController();
  bool _processando = false;

  String _limparCodigo(String valor) {
    String limpo = valor.trim().toUpperCase();
    if (limpo.contains('HTTP')) limpo = limpo.split('/').last;
    return limpo.replaceAll('R-', '');
  }

  Future<void> _confirmarValvula(Map<String, dynamic> item) async {
    if (_processando) return;
    setState(() => _processando = true);

    try {
      final cracha = item['idCrachaTemporario'] ?? '???';
      final List<String> roteiro = List<String>.from(item['roteiro'] ?? []);

      final index = roteiro.indexOf('manutencao_valvula_po');
      if (index == -1 || index >= roteiro.length - 1) {
        throw 'Próxima etapa não encontrada no roteiro.';
      }
      final proximaEstacao = roteiro[index + 1];

      await context.read<ItemOsProvider>().confirmarEtapa(
        itemId: item['id'],
        dadosItem: {
          'manutencao_valvula_po': {
            'data': DateTime.now(),
            'operador': 'operador_valvula_po',
          },
        },
        osId: widget.osId,
        statusPendente: 'aguardando_manutencao_valvula_po',
        proximaEstacao: proximaEstacao,
        dadosOsExtra: {'dataFimValvulaPo': DateTime.now()},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$cracha -> ${proximaEstacao.toUpperCase()}'),
          backgroundColor: Colors.green,
          duration: const Duration(milliseconds: 1200),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _processarBipe(String codigo) async {
    if (codigo.isEmpty) return;
    final idCracha = _limparCodigo(codigo);

    final item = await context.read<ItemOsProvider>().buscarItemPorCracha(
      widget.osId,
      idCracha,
      'aguardando_manutencao_valvula_po',
    );

    if (item != null) {
      await _confirmarValvula(item);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
              Text('Crachá não encontrado ou já processado.')),
        );
      }
    }
    _scannerController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Válvula Pó: OS ${widget.osId}'),
        backgroundColor: _corSetor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () =>
              Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.deepOrange.shade50,
            child: CampoComScanner(
              controller: _scannerController,
              label: 'Bipar Crachá — Válvula OK',
              onSubmitted: _processarBipe,
            ),
          ),
          if (_processando) const LinearProgressIndicator(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: context
                  .read<ItemOsProvider>()
                  .streamItensPorOsEStatus(
                  widget.osId, 'aguardando_manutencao_valvula_po'),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final itens = snapshot.data!;
                if (itens.isEmpty) return _buildConcluido();

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: itens.length,
                  itemBuilder: (context, index) {
                    final item = itens[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(Icons.handyman, color: _corSetor),
                        title: Text(
                            'Crachá: ${item['idCrachaTemporario']}'),
                        subtitle: Text(
                            '${item['tipoAgente']} ${item['capacidade'] ?? ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BotaoCondenar(
                                item: item,
                                etapa: 'manutencao_valvula_po'),
                            IconButton(
                              icon: const Icon(Icons.check_circle,
                                  color: Colors.green),
                              onPressed: () => _confirmarValvula(item),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConcluido() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified, size: 80, color: Colors.green),
          const SizedBox(height: 20),
          const Text('Válvulas Concluídas!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Todos os extintores seguiram para recarga.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('VOLTAR PARA A FILA'),
          ),
        ],
      ),
    );
  }
}