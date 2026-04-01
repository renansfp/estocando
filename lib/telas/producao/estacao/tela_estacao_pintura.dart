import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';
import 'package:protecin_producao/widgets/botao_condenar.dart';

class TelaEstacaoPintura extends StatefulWidget {
  final String osId;
  const TelaEstacaoPintura({super.key, required this.osId});

  @override
  State<TelaEstacaoPintura> createState() => _TelaEstacaoPinturaState();
}

class _TelaEstacaoPinturaState extends State<TelaEstacaoPintura> {
  final TextEditingController _scannerController = TextEditingController();
  bool _processandoBipe = false;

  String _limparCodigo(String valor) {
    String limpo = valor.trim().toUpperCase();
    if (limpo.contains('HTTP')) limpo = limpo.split('/').last;
    return limpo.replaceAll('R-', '');
  }

  Future<void> _concluirPintura(String docId, Map<String, dynamic> dados) async {
    setState(() => _processandoBipe = true);
    try {
      final List<String> roteiro = List<String>.from(dados['roteiro'] ?? []);
      final int index = roteiro.indexOf('pintura');
      final String proxima = (index != -1 && index + 1 < roteiro.length)
          ? roteiro[index + 1]
          : 'recarga_abc';

      await FirebaseFirestore.instance.collection('itens_os').doc(docId).update({
        'status': 'aguardando_$proxima',
        'dataPintura': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Pintura finalizada!'),
              duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _processandoBipe = false);
    }
  }

  Future<void> _processarBipe(String codigo) async {
    if (codigo.isEmpty) return;
    final idCracha = _limparCodigo(codigo);

    final query = await FirebaseFirestore.instance
        .collection('itens_os')
        .where('osId', isEqualTo: widget.osId)
        .where('idCrachaTemporario', isEqualTo: idCracha)
        .where('status', isEqualTo: 'aguardando_pintura')
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      await _concluirPintura(
          query.docs.first.id, query.docs.first.data() as Map<String, dynamic>);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cilindro não encontrado ou já pintado.')),
        );
      }
    }
    _scannerController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pintura: OS ${widget.osId}'),
        backgroundColor: Colors.brown.shade700,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            color: Colors.brown.shade50,
            child: CampoComScanner(
              controller: _scannerController,
              label: 'Bipar Crachá para Concluir Pintura',
              onSubmitted: _processarBipe,
            ),
          ),
          if (_processandoBipe) const LinearProgressIndicator(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('itens_os')
                  .where('osId', isEqualTo: widget.osId)
                  .where('status', isEqualTo: 'aguardando_pintura')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final itens = snapshot.data!.docs;

                if (itens.isEmpty) return _buildConcluido();

                return ListView.builder(
                  itemCount: itens.length,
                  itemBuilder: (context, index) {
                    final item = itens[index];
                    final dados = item.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      elevation: 2,
                      child: ListTile(
                        leading: const Icon(Icons.format_paint,
                            color: Colors.brown),
                        title: Text(
                          'Crachá: ${dados['idCrachaTemporario']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                            '${dados['tipoAgente']} - ${dados['capacidade'] ?? dados['carga'] ?? ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BotaoCondenar(
                                itemDoc: item, etapa: 'pintura'),
                            ElevatedButton(
                              onPressed: () =>
                                  _concluirPintura(item.id, dados),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('CONCLUIR'),
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
          const Icon(Icons.check_circle, size: 80, color: Colors.green),
          const SizedBox(height: 20),
          const Text('OS Totalmente Pintada!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('VOLTAR'),
          ),
        ],
      ),
    );
  }
}