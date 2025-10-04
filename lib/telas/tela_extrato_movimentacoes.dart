// CÓDIGO FINAL E SEGURO - TELA DE EXTRATO DE MOVIMENTAÇÕES

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ---> MUDANÇA 1: Importamos para pegar o usuário.
import 'package:intl/intl.dart';

class TelaExtratoMovimentacoes extends StatefulWidget {
  const TelaExtratoMovimentacoes({super.key});

  @override
  State<TelaExtratoMovimentacoes> createState() => _TelaExtratoMovimentacoesState();
}

class _TelaExtratoMovimentacoesState extends State<TelaExtratoMovimentacoes> {
  DateTime? _dataInicio;
  DateTime? _dataFim;
  String _tipoFiltro = 'todos';

  // ---> MUDANÇA 2: Novas variáveis para guardar o empresaId e controlar o loading.
  String? _empresaId;
  bool _carregandoDadosIniciais = true;

  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario(); // ---> MUDANÇA 3: Chamamos a função para buscar o empresaId.
  }

  // ---> MUDANÇA 4: Nova função para buscar o empresaId do usuário logado.
  Future<void> _carregarDadosUsuario() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (mounted && userDoc.exists) {
        setState(() {
          _empresaId = (userDoc.data() as Map<String, dynamic>)['empresaId'];
          _carregandoDadosIniciais = false;
        });
      }
    } else {
      setState(() {
        _carregandoDadosIniciais = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Query? query;

    // A query só é construída se as datas E o empresaId existirem
    if (_dataInicio != null && _dataFim != null && _empresaId != null) {
      // ---> MUDANÇA 5 (A MAIS IMPORTANTE): A consulta agora é segura!
      query = FirebaseFirestore.instance
          .collection('movimentacoes')
          .where('empresaId', isEqualTo: _empresaId); // <-- FILTRO DE SEGURANÇA

      query = query.orderBy('data', descending: true);

      query = query.where('data', isGreaterThanOrEqualTo: _dataInicio!.toIso8601String());
      final dataFimCompleta = DateTime(_dataFim!.year, _dataFim!.month, _dataFim!.day, 23, 59, 59);
      query = query.where('data', isLessThanOrEqualTo: dataFimCompleta.toIso8601String());

      if (_tipoFiltro == 'entrada') {
        query = query.where('tipo', isEqualTo: 'entrada');
      } else if (_tipoFiltro == 'saida') {
        query = query.where('tipo', isEqualTo: 'saida');
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Extrato de Movimentações'),
        backgroundColor: Colors.teal,
      ),
      body: _carregandoDadosIniciais
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            child: _buildSeletorDePeriodo(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: _buildFiltroTipo(),
          ),
          Expanded(
            child: query == null
                ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Por favor, selecione um período (Data Início e Fim) para visualizar as movimentações.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ),
            )
                : StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Ocorreu um erro ao buscar os dados.'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Nenhuma movimentação encontrada para os filtros aplicados.'));
                }

                final movimentacoes = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: movimentacoes.length,
                  itemBuilder: (context, index) {
                    final mov = movimentacoes[index];
                    final dados = mov.data() as Map<String, dynamic>;

                    final bool isEntrada = dados['tipo'] == 'entrada';
                    final IconData icone = isEntrada ? Icons.arrow_downward : Icons.arrow_upward;
                    final Color corIcone = isEntrada ? Colors.green : Colors.red;
                    final String dataFormatada = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(dados['data']));

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: corIcone.withOpacity(0.15),
                          child: Icon(icone, color: corIcone, size: 20),
                        ),
                        title: Text(
                          dados['produtoNome'] ?? 'Produto não informado',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                            'Qtd: ${dados['quantidade']} | ${dados['subTipo'] ?? ''}\nParceiro: ${dados['nomeCliente'] ?? dados['nomeFornecedor'] ?? 'N/A'}'
                        ),
                        trailing: Text(
                          dataFormatada,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        isThreeLine: true,
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

  Future<void> _selecionarData(BuildContext context, {required bool isDataInicio}) async {
    final dataSelecionada = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (dataSelecionada != null) {
      setState(() {
        if (isDataInicio) {
          _dataInicio = dataSelecionada;
        } else {
          _dataFim = dataSelecionada;
        }
      });
    }
  }

  void _limparFiltroDePeriodo() {
    setState(() {
      _dataInicio = null;
      _dataFim = null;
    });
  }

  Widget _buildSeletorDePeriodo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(_dataInicio == null ? 'Data Início' : DateFormat('dd/MM/yyyy').format(_dataInicio!)),
          onPressed: () => _selecionarData(context, isDataInicio: true),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(_dataFim == null ? 'Data Fim' : DateFormat('dd/MM/yyyy').format(_dataFim!)),
          onPressed: () => _selecionarData(context, isDataInicio: false),
        ),
        if (_dataInicio != null || _dataFim != null)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: IconButton(
              icon: const Icon(Icons.clear, color: Colors.red),
              onPressed: _limparFiltroDePeriodo,
              tooltip: 'Limpar filtro de período',
            ),
          ),
      ],
    );
  }

  Widget _buildFiltroTipo() {
    return ToggleButtons(
      isSelected: [
        _tipoFiltro == 'todos',
        _tipoFiltro == 'entrada',
        _tipoFiltro == 'saida',
      ],
      onPressed: (index) {
        setState(() {
          if (index == 0) _tipoFiltro = 'todos';
          if (index == 1) _tipoFiltro = 'entrada';
          if (index == 2) _tipoFiltro = 'saida';
        });
      },
      borderRadius: BorderRadius.circular(8),
      selectedColor: Colors.white,
      fillColor: Colors.teal.shade300,
      color: Colors.teal.shade900,
      constraints: const BoxConstraints(minHeight: 40.0, minWidth: 100.0),
      children: const [
        Text('Todos'),
        Text('Entradas'),
        Text('Saídas'),
      ],
    );
  }
}