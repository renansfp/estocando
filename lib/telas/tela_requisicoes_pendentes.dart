// CÓDIGO COMPLETO - telas/tela_requisicoes_pendentes.dart (com função REPROVAR)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estocando/models/requisicao.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/movimentacao.dart'; // Precisamos disso para criar a movimentação

class TelaRequisicoesPendentes extends StatefulWidget {
  const TelaRequisicoesPendentes({super.key});

  @override
  State<TelaRequisicoesPendentes> createState() => _TelaRequisicoesPendentesState();
}

class _TelaRequisicoesPendentesState extends State<TelaRequisicoesPendentes> {
  String? _empresaId;
  Map<String, dynamic>? _dadosUsuarioLogado;
  User? _usuarioLogado;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
  }

  Future<void> _carregarDadosUsuario() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _usuarioLogado = user;
      DocumentSnapshot userData = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (mounted && userData.exists) {
        final data = userData.data() as Map<String, dynamic>;
        setState(() {
          _empresaId = data['empresaId'];
          _dadosUsuarioLogado = data;
          // Adiciona o UID aos dados do usuário para fácil acesso
          _dadosUsuarioLogado?['uid'] = user.uid;
          _carregando = false;
        });
      } else {
        if(mounted) setState(() => _carregando = false);
      }
    } else {
      if(mounted) setState(() => _carregando = false);
    }
  }

  // --- FUNÇÃO DE ATENDER ---
  Future<void> _atenderRequisicao(Requisicao requisicao) async {
    if (_dadosUsuarioLogado == null || _empresaId == null || _usuarioLogado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro: Não foi possível identificar o usuário almoxarife.'), backgroundColor: Colors.red));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        title: Text('Processando...'),
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Verificando estoque...'),
          ],
        ),
      ),
    );

    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    final requisicaoRef = db.collection('requisicoes').doc(requisicao.id);
    String? erroEstoque;

    try {
      // 1. VERIFICAÇÃO DE ESTOQUE
      await db.runTransaction((transaction) async {
        for (final item in requisicao.itens) {
          final produtoRef = db.collection('produtos').doc(item.produtoId);
          final produtoSnapshot = await transaction.get(produtoRef);
          if (!produtoSnapshot.exists) {
            throw Exception('O produto ${item.produtoNome} (ID: ${item.produtoId}) não existe mais.');
          }
          final dadosProduto = produtoSnapshot.data() as Map<String, dynamic>;
          final estoqueAtual = (dadosProduto['quantidadeAtual'] ?? 0).toDouble();
          if (estoqueAtual < item.quantidadeSolicitada) {
            erroEstoque = 'Estoque insuficiente para: ${item.produtoNome}. (Disponível: ${estoqueAtual.toString().replaceAll('.', ',')})';
            throw Exception(erroEstoque);
          }
        }
      });
      // A transação só continua se o estoque estava OK

      // 2. ATUALIZAÇÃO E CRIAÇÃO DE MOVIMENTAÇÕES
      await db.runTransaction((transaction) async {
        transaction.update(requisicaoRef, {
          'status': 'ATENDIDO',
          'atendidoPorId': _usuarioLogado!.uid,
          'atendidoPorNome': _dadosUsuarioLogado!['nome'] ?? 'Nome não encontrado',
          'dataAtendimento': Timestamp.now(),
        });

        for (final item in requisicao.itens) {
          final produtoRef = db.collection('produtos').doc(item.produtoId);
          final produtoSnapshot = await transaction.get(produtoRef);
          if (!produtoSnapshot.exists) { // Segurança extra
            throw Exception('Erro Inesperado: Produto ${item.produtoNome} sumiu durante a transação de atualização.');
          }
          final dadosProduto = produtoSnapshot.data() as Map<String, dynamic>;
          final estoqueAtual = (dadosProduto['quantidadeAtual'] ?? 0).toDouble();
          final novoEstoque = estoqueAtual - item.quantidadeSolicitada;

          if (novoEstoque < 0) { // Segurança extra
            throw Exception('Erro Inesperado: Estoque ficou negativo para ${item.produtoNome} durante a atualização.');
          }

          transaction.update(produtoRef, {'quantidadeAtual': novoEstoque});

          final novaMovimentacao = Movimentacao(
            empresaId: _empresaId!,
            produtoId: item.produtoId,
            produtoCodigo: item.produtoCodigo,
            produtoNome: item.produtoNome,
            tipo: TipoMovimentacao.saida,
            quantidade: item.quantidadeSolicitada,
            data: DateTime.now(),
            subTipo: requisicao.subTipo,
            numeroOS: requisicao.numeroOS,
            nomeColaborador: requisicao.nomeColaborador,
            centroDeCusto: requisicao.centroDeCusto,
            numeroPedido: requisicao.numeroPedido,
            numeroNF: requisicao.numeroNF,
            numeroAG: requisicao.agencia,
            nomeCliente: null,
            nomeFornecedor: null,
            valorUnitarioMovimentacao: (dadosProduto['valor'] ?? 0.0).toDouble(),
          );
          final movimentacaoRef = db.collection('movimentacoes').doc();
          batch.set(movimentacaoRef, novaMovimentacao.toJson());
        }
      });

      // 3. EXECUTA O BATCH
      await batch.commit();

      if(mounted) Navigator.of(context, rootNavigator: true).pop(); // Fecha dialog
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Requisição atendida com sucesso! Estoque atualizado.'), backgroundColor: Colors.green));
      }

    } catch (e, s) {
      if(mounted) Navigator.of(context, rootNavigator: true).pop(); // Fecha dialog
      String mensagemErro = erroEstoque ?? e.toString().replaceAll("Exception: ", "");
      print('--- ERRO DETALHADO (Atender Requisição WEB - Final) ---');
      print(mensagemErro);
      print('Erro original: $e');
      print('--- STACK TRACE ---');
      print(s);
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro: $mensagemErro'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10)
        ));
      }
    }
  }

  // --- NOVA FUNÇÃO PARA REPROVAR ---
  Future<void> _reprovarRequisicao(Requisicao req, String motivo) async {
    if (_dadosUsuarioLogado == null || _empresaId == null || _usuarioLogado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro: Não foi possível identificar o usuário.'), backgroundColor: Colors.red));
      return;
    }
    // Mostra indicador simples
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 20), Text('Cancelando...')])),
    );

    final db = FirebaseFirestore.instance;
    final requisicaoRef = db.collection('requisicoes').doc(req.id);

    try {
      await requisicaoRef.update({
        'status': 'CANCELADO', // Muda o status
        'motivoCancelamento': motivo.trim().isNotEmpty ? motivo.trim() : "Motivo não informado", // Salva o motivo
        'atendidoPorId': _usuarioLogado!.uid, // Quem cancelou
        'atendidoPorNome': _dadosUsuarioLogado!['nome'] ?? 'Nome não encontrado', // Quem cancelou
        'dataAtendimento': Timestamp.now(), // Quando cancelou (reutilizamos o campo dataAtendimento)
      });

      if(mounted) Navigator.of(context, rootNavigator: true).pop(); // Fecha dialog processando
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Requisição cancelada.'), backgroundColor: Colors.orange));
      }

    } catch (e) {
      if(mounted) Navigator.of(context, rootNavigator: true).pop(); // Fecha dialog processando
      print("Erro ao cancelar requisição: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao cancelar: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // --- NOVO DIÁLOGO PARA PEDIR O MOTIVO DA REPROVAÇÃO ---
  void _mostrarDialogoReprovar(Requisicao req) {
    final motivoController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reprovar Requisição'),
        content: TextField(
          controller: motivoController,
          decoration: const InputDecoration(
            labelText: 'Motivo (opcional)',
            hintText: 'Ex: Material em falta, Pedido incorreto...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            child: const Text('Voltar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirmar Reprovação'),
            onPressed: () {
              final motivo = motivoController.text;
              Navigator.of(ctx).pop(); // Fecha este dialog
              _reprovarRequisicao(req, motivo); // Chama a função que salva
            },
          )
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Requisições Pendentes'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _empresaId == null
          ? const Center(child: Text("Erro: ID da empresa não encontrado."))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('requisicoes')
            .where('empresaId', isEqualTo: _empresaId)
            .where('status', isEqualTo: 'PENDENTE')
            .orderBy('dataSolicitacao', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            if (snapshot.error.toString().contains('requires an index')) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Erro: O Firestore precisa de um índice para esta consulta. Verifique o console do Firebase (Firestore -> Índices) e crie o índice composto sugerido para a coleção "requisicoes". Detalhes: ${snapshot.error}', style: TextStyle(color: Colors.red)),
              ));
            }
            return Center(child: Text('Erro ao carregar requisições: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma requisição pendente.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }
          final requisicoes = snapshot.data!.docs
              .map((doc) => Requisicao.fromFirestore(doc))
              .toList();
          return ListView.builder(
            itemCount: requisicoes.length,
            itemBuilder: (context, index) {
              final req = requisicoes[index];
              return _buildCardRequisicao(req);
            },
          );
        },
      ),
    );
  }

  Widget _buildCardRequisicao(Requisicao req) {
    final formatadorData = DateFormat('dd/MM/yy HH:mm');
    final String tituloContexto = _getTituloContexto(req);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 3,
      child: InkWell(
        onTap: () {
          _mostrarDialogoDetalhes(req);
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tituloContexto,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Por: ${req.solicitanteNome}',
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    formatadorData.format(req.dataSolicitacao),
                    style: const TextStyle(fontSize: 14, color: Colors.black54, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${req.itens.length} ${req.itens.length == 1 ? "item" : "itens"} solicitados',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTituloContexto(Requisicao req) {
    switch (req.subTipo) {
      case 'OS': return 'OS: ${req.numeroOS ?? "N/A"}';
      case 'Colaborador': return 'Colaborador: ${req.nomeColaborador ?? "N/A"}';
      case 'Venda (Pedido)': return 'Pedido: ${req.numeroPedido ?? "N/A"}';
      case 'Venda (NF)': return 'NF: ${req.numeroNF ?? "N/A"}';
      case 'Itau': return 'AG: ${req.agencia ?? "N/A"}';
      default: return req.subTipo;
    }
  }

  // --- DIÁLOGO DE DETALHES E ATENDIMENTO (COM BOTÃO REPROVAR) ---
  void _mostrarDialogoDetalhes(Requisicao req) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(_getTituloContexto(req)),
          content: SizedBox(
            width: double.maxFinite, // Garante que o dialog use a largura disponível
            child: ListView.builder(
              shrinkWrap: true, // Para o ListView não tentar ocupar espaço infinito
              itemCount: req.itens.length,
              itemBuilder: (context, index) {
                final item = req.itens[index];
                return ListTile(
                  title: Text(item.produtoNome),
                  subtitle: Text('Cód: ${item.produtoCodigo}'),
                  trailing: Text(
                    'Qtd: ${item.quantidadeSolicitada.toString().replaceAll('.', ',')}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                );
              },
            ),
          ),
          actions: <Widget>[
            // Botão Reprovar
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Reprovar'),
              onPressed: () {
                Navigator.of(ctx).pop(); // Fecha o dialog de detalhes
                _mostrarDialogoReprovar(req); // Abre o dialog para pedir o motivo
              },
            ),
            const Spacer(), // Empurra os próximos botões para a direita
            // Botão Voltar (antigo Cancelar)
            TextButton(
              child: const Text('Voltar', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            // Botão Atender
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              child: const Text('Atender Requisição'),
              onPressed: () {
                Navigator.of(ctx).pop(); // Fecha o dialog de detalhes
                _atenderRequisicao(req); // Chama a função principal de atender
              },
            ),
          ],
        );
      },
    );
  }
} // FIM DA CLASSE