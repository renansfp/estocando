import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

class TelaImportacaoProdutos extends StatefulWidget {
  const TelaImportacaoProdutos({super.key});

  @override
  State<TelaImportacaoProdutos> createState() => _TelaImportacaoProdutosState();
}

enum StatusImportacao {
  inicial,
  carregando,
  sucesso,
  erro,
}

class _TelaImportacaoProdutosState extends State<TelaImportacaoProdutos> {
  StatusImportacao _status = StatusImportacao.inicial;
  String _mensagemStatus = 'Nenhum arquivo selecionado.';
  FilePickerResult? _resultadoPicker;

  Future<void> _selecionarArquivo() async {
    try {
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (resultado != null) {
        setState(() {
          _resultadoPicker = resultado;
          _mensagemStatus = 'Arquivo selecionado: ${resultado.files.first.name}';
          _status = StatusImportacao.inicial;
        });
      } else {
        print('Nenhum arquivo selecionado.');
      }
    } catch (e) {
      setState(() {
        _status = StatusImportacao.erro;
        _mensagemStatus = 'Erro ao selecionar o arquivo: $e';
      });
    }
  }

  Future<void> _iniciarImportacao() async {
    if (_resultadoPicker == null) {
      setState(() {
        _status = StatusImportacao.erro;
        _mensagemStatus = 'Por favor, selecione um arquivo primeiro.';
      });
      return;
    }

    setState(() {
      _status = StatusImportacao.carregando;
      _mensagemStatus = 'Iniciando importação...';
    });

    try {
      setState(() { _mensagemStatus = 'Verificando produtos existentes...'; });
      final db = FirebaseFirestore.instance;
      final produtosSnapshot = await db.collection('produtos').get();
      final codigosExistentes = produtosSnapshot.docs.map((doc) => doc['codigo'] as String).toSet();

      setState(() { _mensagemStatus = 'Lendo arquivo CSV...'; });
      final bytes = _resultadoPicker!.files.first.bytes!;
      final conteudoArquivo = utf8.decode(bytes);

      // ================== MODIFICAÇÃO PRINCIPAL ==================
      // Adicionamos um "detetive" para descobrir o separador (delimitador).
      // Ele olha para a primeira linha do arquivo e vê se tem mais vírgulas ou ponto-e-vírgulas.
      final primeiraLinha = conteudoArquivo.split('\n').first;
      final String delimitador = (primeiraLinha.split(';').length > primeiraLinha.split(',').length) ? ';' : ',';
      print('Delimitador detectado: "$delimitador"'); // Log para depuração

      // Usamos o delimitador que o nosso "detetive" encontrou.
      final List<List<dynamic>> linhas = CsvToListConverter(fieldDelimiter: delimitador).convert(conteudoArquivo);
      // ========================================================

      if (linhas.length <= 1) {
        throw Exception("O arquivo CSV está vazio ou contém apenas o cabeçalho.");
      }

      final batch = db.batch();
      int produtosNovos = 0;
      int produtosIgnorados = 0;

      for (int i = 1; i < linhas.length; i++) {
        final linha = linhas[i];
        if (linha.length < 8) {
          print('Linha ${i+1} ignorada (colunas insuficientes: ${linha.length})');
          continue;
        }

        final codigo = linha[0].toString().trim();
        if (codigosExistentes.contains(codigo) || codigo.isEmpty) {
          produtosIgnorados++;
          continue;
        }

        final novoProdutoRef = db.collection('produtos').doc();
        batch.set(novoProdutoRef, {
          'codigo': codigo,
          'nome': linha[1].toString().trim(),
          'valor': double.tryParse(linha[2].toString().replaceAll(',', '.')) ?? 0.0,
          'unidade': linha[3].toString().trim(),
          'tipo': linha[4].toString().trim(),
          'grupo': linha[5].toString().trim().toUpperCase(),
          'estoqueMinimo': int.tryParse(linha[6].toString()) ?? 0,
          'estoqueMaximo': int.tryParse(linha[7].toString()) ?? 0,
          'quantidadeAtual': 0,
          'numeroSC': null,
          'timestamp': FieldValue.serverTimestamp(),
        });
        produtosNovos++;
      }

      if (produtosNovos > 0) {
        setState(() { _mensagemStatus = 'Salvando $produtosNovos produtos no banco de dados...'; });
        await batch.commit();
      }

      setState(() {
        _status = StatusImportacao.sucesso;
        _mensagemStatus = 'Importação Concluída!\n\n$produtosNovos produtos cadastrados.\n$produtosIgnorados produtos ignorados (código duplicado ou vazio).';
      });

    } catch (e) {
      setState(() {
        _status = StatusImportacao.erro;
        _mensagemStatus = 'ERRO: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nenhuma mudança visual no build
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar Produtos via CSV'),
        backgroundColor: Colors.teal,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.upload_file, size: 80, color: Colors.teal.shade200),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('Selecionar Arquivo CSV'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                onPressed: _selecionarArquivo,
              ),
              const SizedBox(height: 24),

              _buildWidgetDeStatus(),
              const SizedBox(height: 32),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade400,
                ),
                onPressed: (_resultadoPicker != null && _status != StatusImportacao.carregando)
                    ? _iniciarImportacao
                    : null,
                child: _status == StatusImportacao.carregando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Iniciar Importação'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWidgetDeStatus() {
    switch (_status) {
      case StatusImportacao.carregando:
        return Center(
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 10),
              Text(_mensagemStatus, textAlign: TextAlign.center),
            ],
          ),
        );
      case StatusImportacao.sucesso:
        return Text(
          _mensagemStatus,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold),
        );
      case StatusImportacao.erro:
        return Text(
          _mensagemStatus,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold),
        );
      case StatusImportacao.inicial:
      default:
        return Text(
          _mensagemStatus,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        );
    }
  }
}