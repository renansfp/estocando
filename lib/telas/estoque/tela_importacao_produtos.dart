// lib/telas/estoque/tela_importacao_produtos.dart
// Migrada para Repository Pattern — sem acesso direto ao Firestore.

import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/produto_provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';

class TelaImportacaoProdutos extends StatefulWidget {
  const TelaImportacaoProdutos({super.key});

  @override
  State<TelaImportacaoProdutos> createState() => _TelaImportacaoProdutosState();
}

enum _StatusImportacao { inicial, carregando, sucesso, erro }

class _TelaImportacaoProdutosState extends State<TelaImportacaoProdutos> {
  _StatusImportacao _status = _StatusImportacao.inicial;
  String _mensagemStatus = 'Selecione uma empresa para começar.';
  FilePickerResult? _resultadoPicker;

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
          _status = _StatusImportacao.erro;
          _carregandoEmpresas = false;
        });
      }
    }
  }

  Future<void> _selecionarArquivo() async {
    if (_empresaSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Por favor, selecione uma empresa primeiro.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    try {
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (resultado != null) {
        setState(() {
          _resultadoPicker = resultado;
          _mensagemStatus =
          'Arquivo selecionado: ${resultado.files.first.name}';
          _status = _StatusImportacao.inicial;
        });
      }
    } catch (e) {
      setState(() {
        _status = _StatusImportacao.erro;
        _mensagemStatus = 'Erro ao selecionar o arquivo: $e';
      });
    }
  }

  Future<void> _iniciarImportacao() async {
    if (_empresaSelecionada == null || _resultadoPicker == null) return;

    setState(() {
      _status = _StatusImportacao.carregando;
      _mensagemStatus = 'Verificando produtos existentes na empresa...';
    });

    try {
      final empresaId = _empresaSelecionada!['id']!;
      final produtoProvider = context.read<ProdutoProvider>();

      // 1. Busca códigos já cadastrados para evitar duplicatas
      final codigosExistentes =
      await produtoProvider.buscarCodigosExistentes(empresaId);

      setState(() => _mensagemStatus = 'Lendo arquivo CSV...');

      final bytes = _resultadoPicker!.files.first.bytes!;
      final conteudo = utf8.decode(bytes);

      final primeiraLinha = conteudo.split('\n').first;
      final delimitador =
      (primeiraLinha.split(';').length > primeiraLinha.split(',').length)
          ? ';'
          : ',';

      final List<List<dynamic>> linhas =
      CsvToListConverter(fieldDelimiter: delimitador).convert(conteudo);

      if (linhas.length <= 1) {
        throw Exception(
            'O arquivo CSV está vazio ou contém apenas o cabeçalho.');
      }

      // 2. Monta a lista de produtos novos (ignora códigos duplicados)
      final List<Map<String, dynamic>> novosProdutos = [];
      int produtosIgnorados = 0;

      for (int i = 1; i < linhas.length; i++) {
        final linha = linhas[i];
        if (linha.length < 8) continue;

        final codigo = linha[0].toString().trim();
        if (codigo.isEmpty || codigosExistentes.contains(codigo)) {
          produtosIgnorados++;
          continue;
        }

        novosProdutos.add({
          'empresaId': empresaId,
          'codigo': codigo,
          'nome': linha[1].toString().trim(),
          'valor':
          double.tryParse(linha[2].toString().replaceAll(',', '.')) ?? 0.0,
          'unidade': linha[3].toString().trim(),
          'tipo': linha[4].toString().trim(),
          'grupo': linha[5].toString().trim().toUpperCase(),
          'estoqueMinimo':
          double.tryParse(linha[6].toString().replaceAll(',', '.')) ?? 0.0,
          'estoqueMaximo':
          double.tryParse(linha[7].toString().replaceAll(',', '.')) ?? 0.0,
          'quantidadeAtual': 0.0,
          'ativo': true,
          'numeroSC': null,
        });
      }

      // 3. Importa em batch
      if (novosProdutos.isNotEmpty) {
        setState(() =>
        _mensagemStatus = 'Salvando ${novosProdutos.length} produtos...');
        final criados = await produtoProvider.importarLote(novosProdutos);
        setState(() {
          _status = _StatusImportacao.sucesso;
          _mensagemStatus = 'Importação Concluída!\n\n'
              '$criados produtos cadastrados para: ${_empresaSelecionada!['nome']}.\n'
              '$produtosIgnorados produtos ignorados (código duplicado ou vazio).';
        });
      } else {
        setState(() {
          _status = _StatusImportacao.sucesso;
          _mensagemStatus = 'Nenhum produto novo encontrado.\n'
              '$produtosIgnorados produtos ignorados (já cadastrados ou sem código).';
        });
      }
    } catch (e) {
      setState(() {
        _status = _StatusImportacao.erro;
        _mensagemStatus = 'ERRO: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar Produtos via CSV'),
        backgroundColor: Colors.teal,
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
                  hint: const Text('Selecione para qual empresa importar'),
                  isExpanded: true,
                  items: _listaEmpresas.map((empresa) {
                    return DropdownMenuItem<Map<String, String>>(
                      value: empresa,
                      child: Text(empresa['nome'] ?? 'Empresa Desconhecida'),
                    );
                  }).toList(),
                  onChanged: (valor) => setState(() {
                    _empresaSelecionada = valor;
                    _mensagemStatus =
                    'Empresa selecionada. Agora selecione o arquivo CSV.';
                    _resultadoPicker = null;
                  }),
                  decoration:
                  const InputDecoration(border: OutlineInputBorder()),
                ),

              const SizedBox(height: 24),

              ElevatedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('Selecionar Arquivo CSV'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                onPressed:
                _empresaSelecionada != null ? _selecionarArquivo : null,
              ),

              const SizedBox(height: 24),

              _buildWidgetDeStatus(),

              const SizedBox(height: 32),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: (_resultadoPicker != null &&
                    _status != _StatusImportacao.carregando)
                    ? _iniciarImportacao
                    : null,
                child: _status == _StatusImportacao.carregando
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
      case _StatusImportacao.carregando:
        return Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 10),
            Text(_mensagemStatus, textAlign: TextAlign.center),
          ],
        );
      case _StatusImportacao.sucesso:
        return Text(
          _mensagemStatus,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold),
        );
      case _StatusImportacao.erro:
        return Text(
          _mensagemStatus,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.red),
        );
      case _StatusImportacao.inicial:
        return Text(
          _mensagemStatus,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        );
    }
  }
}