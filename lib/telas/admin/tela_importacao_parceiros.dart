// CÓDIGO COMPLETO E SEGURO COM LÓGICA DE MULTI-EMPRESA

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
  String _mensagemStatus = 'Selecione uma empresa para começar.';

  FilePickerResult? _parceirosFile;
  FilePickerResult? _pagamentosFile;
  FilePickerResult? _recebimentosFile;

  // ---> MUDANÇA 1: Novas variáveis para gerenciar a seleção de empresas.
  List<Map<String, String>> _listaEmpresas = [];
  Map<String, String>? _empresaSelecionada;
  bool _carregandoEmpresas = true;

  @override
  void initState() {
    super.initState();
    _carregarEmpresas(); // ---> MUDANÇA 2: Chamamos a função para buscar as empresas.
  }

  // ---> MUDANÇA 3: Nova função para buscar todas as empresas cadastradas.
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

      final listaFormatada = empresasMap.entries.map((entry) {
        return {'id': entry.key, 'nome': entry.value};
      }).toList();

      setState(() {
        _listaEmpresas = listaFormatada;
        _carregandoEmpresas = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _mensagemStatus = "Erro ao carregar empresas: $e";
          _status = StatusImportacao.erro;
          _carregandoEmpresas = false;
        });
      }
    }
  }

  Future<FilePickerResult?> _selecionarArquivo() async {
    // A checagem de empresa selecionada já é feita no botão
    try {
      final resultado = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'], withData: true);
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
    // ---> MUDANÇA 4: Verificação de segurança para garantir que uma empresa foi selecionada.
    if (_empresaSelecionada == null || _empresaSelecionada!['id'] == null) {
      setState(() { _status = StatusImportacao.erro; _mensagemStatus = 'Por favor, selecione uma empresa válida.'; });
      return;
    }

    if (_parceirosFile == null || _pagamentosFile == null || _recebimentosFile == null) {
      setState(() { _status = StatusImportacao.erro; _mensagemStatus = 'Por favor, selecione os três arquivos CSV.'; });
      return;
    }

    setState(() { _status = StatusImportacao.carregando; _mensagemStatus = 'Iniciando importação...'; });

    try {
      final db = FirebaseFirestore.instance;
      final String empresaIdSelecionada = _empresaSelecionada!['id']!;

      setState(() { _mensagemStatus = 'Lendo arquivos de transações...'; });
      final Map<String, Map<String, int>> contagemTransacoes = {};

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

      setState(() { _mensagemStatus = 'Lendo arquivo de parceiros...'; });
      final bytesParc = _parceirosFile!.files.first.bytes!;
      final conteudoParc = utf8.decode(bytesParc);
      final delimitadorParc = (conteudoParc.split('\n').first.contains(';') ? ';' : ',');
      final linhasParc = CsvToListConverter(fieldDelimiter: delimitadorParc).convert(conteudoParc);

      if (linhasParc.length <= 1) throw Exception("Arquivo de parceiros está vazio ou contém apenas o cabeçalho.");

      setState(() { _mensagemStatus = 'Validando dados...'; });

      // ---> MUDANÇA 5: A busca por parceiros existentes agora é filtrada por empresa.
      final parceirosSnapshot = await db.collection('parceiros').where('empresaId', isEqualTo: empresaIdSelecionada).get();
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

        if (!contagemTransacoes.containsKey(codigo)) continue;
        if (codigosNoArquivo.contains(codigo)) throw Exception("Código duplicado DENTRO do arquivo CSV: $codigo");
        codigosNoArquivo.add(codigo);
        if (cnpj.isNotEmpty) {
          if (cnpjsNoArquivo.contains(cnpj)) throw Exception("CNPJ/CPF duplicado DENTRO do arquivo CSV: $cnpj");
          cnpjsNoArquivo.add(cnpj);
        }
        if (codigosExistentes.contains(codigo)) throw Exception("Código já existente no banco de dados: $codigo");
        if (cnpj.isNotEmpty && cnpjsExistentes.contains(cnpj)) throw Exception("CNPJ/CPF já existente no banco de dados: $cnpj");

        final contagens = contagemTransacoes[codigo]!;
        final pagamentos = contagens['pagamentos']!;
        final recebimentos = contagens['recebimentos']!;
        final String tipoParceiro = (recebimentos >= pagamentos) ? 'cliente' : 'fornecedor';

        parceirosParaAdicionar.add({
          // ---> MUDANÇA 6: "Carimbamos" o novo parceiro com o ID da empresa.
          'empresaId': empresaIdSelecionada,
          'codigo': codigo,
          'nome': nome,
          'natureza': linha[2].toString().trim(),
          'cnpj': cnpj,
          'tipo': tipoParceiro,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (parceirosParaAdicionar.isEmpty) throw Exception("Nenhum parceiro novo e relevante encontrado para importar.");

      setState(() { _mensagemStatus = 'Salvando ${parceirosParaAdicionar.length} parceiros...'; });
      final batch = db.batch();
      for(final parceiroData in parceirosParaAdicionar) {
        final docRef = db.collection('parceiros').doc();
        batch.set(docRef, parceiroData);
      }
      await batch.commit();

      setState(() {
        _status = StatusImportacao.sucesso;
        _mensagemStatus = 'Importação Concluída!\n\n${parceirosParaAdicionar.length} parceiros cadastrados para a empresa: ${_empresaSelecionada!['nome']}.';
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
              // ---> MUDANÇA 7: Novo Dropdown para selecionar a empresa.
              if (_carregandoEmpresas)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<Map<String, String>>(
                  value: _empresaSelecionada,
                  hint: const Text('1. Selecione a Empresa de Destino'),
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
                      _mensagemStatus = 'Empresa selecionada. Agora selecione os arquivos.';
                      _parceirosFile = null;
                      _pagamentosFile = null;
                      _recebimentosFile = null;
                    });
                  },
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),

              const SizedBox(height: 24),

              _buildFilePickerButton(
                label: '2. Selecionar Parceiros (.csv)',
                fileResult: _parceirosFile,
                onPressed: () async {
                  if (_empresaSelecionada == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione uma empresa primeiro.'), backgroundColor: Colors.orange));
                    return;
                  }
                  final file = await _selecionarArquivo();
                  if (file != null) setState(() => _parceirosFile = file);
                },
              ),
              const SizedBox(height: 16),
              _buildFilePickerButton(
                label: '3. Selecionar Pagamentos (.csv)',
                fileResult: _pagamentosFile,
                onPressed: () async {
                  if (_empresaSelecionada == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione uma empresa primeiro.'), backgroundColor: Colors.orange));
                    return;
                  }
                  final file = await _selecionarArquivo();
                  if (file != null) setState(() => _pagamentosFile = file);
                },
              ),
              const SizedBox(height: 16),
              _buildFilePickerButton(
                label: '4. Selecionar Recebimentos (.csv)',
                fileResult: _recebimentosFile,
                onPressed: () async {
                  if (_empresaSelecionada == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione uma empresa primeiro.'), backgroundColor: Colors.orange));
                    return;
                  }
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
            disabledBackgroundColor: Colors.grey.shade300,
          ),
          onPressed: _empresaSelecionada != null ? onPressed : null,
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