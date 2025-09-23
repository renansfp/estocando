// TELA DE IMPORTAÇÃO DE PARCEIROS

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

class TelaImportacaoParceiros extends StatefulWidget {
  const TelaImportacaoParceiros({super.key});

  @override
  State<TelaImportacaoParceiros> createState() => _TelaImportacaoParceirosState();
}

enum StatusImportacao { inicial, carregando, sucesso, erro }

class _TelaImportacaoParceirosState extends State<TelaImportacaoParceiros> {
  StatusImportacao _status = StatusImportacao.inicial;
  String _mensagemStatus = 'Aguardando seleção dos arquivos.';

  FilePickerResult? _parceirosFile;
  FilePickerResult? _pagamentosFile;
  FilePickerResult? _recebimentosFile;

  // Função genérica para selecionar arquivos
  Future<FilePickerResult?> _selecionarArquivo() async {
    try {
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      return resultado;
    } catch (e) {
      setState(() {
        _status = StatusImportacao.erro;
        _mensagemStatus = 'Erro ao selecionar o arquivo: $e';
      });
    }
    return null;
  }

  Future<void> _iniciarImportacao() async {
    if (_parceirosFile == null || _pagamentosFile == null || _recebimentosFile == null) {
      setState(() {
        _status = StatusImportacao.erro;
        _mensagemStatus = 'Por favor, selecione os três arquivos CSV.';
      });
      return;
    }

    setState(() {
      _status = StatusImportacao.carregando;
      _mensagemStatus = 'Iniciando importação...';
    });

    try {
      final db = FirebaseFirestore.instance;

      // ETAPA 1: Ler os arquivos de transações para criar o mapa de classificação.
      setState(() { _mensagemStatus = 'Lendo arquivos de transações...'; });

      final Map<String, Map<String, int>> contagemTransacoes = {}; // { 'codigo_parceiro': {'pagamentos': X, 'recebimentos': Y} }

      // Processa pagamentos
      final bytesPag = _pagamentosFile!.files.first.bytes!;
      final conteudoPag = utf8.decode(bytesPag);
      final delimitadorPag = (conteudoPag.split('\n').first.contains(';') ? ';' : ',');
      final linhasPag = CsvToListConverter(fieldDelimiter: delimitadorPag).convert(conteudoPag);
      for (final linha in linhasPag) {
        if (linha.isEmpty) continue;
        final codigo = linha[0].toString().trim();
        if (codigo.isEmpty) continue;
        contagemTransacoes.putIfAbsent(codigo, () => {'pagamentos': 0, 'recebimentos': 0});
        contagemTransacoes[codigo]!['pagamentos'] = (contagemTransacoes[codigo]!['pagamentos'] ?? 0) + 1;
      }

      // Processa recebimentos
      final bytesRec = _recebimentosFile!.files.first.bytes!;
      final conteudoRec = utf8.decode(bytesRec);
      final delimitadorRec = (conteudoRec.split('\n').first.contains(';') ? ';' : ',');
      final linhasRec = CsvToListConverter(fieldDelimiter: delimitadorRec).convert(conteudoRec);
      for (final linha in linhasRec) {
        if (linha.isEmpty) continue;
        final codigo = linha[0].toString().trim();
        if (codigo.isEmpty) continue;
        contagemTransacoes.putIfAbsent(codigo, () => {'pagamentos': 0, 'recebimentos': 0});
        contagemTransacoes[codigo]!['recebimentos'] = (contagemTransacoes[codigo]!['recebimentos'] ?? 0) + 1;
      }

      // ETAPA 2: Ler arquivo principal de parceiros.
      setState(() { _mensagemStatus = 'Lendo arquivo de parceiros...'; });
      final bytesParc = _parceirosFile!.files.first.bytes!;
      final conteudoParc = utf8.decode(bytesParc);
      final delimitadorParc = (conteudoParc.split('\n').first.contains(';') ? ';' : ',');
      final linhasParc = CsvToListConverter(fieldDelimiter: delimitadorParc).convert(conteudoParc);

      if (linhasParc.length <= 1) {
        throw Exception("Arquivo de parceiros está vazio ou contém apenas o cabeçalho.");
      }

      // ETAPA 3: FASE DE VALIDAÇÃO ("TUDO OU NADA")
      setState(() { _mensagemStatus = 'Validando dados...'; });

      // Busca dados existentes no DB de uma só vez
      final parceirosSnapshot = await db.collection('parceiros').get();
      final codigosExistentes = parceirosSnapshot.docs.map((doc) => doc['codigo'] as String).toSet();
      final cnpjsExistentes = parceirosSnapshot.docs.map((doc) => doc['cnpj'] as String?).where((cnpj) => cnpj != null && cnpj.isNotEmpty).toSet();

      final List<Map<String, dynamic>> parceirosParaAdicionar = [];
      final Set<String> codigosNoArquivo = {};
      final Set<String> cnpjsNoArquivo = {};

      for (int i = 1; i < linhasParc.length; i++) {
        final linha = linhasParc[i];
        if (linha.length < 4) continue;

        final codigo = linha[0].toString().trim();
        final nome = linha[1].toString().trim();
        final cnpj = linha[3].toString().trim().replaceAll(RegExp(r'[^0-9]'), '');

        // Regra: Ignorar se não teve transação
        if (!contagemTransacoes.containsKey(codigo)) {
          continue;
        }

        // Validação: Duplicidade de código no arquivo
        if (codigosNoArquivo.contains(codigo)) throw Exception("Código duplicado DENTRO do arquivo CSV: $codigo");
        codigosNoArquivo.add(codigo);

        // Validação: Duplicidade de CNPJ no arquivo
        if (cnpj.isNotEmpty) {
          if (cnpjsNoArquivo.contains(cnpj)) throw Exception("CNPJ/CPF duplicado DENTRO do arquivo CSV: $cnpj");
          cnpjsNoArquivo.add(cnpj);
        }

        // Validação: Duplicidade com o banco de dados
        if (codigosExistentes.contains(codigo)) throw Exception("Código já existente no banco de dados: $codigo");
        if (cnpj.isNotEmpty && cnpjsExistentes.contains(cnpj)) throw Exception("CNPJ/CPF já existente no banco de dados: $cnpj");

        // Se passou em todas as validações, classifica e adiciona à lista para importação
        final contagens = contagemTransacoes[codigo]!;
        final pagamentos = contagens['pagamentos']!;
        final recebimentos = contagens['recebimentos']!;
        final String tipoParceiro = (recebimentos >= pagamentos) ? 'cliente' : 'fornecedor';

        parceirosParaAdicionar.add({
          'codigo': codigo,
          'nome': nome,
          'natureza': linha[2].toString().trim(),
          'cnpj': cnpj,
          'tipo': tipoParceiro,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // ETAPA 4: SALVAR EM LOTE (BATCH WRITE)
      if (parceirosParaAdicionar.isEmpty) {
        throw Exception("Nenhum parceiro novo e relevante encontrado para importar.");
      }

      setState(() { _mensagemStatus = 'Salvando ${parceirosParaAdicionar.length} parceiros...'; });
      final batch = db.batch();
      for(final parceiroData in parceirosParaAdicionar) {
        final docRef = db.collection('parceiros').doc();
        batch.set(docRef, parceiroData);
      }
      await batch.commit();

      // ETAPA 5: SUCESSO
      setState(() {
        _status = StatusImportacao.sucesso;
        _mensagemStatus = 'Importação Concluída!\n\n${parceirosParaAdicionar.length} parceiros novos cadastrados.';
      });

    } catch (e) {
      setState(() {
        _status = StatusImportacao.erro;
        _mensagemStatus = 'ERRO: ${e.toString().replaceAll("Exception: ", "")}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar Parceiros via CSV'),
        backgroundColor: const Color.fromRGBO(17, 52, 82, 1),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFilePickerButton(
                label: '1. Selecionar Parceiros (.csv)',
                fileResult: _parceirosFile,
                onPressed: () async {
                  final file = await _selecionarArquivo();
                  if (file != null) setState(() => _parceirosFile = file);
                },
              ),
              const SizedBox(height: 16),
              _buildFilePickerButton(
                label: '2. Selecionar Pagamentos (.csv)',
                fileResult: _pagamentosFile,
                onPressed: () async {
                  final file = await _selecionarArquivo();
                  if (file != null) setState(() => _pagamentosFile = file);
                },
              ),
              const SizedBox(height: 16),
              _buildFilePickerButton(
                label: '3. Selecionar Recebimentos (.csv)',
                fileResult: _recebimentosFile,
                onPressed: () async {
                  final file = await _selecionarArquivo();
                  if (file != null) setState(() => _recebimentosFile = file);
                },
              ),
              const SizedBox(height: 32),
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
                onPressed: (_parceirosFile != null && _pagamentosFile != null && _recebimentosFile != null && _status != StatusImportacao.carregando)
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

  Widget _buildFilePickerButton({
    required String label,
    required FilePickerResult? fileResult,
    required VoidCallback onPressed,
  }) {
    final bool isSelected = fileResult != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          icon: Icon(isSelected ? Icons.check_circle : Icons.folder_open, color: isSelected ? Colors.green : null),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            textStyle: const TextStyle(fontSize: 16),
          ),
          onPressed: onPressed,
        ),
        if (isSelected)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              fileResult.files.first.name,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic),
            ),
          )
      ],
    );
  }

  Widget _buildWidgetDeStatus() {
    // Este widget continua o mesmo da importação de produtos
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