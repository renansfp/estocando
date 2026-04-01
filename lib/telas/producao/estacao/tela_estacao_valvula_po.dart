// lib/telas/producao/estacao/tela_estacao_valvula_po.dart
// Ticker rápido — mesmo padrão da Lixa. Bipar = confirmar = avançar.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';
import 'package:protecin_producao/widgets/botao_condenar.dart';

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

  Future<void> _confirmarValvula(DocumentSnapshot itemDoc) async {
    if (_processando) return;
    setState(() => _processando = true);

    try {
      final dados = itemDoc.data() as Map<String, dynamic>;
      final cracha = dados['idCrachaTemporario'] ?? '???';
      final List<String> roteiro = List<String>.from(dados['roteiro'] ?? []);

      final index = roteiro.indexOf('manutencao_valvula_po');
      if (index == -1 || index >= roteiro.length - 1) {
        throw 'Próxima etapa não encontrada no roteiro.';
      }

      final proximaEstacao = roteiro[index + 1];
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // 1. Avança o item
      batch.update(itemDoc.reference, {
        'status': 'aguardando_$proximaEstacao',
        'manutencao_valvula_po': {
          'data': FieldValue.serverTimestamp(),
          'operador': 'operador_valvula_po',
        },
      });

      // 2. Se for o último, atualiza a OS
      final queryPendentes = await firestore
          .collection('itens_os')
          .where('osId', isEqualTo: widget.osId)
          .where('status', isEqualTo: 'aguardando_manutencao_valvula_po')
          .get();

      if (queryPendentes.docs.length <= 1) {
        final osRef = firestore.collection('ordens_servico').doc(widget.osId);
        batch.update(osRef, {
          'etapaAtual': proximaEstacao,
          'dataFimValvulaPo': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$cracha ✅ → ${proximaEstacao.toUpperCase()}'),
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

    final query = await FirebaseFirestore.instance
        .collection('itens_os')
        .where('osId', isEqualTo: widget.osId)
        .where('idCrachaTemporario', isEqualTo: idCracha)
        .where('status', isEqualTo: 'aguardando_manutencao_valvula_po')
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      await _confirmarValvula(query.docs.first);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Crachá não encontrado ou já processado.')),
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
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('itens_os')
                  .where('osId', isEqualTo: widget.osId)
                  .where('status', isEqualTo: 'aguardando_manutencao_valvula_po')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final itens = snapshot.data!.docs;

                if (itens.isEmpty) return _buildConcluido();

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: itens.length,
                  itemBuilder: (context, index) {
                    final item = itens[index];
                    final d = item.data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        leading: Icon(Icons.handyman, color: _corSetor),
                        title: Text('Crachá: ${d['idCrachaTemporario']}'),
                        subtitle: Text(
                            '${d['tipoAgente']} ${d['capacidade'] ?? ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BotaoCondenar(itemDoc: item, etapa: 'manutencao_valvula_po'),
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green),
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