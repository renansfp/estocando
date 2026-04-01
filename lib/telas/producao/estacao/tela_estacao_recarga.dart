import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_execucao_recarga.dart';

class TelaEstacaoRecarga extends StatefulWidget {
  final String osId;
  final List<String> filtrosAgente;

  const TelaEstacaoRecarga({super.key, required this.osId, required this.filtrosAgente});

  @override
  State<TelaEstacaoRecarga> createState() => _TelaEstacaoRecargaState();
}

class _TelaEstacaoRecargaState extends State<TelaEstacaoRecarga> {
  final TextEditingController _scannerController = TextEditingController();

  String _limparCodigo(String valor) {
    String limpo = valor.trim().toUpperCase();
    if (limpo.contains('HTTP')) limpo = limpo.split('/').last;
    return limpo.replaceAll('R-', '');
  }

  Future<void> _processarBipe(String codigo) async {
    if (codigo.isEmpty) return;
    String idCracha = _limparCodigo(codigo);

    final query = await FirebaseFirestore.instance
        .collection('itens_os')
        .where('osId', isEqualTo: widget.osId)
        .where('idCrachaTemporario', isEqualTo: idCracha)
        .get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      final dados = doc.data();
      String ag = dados['tipoAgente']?.toString().toUpperCase() ?? '';

      // TRAVA DE AGENTE: Evita ABC na tela de BC
      bool agenteBate = widget.filtrosAgente.any((f) {
        if (f.toUpperCase() == "BC") return ag == "BC";
        return ag.contains(f.toUpperCase());
      });

      if (agenteBate && dados['status'].toString().contains('recarga')) {
        _irParaExecucao(doc);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agente incorreto para esta bancada.')));
      }
    }
    _scannerController.clear();
  }

  void _irParaExecucao(DocumentSnapshot doc) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => TelaExecucaoRecarga(itemDoc: doc, osId: widget.osId)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Recarga: OS ${widget.osId}'), backgroundColor: Colors.green.shade900),
      body: Column(
        children: [
          Container(padding: const EdgeInsets.all(12), child: CampoComScanner(controller: _scannerController, label: 'Bipar para Recarregar', onSubmitted: _processarBipe)),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('itens_os').where('osId', isEqualTo: widget.osId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final itens = snapshot.data!.docs.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  String ag = d['tipoAgente']?.toString().toUpperCase() ?? '';
                  String st = d['status']?.toString().toLowerCase() ?? '';

                  // FILTRO RIGOROSO: ABC não entra em BC
                  bool agenteOk = widget.filtrosAgente.any((f) {
                    if (f.toUpperCase() == "BC") return ag == "BC";
                    return ag.contains(f.toUpperCase());
                  });

                  return agenteOk && st.contains('recarga');
                }).toList();

                if (itens.isEmpty) return const Center(child: Text("Nenhum item pronto para esta bancada."));

                return ListView.builder(
                  itemCount: itens.length,
                  itemBuilder: (context, index) {
                    final d = itens[index].data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.ev_station, color: Colors.green),
                        title: Text('Crachá: ${d['idCrachaTemporario']}'),
                        subtitle: Text('${d['tipoAgente']} ${d['capacidade'] ?? d['carga'] ?? ''}'),
                        onTap: () => _irParaExecucao(itens[index]),
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
}