import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';
import 'package:protecin_producao/widgets/botao_condenar.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_ensaio_th.dart';
import 'package:protecin_producao/telas/estoque/tela_criar_requisicao.dart';
import 'package:protecin_producao/utils/mapeador_custos.dart';

class TelaEstacaoTH extends StatefulWidget {
  final String osIdAtual;
  const TelaEstacaoTH({super.key, required this.osIdAtual});

  @override
  State<TelaEstacaoTH> createState() => _TelaEstacaoTHState();
}

class _TelaEstacaoTHState extends State<TelaEstacaoTH> {
  final TextEditingController _scannerController = TextEditingController();

  String _limparCodigo(String valor) {
    String limpo = valor.trim().toUpperCase();
    if (limpo.contains('HTTP')) limpo = limpo.split('/').last;
    return limpo.replaceAll('R-', '');
  }

  Future<void> _processarBipe(String codigo) async {
    if (codigo.isEmpty) return;
    final idCracha = _limparCodigo(codigo);

    try {
      final query = await FirebaseFirestore.instance
          .collection('itens_os')
          .where('osId', isEqualTo: widget.osIdAtual)
          .where('idCrachaTemporario', isEqualTo: idCracha)
          .where('status', isEqualTo: 'aguardando_th')
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        _irParaEnsaio(query.docs.first);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Crachá não encontrado nesta OS ou já processado.')),
          );
        }
      }
    } finally {
      _scannerController.clear();
    }
  }

  void _irParaEnsaio(DocumentSnapshot doc) {
    final dados = doc.data() as Map<String, dynamic>;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TelaEnsaioTH(
          itemOsId: doc.id,
          osId: widget.osIdAtual,
          dadosItem: dados,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bancada: Teste Hidrostático'),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            color: Colors.blue.shade50,
            child: CampoComScanner(
              controller: _scannerController,
              label: 'Bipar Crachá para TH',
              onSubmitted: _processarBipe,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('itens_os')
                  .where('osId', isEqualTo: widget.osIdAtual)
                  .where('status', isEqualTo: 'aguardando_th')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final itens = snapshot.data!.docs;

                if (itens.isEmpty) return _buildTelaConclusao();

                return ListView.builder(
                  itemCount: itens.length,
                  itemBuilder: (context, index) {
                    final itemDoc = itens[index];
                    final dados =
                    itemDoc.data() as Map<String, dynamic>;
                    final idCracha =
                        dados['idCrachaTemporario'] ?? '???';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: Icon(Icons.science,
                            color: Colors.blue.shade900),
                        title: Text('Crachá: $idCracha'),
                        subtitle: Text(
                            'Agente: ${dados['tipoAgente']} | Cap: ${dados['capacidade'] ?? dados['carga'] ?? ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BotaoCondenar(
                                itemDoc: itemDoc, etapa: 'th'),
                            IconButton(
                              icon: const Icon(
                                  Icons.shopping_cart_checkout,
                                  color: Colors.blue),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        TelaCriarRequisicao(
                                          osPrePreenchida:
                                          widget.osIdAtual,
                                          ccPrePreenchido:
                                          MapeadorCustos.obterCC(
                                              'TESTE HIDROSTÁTICO'),
                                          subTipoPrePreenchido: 'OS',
                                        ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        onTap: () => _irParaEnsaio(itemDoc),
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

  Widget _buildTelaConclusao() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: Colors.green),
          const SizedBox(height: 20),
          const Text('Teste Hidro Concluído!',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('Todos os itens foram processados.'),
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