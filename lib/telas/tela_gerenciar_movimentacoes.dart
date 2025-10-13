// CÓDIGO COMPLETO E CORRIGIDO - BOTÃO EDITAR AGORA NAVEGA PARA A TELA DE MOVIMENTAÇÃO

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/movimentacao_service.dart';
// ---> MUDANÇA (EDIÇÃO): Importamos a tela de movimentação para poder abri-la.
import 'package:estocando/telas/tela_movimentacao.dart';


class TelaGerenciarMovimentacoes extends StatefulWidget {
  const TelaGerenciarMovimentacoes({super.key});

  @override
  State<TelaGerenciarMovimentacoes> createState() => _TelaGerenciarMovimentacoesState();
}

class _TelaGerenciarMovimentacoesState extends State<TelaGerenciarMovimentacoes> {
  final MovimentacaoService _movimentacaoService = MovimentacaoService();
  String? _empresaId;
  Map<String, dynamic>? _usuarioLogado;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if(mounted) setState(() => _carregando = false);
      return;
    }
    final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(currentUser.uid).get();
    if(mounted) {
      setState(() {
        _usuarioLogado = userDoc.data();
        _empresaId = _usuarioLogado?['empresaId'];
        _carregando = false;
      });
    }
  }

  void _mostrarDialogoConfirmacao(BuildContext context, Map<String, dynamic> movimentacao, String docId) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: const Text('Você tem certeza? Esta ação irá estornar o valor no estoque e não pode ser desfeita.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Excluir'),
              onPressed: () {
                _excluirMovimentacao(movimentacao, docId);
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _excluirMovimentacao(Map<String, dynamic> movimentacao, String docId) async {
    try {
      await _movimentacaoService.excluirMovimentacaoComEstorno(movimentacao, docId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Movimentação excluída com sucesso!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Movimentações'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _empresaId == null
          ? const Center(child: Text("ID da empresa não encontrado. Faça login novamente."))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('movimentacoes')
            .where('empresaId', isEqualTo: _empresaId)
            .orderBy('data', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Ocorreu um erro: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
            ));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nenhuma movimentação encontrada.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final bool isEntrada = data['tipo'] == 'entrada';

              DateTime dataMov;
              final dataValue = data['data'];

              if (dataValue is Timestamp) {
                dataMov = dataValue.toDate();
              } else if (dataValue is String) {
                dataMov = DateTime.tryParse(dataValue) ?? DateTime.now();
              } else {
                dataMov = DateTime.now();
              }

              final formatadorData = DateFormat('dd/MM/yyyy HH:mm');

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: Icon(
                    isEntrada ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isEntrada ? Colors.green : Colors.red,
                  ),
                  title: Text(data['produtoNome'] ?? 'Produto não informado'),
                  subtitle: Text(
                      'Qtd: ${data['quantidade']} | ${formatadorData.format(dataMov)}'),

                  trailing: (_usuarioLogado?['permissao'] == 'admin' || _usuarioLogado?['nivel'] == 'admin')
                      ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ---> MUDANÇA (EDIÇÃO): Lógica do botão de editar.
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          // Navega para a TelaMovimentacao, passando o documento
                          // da movimentação que foi clicada.
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => TelaMovimentacao(
                              movimentacaoParaEditar: doc,
                            ),
                          ));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          _mostrarDialogoConfirmacao(context, data, doc.id);
                        },
                      ),
                    ],
                  )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}