// lib/telas/producao/estacao/tela_execucao_recarga.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:protecin_producao/utils/mapeador_custos.dart';

class TelaExecucaoRecarga extends StatefulWidget {
  final DocumentSnapshot itemDoc;
  final String osId;

  const TelaExecucaoRecarga({super.key, required this.itemDoc, required this.osId});

  @override
  State<TelaExecucaoRecarga> createState() => _TelaExecucaoRecargaState();
}

class _TelaExecucaoRecargaState extends State<TelaExecucaoRecarga> {
  bool _carregando = false;
  String? _loteSelecionadoId;
  String? _loteSelecionadoNumero;
  final TextEditingController _pesoCo2Controller = TextEditingController();

  double _extrairPeso(String? capacidade) {
    if (capacidade == null || capacidade.isEmpty) return 0.0;
    String limpo = capacidade.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(limpo) ?? 0.0;
  }

  String _obterCodigoMestre(String agente, double peso) {
    String a = agente.toUpperCase();
    if (a.contains('ABC')) {
      return [2.3, 4.5, 9.0, 55.0].contains(peso) ? '911' : '910';
    }
    if (a.contains('BC')) return '2504';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final String equipId = widget.itemDoc['equipamentoId'] ?? '';
    final Color corRecarga = Colors.green.shade700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Execução de Recarga'),
        backgroundColor: corRecarga,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('equipamentos').doc(equipId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final d = snapshot.data!.data() as Map<String, dynamic>;
          final String agente = (d['tipo'] ?? '').toString().toUpperCase();
          final double pesoCapacidade = _extrairPeso(d['capacidade']);
          final bool isPo = agente.contains('ABC') || agente.contains('BC');
          final bool substituir = d['substituirPo'] == true;
          final String codigoMestre = _obterCodigoMestre(agente, pesoCapacidade);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCardInfo(d, corRecarga),
                const SizedBox(height: 20),
                _buildCardDecisao(substituir, d['lotePo']),
                const SizedBox(height: 20),
                if (isPo && substituir)
                  _buildSeletorLotes(codigoMestre, pesoCapacidade)
                else if (agente.contains('CO2'))
                  _buildCampoPesoCO2(),
                const SizedBox(height: 40),
                SizedBox(
                  height: 60,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: Text(_carregando ? "PROCESSANDO..." : "CONFIRMAR E BAIXAR"),
                    style: ElevatedButton.styleFrom(backgroundColor: corRecarga, foregroundColor: Colors.white),
                    onPressed: _carregando ? null : () => _processarRecarga(d, codigoMestre),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardInfo(Map<String, dynamic> d, Color cor) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('CRACHÁ: ${widget.itemDoc['idCrachaTemporario']}',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cor)),
            const Divider(),
            Text("${d['tipo']} - ${d['capacidade']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            Text("Fabricante: ${d['fabricante']}", style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildCardDecisao(bool substituir, String? loteAtual) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: substituir ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: substituir ? Colors.orange : Colors.green),
      ),
      child: Row(
        children: [
          Icon(substituir ? Icons.swap_horiz : Icons.refresh, color: substituir ? Colors.orange : Colors.green),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(substituir ? "CARGA NOVA (TROCA)" : "REAPROVEITAMENTO",
                    style: TextStyle(fontWeight: FontWeight.bold, color: substituir ? Colors.orange.shade900 : Colors.green.shade900)),
                Text(substituir ? "Baixar do estoque" : "Lote original: ${loteAtual ?? 'N/D'}"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeletorLotes(String codigoMestre, double pesoNecessario) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("SELECIONE O LOTE DE PÓ QUE ESTÁ USANDO:", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('produtos')
              .where('codigo', isEqualTo: codigoMestre)
              .limit(1).snapshots(),
          builder: (context, prodSnap) {
            if (!prodSnap.hasData || prodSnap.data!.docs.isEmpty) return const Text("Produto não encontrado no estoque.");
            String prodId = prodSnap.data!.docs.first.id;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('produtos')
                  .doc(prodId)
                  .collection('lotes')
                  .snapshots(),
              builder: (context, loteSnap) {
                if (loteSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final lotes = loteSnap.data?.docs ?? [];
                if (lotes.isEmpty) return const Padding(padding: EdgeInsets.all(8.0), child: Text("⚠️ Nenhum lote encontrado."));

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: lotes.length,
                  itemBuilder: (context, index) {
                    var lote = lotes[index].data() as Map<String, dynamic>;
                    var loteId = lotes[index].id;
                    bool selecionado = _loteSelecionadoId == loteId;

                    return Card(
                      color: selecionado ? Colors.green.shade50 : Colors.white,
                      child: ListTile(
                        leading: Icon(Icons.layers, color: selecionado ? Colors.green : Colors.grey),
                        title: Text("Lote: ${lote['numero'] ?? 'S/N'}"),
                        subtitle: Text("Saldo: ${lote['quantidadeAtual'] ?? '0'} kg"),
                        onTap: () => setState(() {
                          _loteSelecionadoId = loteId;
                          _loteSelecionadoNumero = lote['numero']?.toString();
                        }),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCampoPesoCO2() {
    return TextFormField(
      controller: _pesoCo2Controller,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: "Peso Final da Carga (kg)", border: OutlineInputBorder(), suffixText: "kg"),
    );
  }

  Future<void> _processarRecarga(Map<String, dynamic> dadosEquip, String codigoMestre) async {
    final bool substituirPo = dadosEquip['substituirPo'] == true;
    final String agente = (dadosEquip['tipo'] ?? '').toString().toUpperCase();
    final bool isPo = agente.contains('ABC') || agente.contains('BC');

    if (isPo && substituirPo && _loteSelecionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selecione um lote de pó!"), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _carregando = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final double pesoCarga = _extrairPeso(dadosEquip['capacidade']);
      String loteFinal = dadosEquip['lotePo'] ?? 'N/A';
      String tipoRegistro = "REAPROVEITAMENTO";

      if (isPo && substituirPo) {
        tipoRegistro = "CARGA NOVA";
        loteFinal = _loteSelecionadoNumero!;

        final prodQuery = await firestore.collection('produtos').where('codigo', isEqualTo: codigoMestre).limit(1).get();
        if (prodQuery.docs.isEmpty) throw "Produto mestre não encontrado!";
        final String produtoId = prodQuery.docs.first.id;

        batch.update(firestore.collection('produtos').doc(produtoId).collection('lotes').doc(_loteSelecionadoId),
            {'quantidadeAtual': FieldValue.increment(-pesoCarga)});
        batch.update(firestore.collection('produtos').doc(produtoId), {'quantidadeAtual': FieldValue.increment(-pesoCarga)});

        batch.set(firestore.collection('movimentacoes').doc(), {
          'data': FieldValue.serverTimestamp(),
          'produtoId': produtoId,
          'loteId': _loteSelecionadoId,
          'tipo': 'saida',
          'quantidade': pesoCarga,
          'numeroOS': widget.osId,
          'equipamento': widget.itemDoc['idCrachaTemporario'],
          'operador': 'producao_recarga',
          'clienteNome': dadosEquip['clienteNome'],
          'cc': MapeadorCustos.obterCC('RECARGA E TESTES EQUIPAMENTOS PQS'),
        });
      }

      double pesoFinalRegistrado = pesoCarga;
      if (agente.contains('CO2') && _pesoCo2Controller.text.isNotEmpty) {
        pesoFinalRegistrado = double.tryParse(_pesoCo2Controller.text.replaceAll(',', '.')) ?? pesoCarga;
      }

      batch.update(widget.itemDoc.reference, {
        'status': 'aguardando_estanqueidade',
        'recarga': {
          'data': FieldValue.serverTimestamp(),
          'tipo': tipoRegistro,
          'lote': loteFinal,
          'peso': pesoFinalRegistrado,
          'statusConcluido': true,
        }
      });

      final String equipId = widget.itemDoc['equipamentoId'];
      final String dataAtual = "${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}";
      final equipRef = firestore.collection('equipamentos').doc(equipId);

      // 1. PREPARA OS DADOS DO EQUIPAMENTO (O PAI)
      Map<String, dynamic> updateEquip = {
        'ultimaRecarga': dataAtual,
        'lotePo': loteFinal,
        'substituirPo': false,
      };

      // A REGRA DA FOTO: Se foi carga nova, a Protecin assume a origem e reseta a validade
      if (isPo && substituirPo) {
        updateEquip['origemSelo'] = 'NOSSA'; // Faz a tela de cadastro mostrar "Nossa Empresa"
        updateEquip['ultimaTrocaPo'] = dataAtual; // Define a nova base para o cálculo de 5 anos
      }

      // AQUI VOCÊ INSERE NO BATCH
      batch.update(equipRef, updateEquip);

      // 2. ATUALIZAÇÃO DO ITEM_OS (O FILHO)
      batch.update(widget.itemDoc.reference, {
        'status': 'aguardando_estanqueidade',
        'recarga': {
          'data': FieldValue.serverTimestamp(),
          'tipo': tipoRegistro,
          'lote': loteFinal,
          'peso': pesoFinalRegistrado,
          'statusConcluido': true,
        }
      });


      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recarga confirmada!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }
}