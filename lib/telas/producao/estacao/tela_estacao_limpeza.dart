// lib/telas/producao/estacao/tela_estacao_limpeza.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';
import 'package:protecin_producao/widgets/botao_condenar.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_triagem_limpeza.dart';
import 'package:protecin_producao/telas/estoque/tela_criar_requisicao.dart';
import 'package:protecin_producao/utils/mapeador_custos.dart';

class TelaEstacaoLimpeza extends StatefulWidget {
  final String osId;
  const TelaEstacaoLimpeza({Key? key, required this.osId}) : super(key: key);

  @override
  _TelaEstacaoLimpezaState createState() => _TelaEstacaoLimpezaState();
}

class _TelaEstacaoLimpezaState extends State<TelaEstacaoLimpeza> {
  final TextEditingController _scannerController = TextEditingController();

  String _limparCodigo(String valor) {
    String limpo = valor.trim().toUpperCase();
    if (limpo.contains('HTTP')) {
      limpo = limpo.split('/').last;
    }
    return limpo.replaceAll('R-', '');
  }

  Future<void> _processarBipe(String codigo) async {
    if (codigo.isEmpty) return;
    String idCracha = _limparCodigo(codigo);

    try {
      final query = await FirebaseFirestore.instance
          .collection('itens_os')
          .where('osId', isEqualTo: widget.osId)
          .where('idCrachaTemporario', isEqualTo: idCracha)
          .where('status', isEqualTo: 'aguardando_limpeza')
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final dados = doc.data() as Map<String, dynamic>;

        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (context) => TelaTriagemLimpeza(
          itemOsId: doc.id,
          idRastreio: idCracha,
          tipoAgente: dados['tipoAgente'] ?? '?',
          equipamentoId: dados['equipamentoId'] ?? '',
          osId: widget.osId, // Passamos o osId para a triagem gerenciar a trava de saída
        )));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Crachá não encontrado nesta OS ou já processado.'))
        );
      }
    } finally {
      _scannerController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estação: Limpeza & Triagem'),
        backgroundColor: const Color(0xFF1565C0),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            color: Colors.blue.shade50,
            child: CampoComScanner(
              controller: _scannerController,
              label: 'Bipar Crachá do Cilindro',
              onSubmitted: _processarBipe,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('itens_os')
                  .where('osId', isEqualTo: widget.osId)
                  .where('status', isEqualTo: 'aguardando_limpeza')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final itens = snapshot.data!.docs;

                if (itens.isEmpty) {
                  return _buildTelaConclusao();
                }

                return ListView.builder(
                  itemCount: itens.length,
                  itemBuilder: (context, index) {
                    final itemDoc = itens[index];
                    final dados = itemDoc.data() as Map<String, dynamic>;
                    final idCracha = dados['idCrachaTemporario'] ?? '???';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.cleaning_services, color: Color(0xFF1565C0)),
                        title: Text('Crachá: $idCracha'),
                        subtitle: Text('Agente: ${dados['tipoAgente']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BotaoCondenar(itemDoc: itemDoc, etapa: 'limpeza'),
                            IconButton(
                              icon: const Icon(Icons.shopping_cart_checkout, color: Colors.blue),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TelaCriarRequisicao(
                                      osPrePreenchida: widget.osId,
                                      ccPrePreenchido: MapeadorCustos.obterCC('DESCARGA E PREPARAÇÃO'),
                                      subTipoPrePreenchido: 'OS',
                                    ),
                                  ),
                                );
                              },
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TelaTriagemLimpeza(
                          itemOsId: itemDoc.id,
                          idRastreio: idCracha,
                          tipoAgente: dados['tipoAgente'],
                          equipamentoId: dados['equipamentoId'] ?? '',
                          osId: widget.osId,
                        ))),
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
          const Text('Limpeza Concluída!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('Lote enviado para a Lixa.'),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('VOLTAR PARA A FILA'),
          )
        ],
      ),
    );
  }
}