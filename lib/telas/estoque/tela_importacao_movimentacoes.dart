// CÓDIGO FINAL E SEGURO - TELA DE IMPORTAÇÃO DE MOVIMENTAÇÕES

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ---> MUDANÇA 1
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TelaImportacaoMovimentacoes extends StatefulWidget {
  const TelaImportacaoMovimentacoes({super.key});

  @override
  State<TelaImportacaoMovimentacoes> createState() =>
      _TelaImportacaoMovimentacoesState();
}

class _TelaImportacaoMovimentacoesState
    extends State<TelaImportacaoMovimentacoes> {
  bool _isLoading = false;
  String _log = 'Aguardando seleção da empresa...\n';
  String _fileName = '';

  // ---> MUDANÇA 2: Variáveis para seleção de empresa
  List<Map<String, String>> _listaEmpresas = [];
  Map<String, String>? _empresaSelecionada;
  bool _carregandoEmpresas = true;

  @override
  void initState() {
    super.initState();
    _carregarEmpresas(); // ---> MUDANÇA 3
  }

  // ---> MUDANÇA 4: Nova função para carregar as empresas
  Future<void> _carregarEmpresas() async {
    try {
      final usuariosSnapshot = await FirebaseFirestore.instance.collection('usuarios').get();
      if (!mounted) return;
      final Map<String, String> empresasMap = {};
      for (var userDoc in usuariosSnapshot.docs) {
        final data = userDoc.data();
        final empresaId = data['empresaId'] as String?;
        final nomeEmpresa = data['nome'] as String?;
        if (empresaId != null && nomeEmpresa != null) {
          empresasMap.putIfAbsent(empresaId, () => nomeEmpresa);
        }
      }
      final listaFormatada = empresasMap.entries.map((entry) => {'id': entry.key, 'nome': entry.value}).toList();
      setState(() {
        _listaEmpresas = listaFormatada;
        _carregandoEmpresas = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _log = "Erro ao carregar empresas: $e";
          _carregandoEmpresas = false;
        });
      }
    }
  }

  Future<void> _iniciarImportacao() async {
    if (_empresaSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecione uma empresa primeiro.')));
      return;
    }

    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'], withData: true);
    if (result == null || result.files.single.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum arquivo selecionado.')));
      return;
    }

    setState(() {
      _isLoading = true;
      _fileName = result.files.single.name;
      _log = 'Lendo arquivo "$_fileName"...\n';
    });

    final bytes = result.files.single.bytes!;
    final csvString = utf8.decode(bytes);
    final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);

    if (rows.length < 2) {
      setState(() { _isLoading = false; _log += 'ERRO: O arquivo CSV está vazio ou contém apenas o cabeçalho.\n'; });
      return;
    }

    final headers = rows.first.map((h) => h.toString().toLowerCase().trim()).toList();
    final requiredHeaders = ['codigo', 'quantidade', 'tipo', 'data'];
    if (!requiredHeaders.every((h) => headers.contains(h))) {
      setState(() { _isLoading = false; _log += 'ERRO: O cabeçalho deve conter: ${requiredHeaders.join(', ')}\n'; });
      return;
    }

    final db = FirebaseFirestore.instance;
    int sucessos = 0;
    final List<String> erros = [];
    final String empresaId = _empresaSelecionada!['id']!;

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final linhaNum = i + 1;

      setState(() { _log = 'Processando linha $linhaNum de ${rows.length - 1}...\n'; });

      try {
        final codigo = row[headers.indexOf('codigo')].toString().trim();
        final quantidadeStr = row[headers.indexOf('quantidade')].toString().replaceAll(',', '.').trim();
        final tipo = row[headers.indexOf('tipo')].toString().trim().toLowerCase();
        final dataStr = row[headers.indexOf('data')].toString().trim();
        final destino = headers.contains('destino') ? row[headers.indexOf('destino')].toString().trim() : null;
        final valorUnitarioStr = headers.contains('valor_unitario') ? row[headers.indexOf('valor_unitario')].toString().replaceAll(',', '.').trim() : null;
        final centroCusto = headers.contains('centro_custo') ? row[headers.indexOf('centro_custo')].toString().trim() : null;

        if (codigo.isEmpty) throw Exception('Código do produto está vazio.');
        if (tipo != 'entrada' && tipo != 'saida') throw Exception('Tipo deve ser "entrada" ou "saida".');
        final quantidade = double.tryParse(quantidadeStr);
        if (quantidade == null || quantidade <= 0) throw Exception('Quantidade inválida ou zero.');
        final data = DateFormat('dd/MM/yyyy').parse(dataStr);
        final valorUnitario = valorUnitarioStr != null ? double.tryParse(valorUnitarioStr) : null;

        await db.runTransaction((transaction) async {
          // ---> MUDANÇA 5: A busca pelo produto agora é filtrada por empresa.
          final produtoQuery = await db.collection('produtos')
              .where('empresaId', isEqualTo: empresaId)
              .where('codigo', isEqualTo: codigo)
              .limit(1)
              .get();

          if (produtoQuery.docs.isEmpty) {
            throw Exception('Produto com código "$codigo" não encontrado na empresa selecionada.');
          }
          final produtoRef = produtoQuery.docs.first.reference;
          final produtoSnapshot = await transaction.get(produtoRef);
          final produtoData = produtoSnapshot.data() as Map<String, dynamic>;

          final quantidadeAtual = (produtoData['quantidadeAtual'] ?? 0.0).toDouble();
          final novaQuantidade = tipo == 'entrada' ? quantidadeAtual + quantidade : quantidadeAtual - quantidade;

          transaction.update(produtoRef, {'quantidadeAtual': novaQuantidade});

          final movRef = db.collection('movimentacoes').doc();
          // ---> MUDANÇA 6: "Carimbamos" a nova movimentação com o empresaId.
          transaction.set(movRef, {
            'empresaId': empresaId,
            'produtoId': produtoRef.id,
            'produtoNome': produtoData['nome'] ?? 'N/D',
            'produtoCodigo': codigo,
            'tipo': tipo,
            'subTipo': destino ?? 'Importado',
            'quantidade': quantidade,
            'data': Timestamp.fromDate(data),
            'valorUnitario': valorUnitario,
            'centroDeCusto': centroCusto,
            'usuarioEmail': 'importacao_csv',
          });
        });

        sucessos++;
      } catch (e) {
        erros.add('Linha $linhaNum: ${e.toString().replaceAll('Exception: ', '')}');
      }
    }

    setState(() {
      _isLoading = false;
      _log = 'Importação para "${_empresaSelecionada!['nome']}" concluída!\n\n'
          'Resultados:\n'
          '- $sucessos movimentações importadas com sucesso.\n'
          '- ${erros.length} linhas com erro.\n\n'
          'Detalhes dos erros:\n'
          '${erros.join('\n')}';
    });
  }

  Future<void> _resetarDados() async {
    if (_empresaSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecione uma empresa para redefinir os dados.')));
      return;
    }

    setState(() { _isLoading = true; _log = 'Iniciando a redefinição de dados para "${_empresaSelecionada!['nome']}"...\n'; });

    final db = FirebaseFirestore.instance;
    final String empresaId = _empresaSelecionada!['id']!;

    try {
      // ---> MUDANÇA 7: A busca por movimentações para apagar agora é filtrada por empresa.
      setState(() => _log += 'Apagando movimentações antigas da empresa...\n');
      final movSnapshot = await db.collection('movimentacoes').where('empresaId', isEqualTo: empresaId).get();
      final batchDelete = db.batch();
      for (final doc in movSnapshot.docs) {
        batchDelete.delete(doc.reference);
      }
      await batchDelete.commit();
      setState(() => _log += '- ${movSnapshot.docs.length} movimentações foram apagadas.\n');

      // ---> MUDANÇA 8: A busca por produtos para zerar o estoque agora é filtrada por empresa.
      setState(() => _log += 'Redefinindo estoque dos produtos da empresa para zero...\n');
      final prodSnapshot = await db.collection('produtos').where('empresaId', isEqualTo: empresaId).get();
      final batchUpdate = db.batch();
      for (final doc in prodSnapshot.docs) {
        batchUpdate.update(doc.reference, {'quantidadeAtual': 0});
      }
      await batchUpdate.commit();
      setState(() => _log += '- ${prodSnapshot.docs.length} produtos tiveram seu estoque zerado.\n\n');

      _log += 'Redefinição concluída! Você já pode importar o novo arquivo para esta empresa.\n';

    } catch (e) {
      _log += 'ERRO DURANTE A REDEFINIÇÃO: ${e.toString()}\n';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _mostrarDialogoReset() {
    if (_empresaSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecione uma empresa antes de redefinir os dados.')));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ ATENÇÃO: Ação Irreversível'),
        content: Text(
            'Você tem certeza que deseja apagar TODAS as movimentações e ZERAR o estoque de TODOS os produtos da empresa "${_empresaSelecionada!['nome']}"?\n\n'
                'Esta ação não pode ser desfeita.'
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sim, apagar dados da empresa'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _resetarDados();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar Movimentações'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---> MUDANÇA 9: Seletor de empresa adicionado ao topo da tela.
            if (_carregandoEmpresas)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<Map<String, String>>(
                value: _empresaSelecionada,
                hint: const Text('1. Selecione a Empresa'),
                isExpanded: true,
                items: _listaEmpresas.map((empresa) {
                  return DropdownMenuItem<Map<String, String>>(
                    value: empresa,
                    child: Text(empresa['nome'] ?? 'Empresa Desconhecida'),
                  );
                }).toList(),
                onChanged: (valor) {
                  setState(() {
                    _empresaSelecionada = valor;
                    _log = 'Empresa selecionada. Agora selecione o arquivo de movimentações.';
                  });
                },
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            const SizedBox(height: 20),

            ElevatedButton.icon(
              icon: const Icon(Icons.file_upload),
              label: const Text('2. Selecionar e Importar CSV'),
              onPressed: (_isLoading || _empresaSelecionada == null) ? null : _iniciarImportacao,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  disabledBackgroundColor: Colors.grey.shade300
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Log de Importação:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.grey.shade200,
                child: _isLoading
                    ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(_log, textAlign: TextAlign.center),
                      ],
                    ))
                    : SingleChildScrollView(
                  child: Text(_log),
                ),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextButton.icon(
                icon: const Icon(Icons.warning_amber_rounded),
                label: const Text('Redefinir Dados da Empresa'),
                onPressed: (_isLoading || _empresaSelecionada == null) ? null : _mostrarDialogoReset,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}