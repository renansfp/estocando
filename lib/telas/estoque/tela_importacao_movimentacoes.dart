// lib/telas/estoque/tela_importacao_movimentacoes.dart
// Migrada para Repository Pattern — sem acesso direto ao Firestore.

import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/movimentacao_provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';

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
          _log = 'Erro ao carregar empresas: $e';
          _carregandoEmpresas = false;
        });
      }
    }
  }

  Future<void> _iniciarImportacao() async {
    if (_empresaSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Por favor, selecione uma empresa primeiro.'),
      ));
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (!mounted) return;
    if (result == null || result.files.single.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum arquivo selecionado.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _log = 'Lendo arquivo "${result.files.single.name}"...\n';
    });

    final csvString = utf8.decode(result.files.single.bytes!);
    final List<List<dynamic>> rows =
    const CsvToListConverter().convert(csvString);

    if (rows.length < 2) {
      setState(() {
        _isLoading = false;
        _log += 'ERRO: arquivo vazio ou com apenas o cabeçalho.\n';
      });
      return;
    }

    final headers =
    rows.first.map((h) => h.toString().toLowerCase().trim()).toList();
    final requiredHeaders = ['codigo', 'quantidade', 'tipo', 'data'];
    if (!requiredHeaders.every(headers.contains)) {
      setState(() {
        _isLoading = false;
        _log += 'ERRO: o cabeçalho deve conter: ${requiredHeaders.join(', ')}\n';
      });
      return;
    }

    final provider = context.read<MovimentacaoProvider>();
    final empresaId = _empresaSelecionada!['id']!;
    int sucessos = 0;
    final List<String> erros = [];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final linhaNum = i + 1;

      setState(() =>
      _log = 'Processando linha $linhaNum de ${rows.length - 1}...\n');

      try {
        final codigo =
        row[headers.indexOf('codigo')].toString().trim();
        final quantidadeStr = row[headers.indexOf('quantidade')]
            .toString()
            .replaceAll(',', '.')
            .trim();
        final tipo =
        row[headers.indexOf('tipo')].toString().trim().toLowerCase();
        final dataStr =
        row[headers.indexOf('data')].toString().trim();

        final destino = headers.contains('destino')
            ? row[headers.indexOf('destino')].toString().trim()
            : null;
        final valorUnitarioStr = headers.contains('valor_unitario')
            ? row[headers.indexOf('valor_unitario')]
            .toString()
            .replaceAll(',', '.')
            .trim()
            : null;
        final centroCusto = headers.contains('centro_custo')
            ? row[headers.indexOf('centro_custo')].toString().trim()
            : null;

        if (codigo.isEmpty) throw Exception('Código do produto está vazio.');
        if (tipo != 'entrada' && tipo != 'saida') {
          throw Exception('Tipo deve ser "entrada" ou "saida".');
        }

        final quantidade = double.tryParse(quantidadeStr);
        if (quantidade == null || quantidade <= 0) {
          throw Exception('Quantidade inválida ou zero.');
        }

        final data = DateFormat('dd/MM/yyyy').parse(dataStr);
        final valorUnitario =
        valorUnitarioStr != null ? double.tryParse(valorUnitarioStr) : null;

        await provider.importarMovimentacaoComEstoque(
          empresaId: empresaId,
          codigoProduto: codigo,
          tipo: tipo,
          quantidade: quantidade,
          data: data,
          destino: destino,
          valorUnitario: valorUnitario,
          centroCusto: centroCusto,
        );

        sucessos++;
      } catch (e) {
        erros.add(
            'Linha $linhaNum: ${e.toString().replaceAll("Exception: ", "")}');
      }
    }

    setState(() {
      _isLoading = false;
      _log = 'Importação para "${_empresaSelecionada!['nome']}" concluída!\n\n'
          'Resultados:\n'
          '- $sucessos movimentações importadas com sucesso.\n'
          '- ${erros.length} linhas com erro.\n\n'
          '${erros.isNotEmpty ? 'Detalhes dos erros:\n${erros.join('\n')}' : ''}';
    });
  }

  Future<void> _resetarDados() async {
    if (_empresaSelecionada == null) return;

    setState(() {
      _isLoading = true;
      _log =
      'Iniciando redefinição para "${_empresaSelecionada!['nome']}"...\n';
    });

    try {
      setState(() => _log += 'Apagando movimentações e zerando estoque...\n');

      await context
          .read<MovimentacaoProvider>()
          .resetarDadosEmpresa(_empresaSelecionada!['id']!);

      setState(() {
        _isLoading = false;
        _log += 'Redefinição concluída! Você já pode importar o novo arquivo.\n';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _log += 'ERRO DURANTE A REDEFINIÇÃO: $e\n';
      });
    }
  }

  void _mostrarDialogoReset() {
    if (_empresaSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecione uma empresa antes de redefinir os dados.'),
      ));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ ATENÇÃO: Ação Irreversível'),
        content: Text(
          'Apagar TODAS as movimentações e ZERAR o estoque de TODOS os produtos '
              'da empresa "${_empresaSelecionada!['nome']}"?\n\n'
              'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              _resetarDados();
            },
            child: const Text('Sim, apagar dados da empresa'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importar Movimentações')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Seletor de empresa
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
                onChanged: (valor) => setState(() {
                  _empresaSelecionada = valor;
                  _log = 'Empresa selecionada. Agora selecione o arquivo CSV.';
                }),
                decoration:
                const InputDecoration(border: OutlineInputBorder()),
              ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              icon: const Icon(Icons.file_upload),
              label: const Text('2. Selecionar e Importar CSV'),
              onPressed: (_isLoading || _empresaSelecionada == null)
                  ? null
                  : _iniciarImportacao,
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
                  ),
                )
                    : SingleChildScrollView(child: Text(_log)),
              ),
            ),

            const Divider(),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextButton.icon(
                icon: const Icon(Icons.warning_amber_rounded),
                label: const Text('Redefinir Dados da Empresa'),
                onPressed: (_isLoading || _empresaSelecionada == null)
                    ? null
                    : _mostrarDialogoReset,
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}