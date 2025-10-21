// CÓDIGO COMPLETO E FINAL - telas/tela_requisicoes_pendentes.dart (v. 20/10/2025 - Lógica Separada)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estocando/models/requisicao.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/movimentacao.dart';

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
    print("DEBUG: Iniciando TelaRequisicoesPendentes...");
    _carregarDadosUsuario();
  }

  Future<void> _carregarDadosUsuario() async {
    print("DEBUG: Carregando dados do usuário...");
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _usuarioLogado = user;
      try {
        DocumentSnapshot userData = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
        if (mounted && userData.exists) {
          final data = userData.data() as Map<String, dynamic>;
          print("DEBUG: Dados do usuário encontrados: ${data['nome']}, Empresa: ${data['empresaId']}");
          setState(() {
            _empresaId = data['empresaId'];
            _dadosUsuarioLogado = data;
            _dadosUsuarioLogado?['uid'] = user.uid;
            _carregando = false;
          });
        } else {
          print("AVISO: Documento do usuário não encontrado no Firestore para UID: ${user.uid}");
          if(mounted) setState(() => _carregando = false);
        }
      } catch (e) {
        print("Erro ao carregar dados do usuário: $e");
        if(mounted) setState(() => _carregando = false);
      }
    } else {
      print("AVISO: Nenhum usuário logado ao carregar dados.");
      if(mounted) setState(() => _carregando = false);
    }
  }

  // --- FUNÇÃO DE ATENDER (LÓGICA SEPARADA - VERSÃO FINAL) ---
  Future<void> _atenderRequisicao(Requisicao requisicao) async {
    if (_dadosUsuarioLogado == null || _empresaId == null || _usuarioLogado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro: Não foi possível identificar o usuário almoxarife.'), backgroundColor: Colors.red));
      return;
    }

    // Usaremos um Map para guardar os dados lidos dos produtos na primeira transação
    Map<String, Map<String, dynamic>> dadosProdutos = {};
    String? erroEstoque;

    // Mostra Dialog inicial
    showDialog( context: context, barrierDismissible: false, builder: (ctx) => const AlertDialog( title: Text('Processando...'), content: Row( children: [ CircularProgressIndicator(), SizedBox(width: 20), Text('Verificando estoque...'), ], ), ), );

    final db = FirebaseFirestore.instance;
    final requisicaoRef = db.collection('requisicoes').doc(requisicao.id);

    try {
      // --- TRANSAÇÃO 1: APENAS VERIFICAR ESTOQUE E GUARDAR DADOS ---
      print("DEBUG: Iniciando Transação 1 (Verificação)...");
      await db.runTransaction((transaction) async {
        for (final item in requisicao.itens) {
          final produtoRef = db.collection('produtos').doc(item.produtoId);
          final produtoSnapshot = await transaction.get(produtoRef);
          if (!produtoSnapshot.exists) { throw Exception('O produto ${item.produtoNome} (ID: ${item.produtoId}) não existe mais.'); }

          final dadosProduto = produtoSnapshot.data() as Map<String, dynamic>;
          dadosProdutos[item.produtoId] = dadosProduto; // Guarda os dados lidos

          final estoqueAtual = (dadosProduto['quantidadeAtual'] ?? 0).toDouble();
          if (estoqueAtual < item.quantidadeSolicitada) {
            erroEstoque = 'Estoque insuficiente para: ${item.produtoNome}. (Disponível: ${estoqueAtual.toString().replaceAll('.', ',')})';
            throw Exception(erroEstoque);
          }
        }
      });
      print("DEBUG: Transação 1 (Verificação) OK.");
      // Se chegou aqui, estoque estava OK e dadosProdutos está preenchido

      // Atualiza o Dialog
      if(mounted) Navigator.of(context, rootNavigator: true).pop(); // Fecha o dialog antigo
      showDialog( context: context, barrierDismissible: false, builder: (ctx) => const AlertDialog( title: Text('Processando...'), content: Row( children: [ CircularProgressIndicator(), SizedBox(width: 20), Text('Atualizando requisição...'), ], ), ), );

      // --- TRANSAÇÃO 2: APENAS ATUALIZAR STATUS DA REQUISIÇÃO ---
      print("DEBUG: Iniciando Transação 2 (Update Requisição)...");
      await db.runTransaction((transaction) async {
        transaction.update(requisicaoRef, {
          'status': 'ATENDIDO',
          'atendidoPorId': _usuarioLogado!.uid,
          'atendidoPorNome': _dadosUsuarioLogado!['nome'] ?? 'Nome não encontrado',
          'dataAtendimento': Timestamp.now(),
        });
      });
      print("DEBUG: Transação 2 (Update Requisição) OK.");
      // Se chegou aqui, o status da requisição foi atualizado

      // Atualiza o Dialog
      if(mounted) Navigator.of(context, rootNavigator: true).pop(); // Fecha o dialog antigo
      showDialog( context: context, barrierDismissible: false, builder: (ctx) => const AlertDialog( title: Text('Processando...'), content: Row( children: [ CircularProgressIndicator(), SizedBox(width: 20), Text('Atualizando estoque e gerando movimentações...'), ], ), ), );

      // --- WRITE BATCH (FORA DAS TRANSAÇÕES) ---
      print("DEBUG: Iniciando WriteBatch (Update Produtos e Criação Movs)...");
      final batch = db.batch();
      for (final item in requisicao.itens) {
        final produtoRef = db.collection('produtos').doc(item.produtoId);
        final dadosProdutoAtual = dadosProdutos[item.produtoId]; // Pega os dados guardados

        if (dadosProdutoAtual == null) { // Segurança extra
          throw Exception("Erro interno: Dados do produto ${item.produtoNome} não encontrados após verificação.");
        }

        final estoqueAtual = (dadosProdutoAtual['quantidadeAtual'] ?? 0).toDouble();
        final novoEstoque = estoqueAtual - item.quantidadeSolicitada;
        if (novoEstoque < 0) { // Segurança extra
          throw Exception('Erro Inesperado: Estoque ficou negativo para ${item.produtoNome} durante o Batch.');
        }

        // Adiciona Update do Produto ao Batch
        batch.update(produtoRef, {'quantidadeAtual': novoEstoque});
        print("DEBUG: Batch: Update estoque ${item.produtoNome} para $novoEstoque");

        // Adiciona Criação da Movimentação ao Batch
        final novaMovimentacao = Movimentacao(
          empresaId: _empresaId!,
          produtoId: item.produtoId,
          produtoCodigo: item.produtoCodigo,
          produtoNome: item.produtoNome,
          tipo: TipoMovimentacao.saida,
          quantidade: item.quantidadeSolicitada,
          data: DateTime.now(), // Data do atendimento
          subTipo: requisicao.subTipo,
          numeroOS: requisicao.numeroOS,
          nomeColaborador: requisicao.nomeColaborador,
          centroDeCusto: requisicao.centroDeCusto,
          numeroPedido: requisicao.numeroPedido,
          numeroNF: requisicao.numeroNF,
          numeroAG: requisicao.agencia,
          nomeCliente: null,
          nomeFornecedor: null,
          valorUnitarioMovimentacao: (dadosProdutoAtual['valor'] ?? 0.0).toDouble(), // Usa dados guardados
        );
        final movimentacaoRef = db.collection('movimentacoes').doc();
        batch.set(movimentacaoRef, novaMovimentacao.toJson());
        print("DEBUG: Batch: Set movimentação para ${item.produtoNome}");
      }

      // Executa o Batch
      await batch.commit();
      print("DEBUG: WriteBatch concluído com sucesso.");
      // --- FIM DO WRITE BATCH ---


      if(mounted) Navigator.of(context, rootNavigator: true).pop(); // Fecha o último dialog

      // Mensagem de sucesso final
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Requisição atendida com sucesso! Estoque atualizado.'), backgroundColor: Colors.green));
      }

    } catch (e, s) {
      if(mounted) Navigator.of(context, rootNavigator: true).pop(); // Fecha qualquer dialog que estiver aberto
      String mensagemErro = erroEstoque ?? e.toString().replaceAll("Exception: ", "");
      print('--- ERRO DETALHADO (Atender Requisição WEB - Final) ---'); print(mensagemErro); print('Erro original: $e'); print('--- STACK TRACE ---'); print(s);
      if(mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar( content: Text('Erro: $mensagemErro'), backgroundColor: Colors.red, duration: const Duration(seconds: 10) )); }
    }
  } // ---> FIM DA FUNÇÃO _atenderRequisicao <---

  Future<void> _reprovarRequisicao(Requisicao req, String motivo) async {
    // ... (Função _reprovarRequisicao completa e final) ...
    if (_dadosUsuarioLogado == null || _empresaId == null || _usuarioLogado == null) { /* ... erro ... */ return; }
    showDialog( context: context, barrierDismissible: false, builder: (ctx) => const AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 20), Text('Cancelando...')])), );
    final db = FirebaseFirestore.instance;
    final requisicaoRef = db.collection('requisicoes').doc(req.id);
    try {
      await requisicaoRef.update({ 'status': 'CANCELADO', 'motivoCancelamento': motivo.trim().isNotEmpty ? motivo.trim() : "Motivo não informado", 'atendidoPorId': _usuarioLogado!.uid, 'atendidoPorNome': _dadosUsuarioLogado!['nome'] ?? 'Nome não encontrado', 'dataAtendimento': Timestamp.now(), });
      if(mounted) Navigator.of(context, rootNavigator: true).pop(); // Fecha dialog
      if(mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Requisição cancelada.'), backgroundColor: Colors.orange)); }
    } catch (e) {
      if(mounted) Navigator.of(context, rootNavigator: true).pop(); // Fecha dialog
      print("Erro ao cancelar requisição: $e");
      if(mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao cancelar: $e'), backgroundColor: Colors.red)); }
    }
  }

  void _mostrarDialogoReprovar(Requisicao req) {
    // ... (Função _mostrarDialogoReprovar completa e final) ...
    final motivoController = TextEditingController();
    showDialog( context: context, builder: (ctx) => AlertDialog( title: const Text('Reprovar Requisição'), content: TextField( controller: motivoController, decoration: const InputDecoration( labelText: 'Motivo (opcional)', hintText: 'Ex: Material em falta, Pedido incorreto...', border: OutlineInputBorder(), ), maxLines: 3, ), actions: [ TextButton( child: const Text('Voltar'), onPressed: () => Navigator.of(ctx).pop(), ), ElevatedButton( style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Confirmar Reprovação'), onPressed: () { final motivo = motivoController.text; Navigator.of(ctx).pop(); _reprovarRequisicao(req, motivo); }, ) ], ), );
  }

  @override
  Widget build(BuildContext context) {
    print("DEBUG: Buildando TelaRequisicoesPendentes. Carregando: $_carregando, EmpresaID: $_empresaId");
    return Scaffold(
      appBar: AppBar(
        title: const Text('Requisições Pendentes'),
        actions: [ IconButton( icon: const Icon(Icons.refresh), tooltip: 'Recarregar Dados', onPressed: () { if (!_carregando) { setState(() => _carregando = true); _carregarDadosUsuario(); } }, ) ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _empresaId == null
          ? Center(child: Padding( padding: const EdgeInsets.all(16.0), child: Text( _usuarioLogado == null ? "Erro: Usuário não está logado." : "Erro: ID da empresa não encontrado para este usuário. Verifique o cadastro no Firestore.", textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700), ), ))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance .collection('requisicoes') .where('empresaId', isEqualTo: _empresaId) .where('status', isEqualTo: 'PENDENTE') .orderBy('dataSolicitacao', descending: false) .snapshots(),
        builder: (context, snapshot) {
          print("DEBUG: StreamBuilder state: ${snapshot.connectionState}");
          if (snapshot.hasError) {
            print("!!!! ERRO no StreamBuilder: ${snapshot.error}");
            String erroMsg = 'Ocorreu um erro ao carregar as requisições.';
            if (snapshot.error.toString().contains('requires an index')) { erroMsg = 'Erro: O Firestore precisa de um índice para esta consulta...'; }
            else if (snapshot.error.toString().contains('permission-denied')) { erroMsg = 'Erro: Permissão negada...'; }
            return Center(child: Padding( padding: const EdgeInsets.all(16.0), child: Text(erroMsg, style: TextStyle(color: Colors.red.shade700)), ));
          }
          if (snapshot.connectionState == ConnectionState.waiting) { print("DEBUG: StreamBuilder esperando dados..."); return const Center(child: CircularProgressIndicator()); }
          if (!snapshot.hasData || snapshot.data == null || snapshot.data!.docs.isEmpty) { print("DEBUG: StreamBuilder sem dados ou lista vazia."); return const Center( child: Text( 'Nenhuma requisição pendente.', style: TextStyle(fontSize: 18, color: Colors.grey), ), ); }
          print("DEBUG: StreamBuilder recebeu ${snapshot.data!.docs.length} documentos.");
          List<Requisicao> requisicoes = [];
          List<String> errosDeConversao = [];
          for (var doc in snapshot.data!.docs) {
            try {
              print("DEBUG: Mapeando doc ID: ${doc.id}");
              final req = Requisicao.fromFirestore(doc);
              if (req.status != 'INVALIDO' && req.empresaId != 'EMPRESA_INVALIDA') { requisicoes.add(req); print("DEBUG: Doc ${doc.id} mapeado com sucesso."); }
              else { print("AVISO: Doc ${doc.id} filtrado por ter status/empresa inválido."); }
            } catch (e, s) {
              print("!!!! ERRO ao mapear Requisicao.fromFirestore para doc ID: ${doc.id}"); print("     Erro: $e"); print("     StackTrace: $s");
              errosDeConversao.add("Erro ao processar requisição ${doc.id}: $e");
            }
          }
          if (errosDeConversao.isNotEmpty) { return Center(child: Padding( padding: const EdgeInsets.all(16.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ Text('Erro ao processar algumas requisições:', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)), const SizedBox(height: 10), Text(errosDeConversao.join('\n'), style: TextStyle(color: Colors.red.shade700)), const SizedBox(height: 20), ElevatedButton(onPressed: (){ setState(() {}); }, child: Text('Tentar Recarregar')) ], ), )); }
          if (requisicoes.isEmpty) { print("DEBUG: Lista final de requisições vazia após mapeamento/filtro."); return const Center( child: Text( 'Nenhuma requisição pendente válida encontrada.', style: TextStyle(fontSize: 18, color: Colors.grey), ), ); }
          print("DEBUG: Construindo ListView com ${requisicoes.length} requisições.");
          return ListView.builder( itemCount: requisicoes.length, itemBuilder: (context, index) { final req = requisicoes[index]; return _buildCardRequisicao(req); }, );
        },
      ),
    );
  }

  Widget _buildCardRequisicao(Requisicao req) {
    final formatadorData = DateFormat('dd/MM/yy HH:mm');
    final String tituloContexto = _getTituloContexto(req);
    return Card( margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), elevation: 3, child: InkWell( onTap: () { _mostrarDialogoDetalhes(req); }, child: Padding( padding: const EdgeInsets.all(12.0), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text( tituloContexto, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), ), const SizedBox(height: 8), Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Flexible( child: Text( 'Por: ${req.solicitanteNome}', style: const TextStyle(fontSize: 14, color: Colors.black54), overflow: TextOverflow.ellipsis, ), ), Text( formatadorData.format(req.dataSolicitacao), style: const TextStyle(fontSize: 14, color: Colors.black54, fontStyle: FontStyle.italic), ), ], ), const SizedBox(height: 10), Text( '${req.itens.length} ${req.itens.length == 1 ? "item" : "itens"} solicitados', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent), ), ], ), ), ), );
  }

  String _getTituloContexto(Requisicao req) {
    switch (req.subTipo) { case 'OS': return 'OS: ${req.numeroOS ?? "N/A"}'; case 'Colaborador': return 'Colaborador: ${req.nomeColaborador ?? "N/A"}'; case 'Venda (Pedido)': return 'Pedido: ${req.numeroPedido ?? "N/A"}'; case 'Venda (NF)': return 'NF: ${req.numeroNF ?? "N/A"}'; case 'Itau': return 'AG: ${req.agencia ?? "N/A"}'; default: return req.subTipo; }
  }

  void _mostrarDialogoDetalhes(Requisicao req) {
    showDialog( context: context, builder: (ctx) { return AlertDialog( title: Text(_getTituloContexto(req)), contentPadding: const EdgeInsets.fromLTRB(0, 20, 0, 0), content: Container( width: double.maxFinite, constraints: BoxConstraints( maxHeight: MediaQuery.of(context).size.height * 0.4, ), child: ListView.builder( shrinkWrap: true, itemCount: req.itens.length, itemBuilder: (context, index) { final item = req.itens[index]; return Padding( padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0), child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(item.produtoNome, style: const TextStyle(fontSize: 15)), Text('Cód: ${item.produtoCodigo}', style: const TextStyle(fontSize: 12, color: Colors.grey)), ], ), ), Text( 'Qtd: ${item.quantidadeSolicitada.toString().replaceAll('.', ',')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), ), ], ), ); }, ), ), actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), actionsAlignment: MainAxisAlignment.spaceBetween, actions: <Widget>[ TextButton( style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Reprovar'), onPressed: () { Navigator.of(ctx).pop(); _mostrarDialogoReprovar(req); }, ), Row( mainAxisSize: MainAxisSize.min, children: [ TextButton( child: const Text('Voltar', style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.of(ctx).pop(), ), const SizedBox(width: 8), ElevatedButton( style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent), child: const Text('Atender Requisição'), onPressed: () { Navigator.of(ctx).pop(); _atenderRequisicao(req); }, ), ], ) ], ); }, );
  }
} // FIM DA CLASSEgit push origin main