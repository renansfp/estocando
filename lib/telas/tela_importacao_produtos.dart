// CÓDIGO COMPLETO E SEGURO COM LÓGICA DE MULTI-EMPRESA

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
  String _mensagemStatus = 'Selecione uma empresa para começar.';
  FilePickerResult? _resultadoPicker;

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
        // Usaremos o nome do primeiro usuário encontrado como "nome" da empresa para exibição.
        final nomeEmpresa = data['nome'] as String?;

        if (empresaId != null && nomeEmpresa != null) {
          // Adiciona ao mapa para evitar duplicatas, associando ID ao nome.
          empresasMap.putIfAbsent(empresaId, () => nomeEmpresa);
        }
      }

      final

      listaFormatada = empresasMap.entries.map((entry) {
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

  Future<void> _selecionarArquivo() async {
    if (_empresaSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecione uma empresa primeiro.'), backgroundColor: Colors.orange));
      return;
    }
    try {
      final resultado = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'], withData: true);
      if (resultado != null) {
        setState(() {
          _resultadoPicker = resultado;
          _mensagemStatus = 'Arquivo selecionado: ${resultado.files.first.name}';
          _status = StatusImportacao.inicial;
        });
      }
    } catch (e) {
      setState(() {
        _status = StatusImportacao.erro;
        _mensagemStatus = 'Erro ao selecionar o arquivo: $e';
      });
    }
  }

  Future<void> _iniciarImportacao() async {
    // ---> MUDANÇA 4: Verificação de segurança para garantir que uma empresa foi selecionada.
    if (_empresaSelecionada == null || _empresaSelecionada!['id'] == null) {
      setState(() { _status = StatusImportacao.erro; _mensagemStatus = 'Por favor, selecione uma empresa válida.'; });
      return;
    }

    if (_resultadoPicker == null) {
      setState(() { _status = StatusImportacao.erro; _mensagemStatus = 'Por favor, selecione um arquivo primeiro.'; });
      return;
    }

    setState(() { _status = StatusImportacao.carregando; _mensagemStatus = 'Iniciando importação...'; });

    try {
      setState(() { _mensagemStatus = 'Verificando produtos existentes na empresa...'; });
      final db = FirebaseFirestore.instance;

      // ---> MUDANÇA 5: A verificação de duplicidade agora é segura e filtra por empresa.
      final produtosSnapshot = await db.collection('produtos')
          .where('empresaId', isEqualTo: _empresaSelecionada!['id'])
          .get();
      final codigosExistentes = produtosSnapshot.docs.map((doc) => doc['codigo'] as String).toSet();

      setState(() { _mensagemStatus = 'Lendo arquivo CSV...'; });
      final bytes = _resultadoPicker!.files.first.bytes!;
      final conteudoArquivo = utf8.decode(bytes);

      final primeiraLinha = conteudoArquivo.split('\n').first;
      final String delimitador = (primeiraLinha.split(';').length > primeiraLinha.split(',').length) ? ';' : ',';

      final List<List<dynamic>> linhas = CsvToListConverter(fieldDelimiter: delimitador).convert(conteudoArquivo);

      if (linhas.length <= 1) throw Exception("O arquivo CSV está vazio ou contém apenas o cabeçalho.");

      final batch = db.batch();
      int produtosNovos = 0;
      int produtosIgnorados = 0;

      for (int i = 1; i < linhas.length; i++) {
        final linha = linhas[i];
        if (linha.length < 8) continue;

        final codigo = linha[0].toString().trim();
        if (codigosExistentes.contains(codigo) || codigo.isEmpty) {
          produtosIgnorados++;
          continue;
        }

        final novoProdutoRef = db.collection('produtos').doc();
        batch.set(novoProdutoRef, {
          // ---> MUDANÇA 6: "Carimbamos" o novo produto com o ID da empresa selecionada.
          'empresaId': _empresaSelecionada!['id'],
          'codigo': codigo,
          'nome': linha[1].toString().trim(),
          'valor': double.tryParse(linha[2].toString().replaceAll(',', '.')) ?? 0.0,
          'unidade': linha[3].toString().trim(),
          'tipo': linha[4].toString().trim(),
          'grupo': linha[5].toString().trim().toUpperCase(),
          'estoqueMinimo': double.tryParse(linha[6].toString().replaceAll(',', '.')) ?? 0.0,
          'estoqueMaximo': double.tryParse(linha[7].toString().replaceAll(',', '.')) ?? 0.0,
          'quantidadeAtual': 0.0,
          'ativo': true, // Por padrão, produtos importados são ativos.
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
        _mensagemStatus = 'Importação Concluída!\n\n$produtosNovos produtos cadastrados para a empresa: ${_empresaSelecionada!['nome']}.\n$produtosIgnorados produtos ignorados (código duplicado ou vazio).';
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
              // ---> MUDANÇA 7: Novo Dropdown para selecionar a empresa.
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
                  onChanged: (valor) {
                    setState(() {
                      _empresaSelecionada = valor;
                      _mensagemStatus = 'Empresa selecionada. Agora selecione o arquivo CSV.';
                      _resultadoPicker = null; // Reseta a seleção de arquivo
                    });
                  },
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),

              const SizedBox(height: 24),

              ElevatedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('Selecionar Arquivo CSV'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                  // O botão só fica ativo depois de selecionar uma empresa.
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                onPressed: _empresaSelecionada != null ? _selecionarArquivo : null,
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