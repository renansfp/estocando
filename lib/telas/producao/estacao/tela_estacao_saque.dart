// Salve como: lib/telas/producao/estacao/tela_estacao_saque.dart
// (VERSÃO v2.0 - Com Inspeção e Condenação)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelaEstacaoSaque extends StatefulWidget {
  final String numeroLote; // ID da OS
  const TelaEstacaoSaque({super.key, required this.numeroLote});

  @override
  State<TelaEstacaoSaque> createState() => _TelaEstacaoSaqueState();
}

class _TelaEstacaoSaqueState extends State<TelaEstacaoSaque> {
  final Color _corSetor = Colors.red[700]!;

  // --- LÓGICA DE CONDENAÇÃO (SUCATA) ---
  Future<void> _condenarItem(DocumentSnapshot itemDoc, String motivo) async {
    try {
      final dados = itemDoc.data() as Map<String, dynamic>;
      final equipId = dados['equipamentoId'];
      final codigo = dados['idCrachaTemporario'] ?? '???';

      final batch = FirebaseFirestore.instance.batch();

      // 1. Mata o Item na OS
      final itemRef = FirebaseFirestore.instance.collection('itens_os').doc(itemDoc.id);
      batch.update(itemRef, {
        'status': 'condenado',
        'statusAtual': 'condenado', // Tira do painel de produção
        'etapa': 'SUCATA',
        'motivoCondenacao': motivo,
        'saque': {
          'data': FieldValue.serverTimestamp(),
          'operador': 'operador_saque',
          'resultado': 'CONDENADO',
          'motivo': motivo,
        }
      });

      // 2. Mata o Equipamento no Inventário (Para não usar mais)
      if (equipId != null) {
        final equipRef = FirebaseFirestore.instance.collection('equipamentos').doc(equipId);
        batch.update(equipRef, {
          'status': 'baixado', // Status de "Morto"
          'motivoCondenacao': motivo,
          'dataBaixa': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (!mounted) return;
      Navigator.pop(context); // Fecha o Dialog

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item $codigo CONDENADO com sucesso!'), backgroundColor: Colors.red)
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao condenar: $e')));
    }
  }

  // --- LÓGICA DE APROVAÇÃO (FLUXO NORMAL) ---
  Future<void> _confirmarSaque(DocumentSnapshot itemDoc) async {
    try {
      final dados = itemDoc.data() as Map<String, dynamic>;
      final codigo = dados['idCrachaTemporario'] ?? '???';

      // Ler dados da triagem para saber se precisa de TH
      final triagem = dados['triagem'] as Map<String, dynamic>? ?? {};
      final bool precisaTH = triagem['testeVencido'] == true;

      String proximoStatus;
      String nomeProximaEtapa;

      if (precisaTH) {
        proximoStatus = 'aguardando_teste_hidro';
        nomeProximaEtapa = 'TESTE HIDROSTÁTICO';
      } else {
        // Se não precisa de TH, vai para PINTURA
        proximoStatus = 'aguardando_pintura';
        nomeProximaEtapa = 'PINTURA';
      }

      await FirebaseFirestore.instance.collection('itens_os').doc(itemDoc.id).update({
        'status': proximoStatus,
        'saque': {
          'data': FieldValue.serverTimestamp(),
          'operador': 'operador_saque',
          'inspecoes': {
            'interna': true,
            'rosca': true
          }
        }
      });

      if (!mounted) return;
      Navigator.pop(context); // Fecha o Dialog

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item $codigo Aprovado -> Vai para $nomeProximaEtapa'),
            backgroundColor: precisaTH ? Colors.purple : Colors.brown,
            duration: const Duration(seconds: 2),
          )
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar')));
    }
  }

  // --- INTERFACE DO DIÁLOGO ---
  void _mostrarDialogoExecucao(DocumentSnapshot itemDoc) {
    final dados = itemDoc.data() as Map<String, dynamic>;
    final codigo = dados['idCrachaTemporario'] ?? '???';
    final tipo = dados['tipoAgente'] ?? '';

    // Variáveis locais do Dialog (Estado temporário)
    bool inspInterna = false;
    bool inspRosca = false;
    final motivoController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false, // Obriga a clicar nos botões
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Execução: $codigo ($tipo)', style: TextStyle(color: _corSetor)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Inspeções de Segurança:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    CheckboxListTile(
                      title: const Text("Inspeção Interna realizada?"),
                      subtitle: const Text("Ferrugem, corrosão, sujeira"),
                      value: inspInterna,
                      activeColor: Colors.green,
                      onChanged: (v) => setStateDialog(() => inspInterna = v ?? false),
                    ),

                    CheckboxListTile(
                      title: const Text("Inspeção de Rosca realizada?"),
                      subtitle: const Text("Fios espanados ou trincas"),
                      value: inspRosca,
                      activeColor: Colors.green,
                      onChanged: (v) => setStateDialog(() => inspRosca = v ?? false),
                    ),

                    const Divider(height: 30),
                    const Text('Área de Risco:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    const SizedBox(height: 5),
                    TextField(
                      controller: motivoController,
                      decoration: const InputDecoration(
                        labelText: 'Motivo da Condenação (Se houver)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.warning, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                // BOTÃO CONDENAR
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () {
                    if (motivoController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Digite o motivo para condenar.')));
                      return;
                    }
                    _condenarItem(itemDoc, motivoController.text);
                  },
                  child: const Text("CONDENAR CILINDRO"),
                ),

                // BOTÃO CONFIRMAR
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: (inspInterna && inspRosca)
                      ? () => _confirmarSaque(itemDoc)
                      : null, // Desabilitado se não marcar os checks
                  child: const Text("CONFIRMAR SAQUE", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Execução: Saque de Válvula'),
        backgroundColor: _corSetor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('osId', isEqualTo: widget.numeroLote)
            .where('status', isEqualTo: 'aguardando_saque_valvula')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final itens = snapshot.data!.docs;

          if (itens.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).pop();
            });
            return const Center(child: Text('Todos os saques concluídos!'));
          }

          return ListView.builder(
            itemCount: itens.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              final item = itens[index];
              final dados = item.data() as Map<String, dynamic>;
              final codigo = dados['idCrachaTemporario'] ?? '---';
              final tipo = dados['tipoAgente'] ?? '';

              final triagem = dados['triagem'] as Map<String, dynamic>? ?? {};
              final bool vaiParaTH = triagem['testeVencido'] == true;

              return Card(
                elevation: 3,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.shade100,
                    child: Icon(Icons.settings_backup_restore, color: _corSetor),
                  ),
                  title: Text('Item: $codigo', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Tipo: $tipo\nPróx: ${vaiParaTH ? "TESTE HIDRO" : "PINTURA"}'),
                  trailing: const Icon(Icons.touch_app, color: Colors.blue),
                  onTap: () => _mostrarDialogoExecucao(item),
                ),
              );
            },
          );
        },
      ),
    );
  }
}