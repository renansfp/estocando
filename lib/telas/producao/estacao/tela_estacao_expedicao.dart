// Salve como: lib/telas/producao/estacao/tela_estacao_expedicao.dart
// (VERSÃO v3.0 - Atualiza o Cadastro do Equipamento ao Finalizar)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TelaEstacaoExpedicao extends StatefulWidget {
  final String osId;
  const TelaEstacaoExpedicao({super.key, required this.osId});

  @override
  State<TelaEstacaoExpedicao> createState() => _TelaEstacaoExpedicaoState();
}

class _TelaEstacaoExpedicaoState extends State<TelaEstacaoExpedicao> {

  Future<void> _expedirItem(String docId, String codigo) async {
    try {
      // 1. Ler os dados completos do Item para saber o que foi feito
      final docSnapshot = await FirebaseFirestore.instance.collection('itens_os').doc(docId).get();
      final dataItem = docSnapshot.data() as Map<String, dynamic>;
      final equipamentoId = dataItem['equipamentoId'];

      // Preparar Batch (Pacote de atualizações) para ser seguro
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // --- A. ATUALIZA O ITEM DA OS (FINALIZAÇÃO) ---
      final itemRef = FirebaseFirestore.instance.collection('itens_os').doc(docId);
      batch.update(itemRef, {
        'status': 'finalizado',
        'statusAtual': 'finalizado', // Tira da contagem da Home
        'expedicao': {
          'data': Timestamp.now(),
          'operador': 'operador_expedicao', // Aqui você pode por o usuario logado
        }
      });

      // --- B. ATUALIZA O CADASTRO DO EQUIPAMENTO (MEMÓRIA LONGO PRAZO) ---
      if (equipamentoId != null) {
        final equipRef = FirebaseFirestore.instance.collection('equipamentos').doc(equipamentoId);

        Map<String, dynamic> atualizacoesEquip = {
          'ultimaRecarga': DateFormat('MM/yyyy').format(DateTime.now()), // Sempre atualiza recarga
          'status': 'ativo', // Garante que volta a ficar ativo se estava em manutenção
        };

        // 1. Atualiza TH se foi feito
        final tipoServico = (dataItem['tipoServico'] ?? '').toString().toUpperCase();
        if (tipoServico.contains('TH') || tipoServico.contains('HIDRO')) {
          atualizacoesEquip['anoUltimoTH'] = DateFormat('yyyy').format(DateTime.now());
        }

        // 2. Atualiza Lote de Pó se houve troca
        final dadosRecarga = dataItem['recarga'] as Map<String, dynamic>?;
        if (dadosRecarga != null) {
          if (dadosRecarga['tipo'] == 'TROCA_PO') {
            // Salva o novo lote no cadastro
            atualizacoesEquip['lotePo'] = dadosRecarga['loteNumero'] ?? 'LOTE_MANUAL';
            // IMPORTANTE: Reseta a flag de substituir, pois já substituímos!
            atualizacoesEquip['substituirPo'] = false;
          }
        }

        batch.update(equipRef, atualizacoesEquip);
      }

      // Executa tudo de uma vez
      await batch.commit();

      // 2. Verifica se a OS inteira acabou (Auto-Fechamento da OS)
      await _verificarFechamentoOS();

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Item $codigo expedido e cadastro atualizado!'), backgroundColor: Colors.black87)
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _verificarFechamentoOS() async {
    // Conta quantos itens ainda não estão finalizados nessa OS
    final pendentes = await FirebaseFirestore.instance
        .collection('itens_os')
        .where('osId', isEqualTo: widget.osId)
        .where('status', isNotEqualTo: 'finalizado')
        .get();

    if (pendentes.docs.isEmpty) {
      // Se não tem pendentes, fecha a OS Principal
      await FirebaseFirestore.instance.collection('ordens_servico').doc(widget.osId).update({
        'statusLote': 'finalizada',
        'dataSaida': FieldValue.serverTimestamp(),
        'etapaAtual': 'finalizada',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estação: Expedição Final'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('osId', isEqualTo: widget.osId)
            .where('status', isEqualTo: 'aguardando_expedicao')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final itens = snapshot.data!.docs;

          if (itens.isEmpty) {
            Future.delayed(Duration.zero, () { if (mounted) Navigator.pop(context); });
            return const Center(child: Text('OS Finalizada!'));
          }

          return ListView.builder(
            itemCount: itens.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              final doc = itens[index];
              final data = doc.data() as Map<String, dynamic>;
              final codigo = data['idCrachaTemporario'] ?? 'Item';
              final tipo = data['tipoAgente'] ?? '';

              // Dados visuais para conferência
              final recarga = data['recarga'] as Map<String, dynamic>? ?? {};
              final loteUsado = recarga['loteNumero'];
              final foiTroca = recarga['tipo'] == 'TROCA_PO';

              return Card(
                elevation: 4,
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined, color: Colors.black, size: 30),
                  title: Text(codigo, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tipo: $tipo'),
                      if (foiTroca)
                        Text('Pó Trocado: Lote $loteUsado', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold))
                      else
                        const Text('Pó Reutilizado', style: TextStyle(color: Colors.orange, fontSize: 12)),
                    ],
                  ),
                  trailing: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black87),
                    icon: const Icon(Icons.local_shipping, size: 16),
                    label: const Text('EXPEDIR'),
                    onPressed: () => _expedirItem(doc.id, codigo),
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