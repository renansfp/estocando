import 'package:flutter/material.dart';
import 'package:protecin_producao/widgets/botao_condenar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';

class TelaEstacaoLixa extends StatefulWidget {
  final String osId;
  const TelaEstacaoLixa({Key? key, required this.osId}) : super(key: key);

  @override
  _TelaEstacaoLixaState createState() => _TelaEstacaoLixaState();
}

class _TelaEstacaoLixaState extends State<TelaEstacaoLixa> {
  final Color _corSetor = Colors.blueGrey.shade700;
  final TextEditingController _scannerController = TextEditingController();
  bool _processando = false;

  String _limparCodigo(String valor) {
    String limpo = valor.trim().toUpperCase();
    if (limpo.contains('HTTP')) limpo = limpo.split('/').last;
    return limpo.replaceAll('R-', '');
  }

  Future<void> _confirmarLixamento(DocumentSnapshot itemDoc) async {
    if (_processando) return;
    setState(() => _processando = true);

    try {
      final dados = itemDoc.data() as Map<String, dynamic>;
      final codigo = dados['idCrachaTemporario'] ?? '???';
      final List<String> roteiro = List<String>.from(dados['roteiro'] ?? []);

      // LÓGICA DO ROTEIRO: Descobre o próximo passo baseado no DNA do item
      int indexLixa = roteiro.indexOf('lixa');
      if (indexLixa == -1 || indexLixa >= roteiro.length - 1) {
        throw 'Erro: Próxima etapa não encontrada no roteiro.';
      }

      String proximaEstacao = roteiro[indexLixa + 1];
      String proximoStatus = 'aguardando_$proximaEstacao';

      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // 1. Atualiza o item individual
      batch.update(itemDoc.reference, {
        'status': proximoStatus,
        'lixa': {
          'data': FieldValue.serverTimestamp(),
          'operador': 'operador_lixa',
        }
      });

      // 2. Trava de Segurança: Verifica se restam itens pendentes NA LIXA
      final queryPendentes = await firestore
          .collection('itens_os')
          .where('osId', isEqualTo: widget.osId)
          .where('status', isEqualTo: 'aguardando_lixa')
          .get();

      // 3. Se for o último, move a OS para a próxima etapa do roteiro
      if (queryPendentes.docs.length <= 1) {
        final osRef = firestore.collection('ordens_servico').doc(widget.osId);
        batch.update(osRef, {
          'etapaAtual': proximaEstacao,
          'dataFimLixa': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cilindro $codigo finalizado -> Seguindo para $proximaEstacao'),
            backgroundColor: Colors.green,
            duration: const Duration(milliseconds: 1000),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  void _processarBipe(String codigo) async {
    if (codigo.isEmpty) return;
    String idCracha = _limparCodigo(codigo);

    final query = await FirebaseFirestore.instance
        .collection('itens_os')
        .where('osId', isEqualTo: widget.osId)
        .where('idCrachaTemporario', isEqualTo: idCracha)
        .where('status', isEqualTo: 'aguardando_lixa')
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      _confirmarLixamento(query.docs.first);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Crachá inválido para lixa.')));
    }
    _scannerController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Execução: Lixa/Jato'), backgroundColor: _corSetor, foregroundColor: Colors.white),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            color: Colors.blueGrey.shade50,
            child: CampoComScanner(controller: _scannerController, label: 'Bipar Crachá para Lixar', onSubmitted: _processarBipe),
          ),
          if (_processando) const LinearProgressIndicator(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('itens_os')
                  .where('osId', isEqualTo: widget.osId)
                  .where('status', isEqualTo: 'aguardando_lixa')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
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
                        leading: Icon(Icons.build, color: _corSetor),
                        title: Text('Crachá: ${d['idCrachaTemporario']}'),
                        subtitle: Text('Agente: ${d['tipoAgente']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BotaoCondenar(itemDoc: item, etapa: 'lixa'),
                            IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () => _confirmarLixamento(item)),
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
          const Text('Etapa Lixa Concluída!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('VOLTAR PARA A FILA')),
        ],
      ),
    );
  }
}