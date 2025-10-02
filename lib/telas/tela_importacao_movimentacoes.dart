import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
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
  String _log = 'Aguardando seleção de arquivo CSV...\n\n';
  String _fileName = '';

  Future<void> _iniciarImportacao() async {
    // 1. SELEÇÃO DO ARQUIVO
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum arquivo selecionado ou o arquivo não pôde ser lido.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _fileName = result.files.single.name;
      _log = 'Lendo arquivo "$_fileName"...\n';
    });

    // 2. LEITURA E CONVERSÃO DO CSV
    final bytes = result.files.single.bytes!;
    final csvString = utf8.decode(bytes);
    final List<List<dynamic>> rows =
    const CsvToListConverter(fieldDelimiter: ',').convert(csvString);

    if (rows.length < 2) {
      setState(() {
        _isLoading = false;
        _log += 'ERRO: O arquivo CSV está vazio ou contém apenas o cabeçalho.\n';
      });
      return;
    }

    // 3. MAPEAMENTO DO CABEÇALHO
    final headers = rows.first.map((h) => h.toString().toLowerCase().trim()).toList();
    final requiredHeaders = ['codigo', 'quantidade', 'tipo', 'data'];
    if (!requiredHeaders.every((h) => headers.contains(h))) {
      setState(() {
        _isLoading = false;
        _log += 'ERRO: O cabeçalho do arquivo deve conter as colunas: ${requiredHeaders.join(', ')}\n';
      });
      return;
    }

    final db = FirebaseFirestore.instance;
    int sucessos = 0;
    final List<String> erros = [];

    // 4. PROCESSAMENTO DAS LINHAS
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final linhaNum = i + 1;

      setState(() {
        _log = 'Processando linha $linhaNum de ${rows.length - 1}...\n';
      });

      try {
        final codigo = row[headers.indexOf('codigo')].toString().trim();
        // O "PORQUÊ": A lógica aqui agora é idêntica à do valor_unitario.
        // Trocamos int.tryParse por double.tryParse e adicionamos o replaceAll
        // para aceitar tanto "1,5" quanto "1.5" como números decimais.
        final quantidadeStr = row[headers.indexOf('quantidade')].toString().replaceAll(',', '.').trim();
        final tipo = row[headers.indexOf('tipo')].toString().trim().toLowerCase();
        final dataStr = row[headers.indexOf('data')].toString().trim();

        // Dados opcionais
        final destino = headers.contains('destino') ? row[headers.indexOf('destino')].toString().trim() : null;
        final valorUnitarioStr = headers.contains('valor_unitario') ? row[headers.indexOf('valor_unitario')].toString().replaceAll(',', '.').trim() : null;
        final centroCusto = headers.contains('centro_custo') ? row[headers.indexOf('centro_custo')].toString().trim() : null;

        // Validações
        if (codigo.isEmpty) throw Exception('Código do produto está vazio.');
        if (tipo != 'entrada' && tipo != 'saida') throw Exception('Tipo deve ser "entrada" ou "saida".');
        final quantidade = double.tryParse(quantidadeStr);
        if (quantidade == null || quantidade <= 0) throw Exception('Quantidade inválida ou zero.');
        final data = DateFormat('dd/MM/yyyy').parse(dataStr);
        final valorUnitario = valorUnitarioStr != null ? double.tryParse(valorUnitarioStr) : null;

        // 5. TRANSAÇÃO ATÔMICA NO FIRESTORE
        await db.runTransaction((transaction) async {
          // Busca o produto pelo código
          final produtoQuery = await db.collection('produtos').where('codigo', isEqualTo: codigo).limit(1).get();
          if (produtoQuery.docs.isEmpty) {
            throw Exception('Produto com código "$codigo" não encontrado.');
          }
          final produtoRef = produtoQuery.docs.first.reference;
          final produtoSnapshot = await transaction.get(produtoRef);
          final produtoData = produtoSnapshot.data() as Map<String, dynamic>;

          // O "PORQUÊ": A quantidade em estoque agora é tratada como double.
          // Usamos .toDouble() para garantir que a soma seja feita com precisão decimal.
          final quantidadeAtual = (produtoData['quantidadeAtual'] ?? 0.0).toDouble();
          final novaQuantidade = tipo == 'entrada'
              ? quantidadeAtual + quantidade
              : quantidadeAtual - quantidade;

          // Atualiza o produto
          transaction.update(produtoRef, {'quantidadeAtual': novaQuantidade});

          // Cria a movimentação
          final movRef = db.collection('movimentacoes').doc();
          transaction.set(movRef, {
            'produtoId': produtoRef.id,
            'produtoNome': produtoData['nome'] ?? 'N/D',
            'produtoCodigo': codigo,
            'tipo': tipo,
            'subTipo': destino ?? 'Importado',
            'quantidade': quantidade, // Agora salva um double
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

    // 6. RELATÓRIO FINAL
    setState(() {
      _isLoading = false;
      _log = 'Importação de "$_fileName" concluída!\n\n'
          'Resultados:\n'
          '- $sucessos movimentações importadas com sucesso.\n'
          '- ${erros.length} linhas com erro.\n\n'
          'Detalhes dos erros:\n'
          '${erros.join('\n')}';
    });
  }

  Future<void> _resetarDados() async {
    setState(() {
      _isLoading = true;
      _log = 'Iniciando a redefinição de dados...\n';
    });

    final db = FirebaseFirestore.instance;

    try {
      // 1. Apagar todas as movimentações
      setState(() => _log += 'Apagando movimentações antigas...\n');
      final movSnapshot = await db.collection('movimentacoes').get();
      final batchDelete = db.batch();
      for (final doc in movSnapshot.docs) {
        batchDelete.delete(doc.reference);
      }
      await batchDelete.commit();
      setState(() => _log += '- ${movSnapshot.docs.length} movimentações foram apagadas.\n');

      // 2. Redefinir o estoque de todos os produtos para 0
      setState(() => _log += 'Redefinindo estoque dos produtos para zero...\n');
      final prodSnapshot = await db.collection('produtos').get();
      final batchUpdate = db.batch();
      for (final doc in prodSnapshot.docs) {
        batchUpdate.update(doc.reference, {'quantidadeAtual': 0});
      }
      await batchUpdate.commit();
      setState(() => _log += '- ${prodSnapshot.docs.length} produtos tiveram seu estoque zerado.\n\n');

      _log += 'Redefinição concluída! Você já pode importar o novo arquivo.\n';

    } catch (e) {
      _log += 'ERRO DURANTE A REDEFINIÇÃO: ${e.toString()}\n';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _mostrarDialogoReset() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ ATENÇÃO: Ação Irreversível'),
        content: const Text(
            'Você tem certeza que deseja apagar TODAS as movimentações e ZERAR o estoque de TODOS os produtos?\n\n'
                'Use esta função apenas antes da primeira importação de dados históricos.'
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sim, apagar tudo'),
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
            ElevatedButton.icon(
              icon: const Icon(Icons.file_upload),
              label: const Text('Selecionar Arquivo CSV'),
              onPressed: _isLoading ? null : _iniciarImportacao,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
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
                label: const Text('Redefinir Dados (Apagar Tudo)'),
                onPressed: _isLoading ? null : _mostrarDialogoReset,
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

