import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/provider/movimentacao_provider.dart';

class TelaExtratoMovimentacoes extends StatefulWidget {
  const TelaExtratoMovimentacoes({super.key});

  @override
  State<TelaExtratoMovimentacoes> createState() =>
      _TelaExtratoMovimentacoesState();
}

class _TelaExtratoMovimentacoesState extends State<TelaExtratoMovimentacoes> {
  DateTime? _dataInicio;
  DateTime? _dataFim;
  String _tipoFiltro = 'todos';

  Future<void> _selecionarData(BuildContext context,
      {required bool isDataInicio}) async {
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

  @override
  Widget build(BuildContext context) {
    // Usa UsuarioProvider — sem Firestore direto
    final usuario = context.watch<UsuarioProvider>().usuario;
    final empresaId = usuario?.empresaId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Extrato de Movimentações'),
        backgroundColor: Colors.teal,
      ),
      body: empresaId == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            child: _buildSeletorDePeriodo(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 8.0, vertical: 4.0),
            child: _buildFiltroTipo(),
          ),
          Expanded(
            child: (_dataInicio == null || _dataFim == null)
                ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Por favor, selecione um período (Data Início e Fim) para visualizar as movimentações.',
                  textAlign: TextAlign.center,
                  style:
                  TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ),
            )
                : FutureBuilder<List<Map<String, dynamic>>>(
              future: context
                  .read<MovimentacaoProvider>()
                  .buscarMovimentacoesFiltradas(
                empresaId,
                dataInicio: _dataInicio,
                dataFim: _dataFim,
                tipo: _tipoFiltro == 'todos'
                    ? null
                    : _tipoFiltro,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                      child: Text(
                          'Ocorreu um erro ao buscar os dados.'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text(
                          'Nenhuma movimentação encontrada para os filtros aplicados.'));
                }

                final movimentacoes = snapshot.data!;

                return ListView.builder(
                  itemCount: movimentacoes.length,
                  itemBuilder: (context, index) {
                    final mov = movimentacoes[index];
                    final bool isEntrada = mov['tipo'] == 'entrada';
                    final Color corIcone =
                    isEntrada ? Colors.green : Colors.red;

                    final dataDoBanco = mov['data'] as DateTime;
                    final String dataFormatada =
                    DateFormat('dd/MM/yyyy HH:mm')
                        .format(dataDoBanco);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 6.0),
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                          corIcone.withOpacity(0.15),
                          child: Icon(
                            isEntrada
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: corIcone,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          mov['produtoNome'] ??
                              'Produto não informado',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                            'Qtd: ${mov['quantidade']} | ${mov['subTipo'] ?? ''}\nParceiro: ${mov['nomeCliente'] ?? mov['nomeFornecedor'] ?? 'N/A'}'),
                        trailing: Text(dataFormatada,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
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

  Widget _buildSeletorDePeriodo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(_dataInicio == null
              ? 'Data Início'
              : DateFormat('dd/MM/yyyy').format(_dataInicio!)),
          onPressed: () => _selecionarData(context, isDataInicio: true),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(_dataFim == null
              ? 'Data Fim'
              : DateFormat('dd/MM/yyyy').format(_dataFim!)),
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
      constraints:
      const BoxConstraints(minHeight: 40.0, minWidth: 100.0),
      children: const [
        Text('Todos'),
        Text('Entradas'),
        Text('Saídas'),
      ],
    );
  }
}