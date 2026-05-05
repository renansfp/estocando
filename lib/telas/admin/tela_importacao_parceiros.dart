// lib/telas/admin/tela_importacao_parceiros.dart
// Migrada para Repository Pattern — sem acesso direto ao Firestore.

import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/parceiro_provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';

class TelaImportacaoParceiros extends StatefulWidget {
  const TelaImportacaoParceiros({super.key});

  @override
  State<TelaImportacaoParceiros> createState() =>
      _TelaImportacaoParceirosState();
}

enum StatusImportacao { inicial, carregando, sucesso, erro }

class _TelaImportacaoParceirosState extends State<TelaImportacaoParceiros> {
  StatusImportacao _status = StatusImportacao.inicial;
  String _mensagemStatus = 'Selecione uma empresa para começar.';

  FilePickerResult? _parceirosFile;
  FilePickerResult? _pagamentosFile;
  FilePickerResult? _recebimentosFile;

  List<Map<String, String>> _listaEmpresas = [];
  Map<String, String>? _empresaSelecionada;
  bool _carregandoEmpresas = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregarEmpresas());
  }

  Future<void> _carregarEmpresas() async {
    try {
      final lista =
      await context.read<UsuarioProvider>().buscarTodasEmpresas();
      if (mounted) {
        setState(() {
          _listaEmpresas = lista;
          _carregandoEmpresas = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mensagemStatus = 'Erro ao carregar empresas: $e';
          _status = StatusImportacao.erro;
          _carregandoEmpresas = false;
        });
      }
    }
  }

  Future<FilePickerResult?> _selecionarArquivo() async {
    try {
      return await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
    } catch (e) {
      setState(() {
        _status = StatusImportacao.erro;
        _mensagemStatus = 'Erro ao selecionar o arquivo: $e';
      });
      return null;
    }
  }

  Future<void> _iniciarImportacao() async {
    if (_empresaSelecionada == null || _empresaSelecionada!['id'] == null) {
      setState(() {
        _status = StatusImportacao.erro;
        _mensagemStatus = 'Por favor, selecione uma empresa válida.';
      });
      return;
    }
    if (_parceirosFile == null ||
        _pagamentosFile == null ||
        _recebimentosFile == null) {
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
      final provider = context.read<ParceiroProvider>();
      final String empresaId = _empresaSelecionada!['id']!;

      // 1. Lê os arquivos de transações e conta pagamentos/recebimentos por código
      setState(() => _mensagemStatus = 'Lendo arquivos de transações...');
      final Map<String, Map<String, int>> contagemTransacoes = {};

      for (final entry in [
        (_pagamentosFile!, 'pagamentos'),
        (_recebimentosFile!, 'recebimentos'),
      ]) {
        final conteudo = utf8.decode(entry.$1.files.first.bytes!);
        final delimitador =
        conteudo.split('\n').first.contains(';') ? ';' : ',';
        final linhas =
        CsvToListConverter(fieldDelimiter: delimitador).convert(conteudo);
        for (final linha in linhas) {
          if (linha.isEmpty) continue;
          final codigo = linha[0].toString().trim();
          if (codigo.isEmpty) continue;
          contagemTransacoes.putIfAbsent(
              codigo, () => {'pagamentos': 0, 'recebimentos': 0});
          contagemTransacoes[codigo]![entry.$2] =
              (contagemTransacoes[codigo]![entry.$2] ?? 0) + 1;
        }
      }

      // 2. Lê o arquivo de parceiros
      setState(() => _mensagemStatus = 'Lendo arquivo de parceiros...');
      final conteudoParc =
      utf8.decode(_parceirosFile!.files.first.bytes!);
      final delimitadorParc =
      conteudoParc.split('\n').first.contains(';') ? ';' : ',';
      final linhasParc =
      CsvToListConverter(fieldDelimiter: delimitadorParc)
          .convert(conteudoParc);

      if (linhasParc.length <= 1) {
        throw Exception(
            'Arquivo de parceiros está vazio ou contém apenas o cabeçalho.');
      }

      // 3. Busca duplicatas existentes no banco
      setState(() => _mensagemStatus = 'Validando dados...');
      final existentes =
      await provider.buscarCodigosECnpjsExistentes(empresaId);
      final codigosExistentes = existentes.codigos;
      final cnpjsExistentes = existentes.cnpjs;

      // 4. Monta lista de novos parceiros validando duplicatas
      final List<Map<String, dynamic>> parceirosParaAdicionar = [];
      final Set<String> codigosNoArquivo = {};
      final Set<String> cnpjsNoArquivo = {};

      for (int i = 1; i < linhasParc.length; i++) {
        final linha = linhasParc[i];
        if (linha.length < 4) continue;

        final codigo = linha[0].toString().trim();
        final nome = linha[1].toString().trim();
        final cnpj = linha[3]
            .toString()
            .trim()
            .replaceAll(RegExp(r'[^0-9]'), '');

        // Só importa parceiros que aparecem nas transações
        if (!contagemTransacoes.containsKey(codigo)) continue;

        if (codigosNoArquivo.contains(codigo)) {
          throw Exception('Código duplicado dentro do arquivo CSV: $codigo');
        }
        codigosNoArquivo.add(codigo);

        if (cnpj.isNotEmpty) {
          if (cnpjsNoArquivo.contains(cnpj)) {
            throw Exception(
                'CNPJ/CPF duplicado dentro do arquivo CSV: $cnpj');
          }
          cnpjsNoArquivo.add(cnpj);
        }

        if (codigosExistentes.contains(codigo)) {
          throw Exception('Código já existente no banco de dados: $codigo');
        }
        if (cnpj.isNotEmpty && cnpjsExistentes.contains(cnpj)) {
          throw Exception(
              'CNPJ/CPF já existente no banco de dados: $cnpj');
        }

        // Determina tipo pelo número de transações
        final contagens = contagemTransacoes[codigo]!;
        final tipo =
        (contagens['recebimentos']! >= contagens['pagamentos']!)
            ? 'cliente'
            : 'fornecedor';

        parceirosParaAdicionar.add({
          'empresaId': empresaId,
          'codigo': codigo,
          'nome': nome,
          'natureza': linha[2].toString().trim(),
          'cnpj': cnpj,
          'tipo': tipo,
        });
      }

      if (parceirosParaAdicionar.isEmpty) {
        throw Exception(
            'Nenhum parceiro novo e relevante encontrado para importar.');
      }

      // 5. Importa em batch
      setState(() =>
      _mensagemStatus =
      'Salvando ${parceirosParaAdicionar.length} parceiros...');
      final criados = await provider.importarLote(parceirosParaAdicionar);

      setState(() {
        _status = StatusImportacao.sucesso;
        _mensagemStatus = 'Importação Concluída!\n\n'
            '$criados parceiros cadastrados para: ${_empresaSelecionada!['nome']}.';
      });
    } catch (e) {
      setState(() {
        _status = StatusImportacao.erro;
        _mensagemStatus =
        'ERRO: ${e.toString().replaceAll("Exception: ", "")}';
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Seletor de empresa
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
                      child:
                      Text(empresa['nome'] ?? 'Empresa Desconhecida'),
                    );
                  }).toList(),
                  onChanged: (valor) => setState(() {
                    _empresaSelecionada = valor;
                    _mensagemStatus =
                    'Empresa selecionada. Agora selecione os arquivos.';
                    _parceirosFile = null;
                    _pagamentosFile = null;
                    _recebimentosFile = null;
                  }),
                  decoration:
                  const InputDecoration(border: OutlineInputBorder()),
                ),

              const SizedBox(height: 24),

              _buildFilePickerButton(
                label: '2. Selecionar Parceiros (.csv)',
                fileResult: _parceirosFile,
                onPressed: () async {
                  if (_empresaSelecionada == null) {
                    _snackEmpresa();
                    return;
                  }
                  final f = await _selecionarArquivo();
                  if (f != null) setState(() => _parceirosFile = f);
                },
              ),
              const SizedBox(height: 16),
              _buildFilePickerButton(
                label: '3. Selecionar Pagamentos (.csv)',
                fileResult: _pagamentosFile,
                onPressed: () async {
                  if (_empresaSelecionada == null) {
                    _snackEmpresa();
                    return;
                  }
                  final f = await _selecionarArquivo();
                  if (f != null) setState(() => _pagamentosFile = f);
                },
              ),
              const SizedBox(height: 16),
              _buildFilePickerButton(
                label: '4. Selecionar Recebimentos (.csv)',
                fileResult: _recebimentosFile,
                onPressed: () async {
                  if (_empresaSelecionada == null) {
                    _snackEmpresa();
                    return;
                  }
                  final f = await _selecionarArquivo();
                  if (f != null) setState(() => _recebimentosFile = f);
                },
              ),

              const SizedBox(height: 32),
              _buildWidgetDeStatus(),
              const SizedBox(height: 32),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade400,
                ),
                onPressed: (_parceirosFile != null &&
                    _pagamentosFile != null &&
                    _recebimentosFile != null &&
                    _status != StatusImportacao.carregando)
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

  void _snackEmpresa() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Selecione uma empresa primeiro.'),
      backgroundColor: Colors.orange,
    ));
  }

  Widget _buildFilePickerButton({
    required String label,
    required FilePickerResult? fileResult,
    required VoidCallback onPressed,
  }) {
    final isSelected = fileResult != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          icon: Icon(
            isSelected ? Icons.check_circle : Icons.folder_open,
            color: isSelected ? Colors.green : null,
          ),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            textStyle: const TextStyle(fontSize: 16),
          ),
          onPressed: _empresaSelecionada != null ? onPressed : null,
        ),
        if (isSelected)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              fileResult.files.first.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }

  Widget _buildWidgetDeStatus() {
    switch (_status) {
      case StatusImportacao.carregando:
        return Column(children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 10),
          Text(_mensagemStatus, textAlign: TextAlign.center),
        ]);
      case StatusImportacao.sucesso:
        return Text(_mensagemStatus,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16,
                color: Colors.green,
                fontWeight: FontWeight.bold));
      case StatusImportacao.erro:
        return Text(_mensagemStatus,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
                fontWeight: FontWeight.bold));
      case StatusImportacao.inicial:
        return Text(_mensagemStatus,
            textAlign: TextAlign.center,
            style:
            const TextStyle(fontSize: 16, color: Colors.grey));
    }
  }
}