// lib/telas/producao/estacao/tela_estacao_valvula_po.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/models/usuario.dart';
import 'package:protecin_producao/provider/equipamento_provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/widgets/botao_condenar.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';
import 'package:protecin_producao/widgets/dialog_pecas_trocadas.dart';
import 'package:protecin_producao/widgets/seletor_operador.dart';

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

  Stream<List<Map<String, dynamic>>>? _streamItens;
  String? _empresaIdEscutando;
  List<Map<String, dynamic>> _itensSnapshot = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final empresaId = context.watch<UsuarioProvider>().usuario?.empresaId;
    if (empresaId != null &&
        empresaId.isNotEmpty &&
        empresaId != _empresaIdEscutando) {
      _empresaIdEscutando = empresaId;
      _streamItens = context
          .read<ItemOsProvider>()
          .streamItensPorOsEStatus(
          widget.osId, 'aguardando_manutencao_valvula_po', empresaId);
    }
  }

  String _limparCodigo(String valor) {
    String limpo = valor.trim().toUpperCase();
    if (limpo.contains('HTTP')) limpo = limpo.split('/').last;
    return limpo.replaceAll('R-', '');
  }

  Future<void> _confirmarValvula(Map<String, dynamic> item) async {
    if (_processando) return;

    // ── Captura providers ANTES de qualquer await ──────────────────────────
    final itemOsProvider      = context.read<ItemOsProvider>();
    final equipamentoProvider = context.read<EquipamentoProvider>();
    final empresaId           = context.read<UsuarioProvider>().usuario?.empresaId ?? '';

    // ── Busca o equipamento para ter tipo/capacidade/fabricante ───────────
    final equipamentoId = item['equipamentoId'] as String? ?? '';
    final equip = equipamentoId.isNotEmpty
        ? await equipamentoProvider.buscarPorId(equipamentoId)
        : null;

    // ── Abre o dialog de peças ─────────────────────────────────────────────
    if (!mounted) return;
    final pecasSelecionadas = await mostrarDialogPecasTrocadas(
      context              : context,
      // Peças disponíveis na manutenção de válvula Pó
      legendasDisponiveis  : [1, 4, 9, 13, 15, 16, 20, 26],
      // O-ring e Pera sempre trocados
      legendasObrigatorias : [13, 15],
      tipoEquipamento      : equip?.tipo      ?? item['tipoAgente'] ?? '',
      capacidadeEquipamento: equip?.capacidade ?? item['capacidade'] ?? '',
      fabricanteEquipamento: equip?.fabricante ?? '',
    );

    // Operador cancelou
    if (pecasSelecionadas == null) return;

    setState(() => _processando = true);
    try {
      final cracha = item['idCrachaTemporario'] ?? '???';
      final List<String> roteiro = List<String>.from(item['roteiro'] ?? []);

      final index = roteiro.indexOf('manutencao_valvula_po');
      if (index == -1 || index >= roteiro.length - 1) {
        throw 'Próxima etapa não encontrada no roteiro.';
      }
      final proximaEstacao = roteiro[index + 1];

      // ── Confirma etapa ─────────────────────────────────────────────────
      await itemOsProvider.confirmarEtapa(
        itemId: item['id'],
        dadosItem: {
          'manutencao_valvula_po': {
            'data': DateTime.now(),
            'operador': context.read<UsuarioProvider>().operadorAtivo?.nome ?? 'Operador',
          },
        },
        osId: widget.osId,
        statusPendente: 'aguardando_manutencao_valvula_po',
        proximaEstacao: proximaEstacao,
        dadosOsExtra: {'dataFimValvulaPo': DateTime.now()},
      );

      // ── Registra peças e baixa estoque ────────────────────────────────
      if (pecasSelecionadas.isNotEmpty) {
        await itemOsProvider.registrarPecasTrocadas(
          itemId   : item['id'],
          osId     : widget.osId,
          empresaId: empresaId,
          pecas    : pecasSelecionadas,
        );
      }

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
    final empresaId = context.read<UsuarioProvider>().usuario?.empresaId ?? '';
    // Busca local — scan instantâneo (sem round-trip Firestore)
    Map<String, dynamic>? item;
    if (_itensSnapshot.isNotEmpty) {
      try {
        item = _itensSnapshot.firstWhere(
              (i) => i['idCrachaTemporario']?.toString() == idCracha,
        );
      } catch (_) {
        item = null;
      }
    }
    // Fallback ao Firestore apenas se o snapshot ainda não chegou
    if (item == null && _itensSnapshot.isEmpty) {
      item = await context.read<ItemOsProvider>().buscarItemPorCracha(
        widget.osId, idCracha, 'aguardando_manutencao_valvula_po', empresaId,
      );
    }


    if (item != null) {
      await _confirmarValvula(item);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Crachá não encontrado ou já processado.')),
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
        actions: [
          const SeletorOperador(estacao: EstacaoProducao.valvulaPo),
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () =>
                Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ],
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
              stream: _streamItens,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                _itensSnapshot = snapshot.data!;
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