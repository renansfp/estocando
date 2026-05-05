// lib/telas/admin/tela_cadastro_parceiro.dart
// Migrada para Repository Pattern — sem acesso direto ao Firestore.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/models/parceiro.dart';
import 'package:protecin_producao/provider/parceiro_provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';

enum TipoDocumento { cpf, cnpj }

class TelaCadastroParceiro extends StatefulWidget {
  /// Map com os dados do parceiro a editar (inclui campo 'id').
  /// Null quando for um novo cadastro.
  final Map<String, dynamic>? parceiroParaEditar;

  const TelaCadastroParceiro({super.key, this.parceiroParaEditar});

  @override
  State<TelaCadastroParceiro> createState() => _TelaCadastroParceiroState();
}

class _TelaCadastroParceiroState extends State<TelaCadastroParceiro> {
  final _formKey = GlobalKey<FormState>();

  bool get _modoEdicao => widget.parceiroParaEditar != null;
  String? get _parceiroId => widget.parceiroParaEditar?['id'] as String?;

  // Controllers
  final _codigoController = TextEditingController();
  final _nomeController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _estadoController = TextEditingController();
  final _cepController = TextEditingController();

  TipoParceiro _tipoParceiro = TipoParceiro.cliente;
  TipoDocumento _tipoDocumento = TipoDocumento.cpf;
  bool _isSalvando = false;

  // Formatadores
  final _documentoFormatter = MaskTextInputFormatter(
      mask: '###.###.###-##', filter: {'#': RegExp(r'[0-9]')});
  final _telefoneFormatter = MaskTextInputFormatter(
      mask: '(##) #####-####', filter: {'#': RegExp(r'[0-9]')});
  final _cepFormatter = MaskTextInputFormatter(
      mask: '#####-###', filter: {'#': RegExp(r'[0-9]')});

  @override
  void initState() {
    super.initState();

    if (_modoEdicao) {
      final dados = widget.parceiroParaEditar!;
      _codigoController.text = dados['codigo'] ?? '';
      _nomeController.text = dados['nome'] ?? '';
      _tipoParceiro =
          TipoParceiro.values.byName(dados['tipo'] ?? 'cliente');

      if (dados['telefone'] != null) {
        _telefoneController.text =
            _telefoneFormatter.maskText(dados['telefone']);
      }
      if (dados['endereco'] != null) {
        _enderecoController.text = dados['endereco'];
      }
      if (dados['cidade'] != null) _cidadeController.text = dados['cidade'];
      if (dados['estado'] != null) _estadoController.text = dados['estado'];
      if (dados['cep'] != null) {
        _cepController.text = _cepFormatter.maskText(dados['cep']);
      }

      final cnpj = dados['cnpj'] ?? '';
      if (cnpj.isNotEmpty) {
        _tipoDocumento =
        cnpj.length > 11 ? TipoDocumento.cnpj : TipoDocumento.cpf;
        _documentoFormatter.updateMask(
            mask: _tipoDocumento == TipoDocumento.cnpj
                ? '##.###.###/####-##'
                : '###.###.###-##');
        _cnpjController.text = _documentoFormatter.maskText(cnpj);
      }
    }
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _nomeController.dispose();
    _cnpjController.dispose();
    _telefoneController.dispose();
    _enderecoController.dispose();
    _cidadeController.dispose();
    _estadoController.dispose();
    _cepController.dispose();
    super.dispose();
  }

  Future<void> _salvarParceiro() async {
    if (!_formKey.currentState!.validate() || _isSalvando) return;

    final usuario = context.read<UsuarioProvider>().usuario;
    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Erro: empresa não identificada.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isSalvando = true);

    try {
      final provider = context.read<ParceiroProvider>();
      final codigo = _codigoController.text.trim();
      final empresaId = usuario.empresaId;

      // Verifica código duplicado
      final duplicado = await provider.verificarCodigoDuplicado(
        empresaId,
        codigo,
        excludeId: _parceiroId,
      );

      if (duplicado) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Erro: código já existe.'),
            backgroundColor: Colors.red,
          ));
        }
        return;
      }

      final dados = {
        'empresaId': empresaId,
        'codigo': codigo,
        'nome': _nomeController.text.trim().toUpperCase(),
        'tipo': _tipoParceiro.name,
        'cnpj': _documentoFormatter.unmaskText(_cnpjController.text),
        'telefone': _telefoneFormatter.unmaskText(_telefoneController.text),
        'endereco': _enderecoController.text.trim(),
        'cidade': _cidadeController.text.trim(),
        'estado': _estadoController.text.trim(),
        'cep': _cepFormatter.unmaskText(_cepController.text),
      };

      if (_modoEdicao) {
        await provider.atualizar(_parceiroId!, dados);
      } else {
        await provider.criar(dados);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Salvo com sucesso!'),
          backgroundColor: Colors.green,
        ));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSalvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_modoEdicao ? 'Editar Parceiro' : 'Novo Parceiro')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Dados Básicos ──────────────────────────────────────────
              const Text('Dados Básicos',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _codigoController,
                      decoration: const InputDecoration(
                          labelText: 'Código',
                          border: OutlineInputBorder()),
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(7)
                      ],
                      validator: (t) =>
                      (t == null || t.trim().isEmpty)
                          ? 'Obrigatório'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _nomeController,
                      decoration: const InputDecoration(
                          labelText: 'Nome / Razão Social',
                          border: OutlineInputBorder()),
                      validator: (t) =>
                      (t == null || t.trim().isEmpty)
                          ? 'Obrigatório'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              RadioGroup<TipoParceiro>(
                groupValue: _tipoParceiro,
                onChanged: (v) => setState(() => _tipoParceiro = v!),
                child: Row(children: [
                  Expanded(
                    child: RadioListTile<TipoParceiro>(
                      title: const Text('Cliente'),
                      value: TipoParceiro.cliente,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<TipoParceiro>(
                      title: const Text('Fornecedor'),
                      value: TipoParceiro.fornecedor,
                    ),
                  ),
                ]),
              ),

              // ── Documento ──────────────────────────────────────────────
              RadioGroup<TipoDocumento>(
                groupValue: _tipoDocumento,
                onChanged: (v) => setState(() {
                  _tipoDocumento = v!;
                  _documentoFormatter.updateMask(
                    mask: v == TipoDocumento.cnpj
                        ? '##.###.###/####-##'
                        : '###.###.###-##',
                  );
                  _cnpjController.clear();
                }),
                child: Row(children: [
                  Expanded(
                    child: RadioListTile<TipoDocumento>(
                      dense: true,
                      title: const Text('CPF'),
                      value: TipoDocumento.cpf,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<TipoDocumento>(
                      dense: true,
                      title: const Text('CNPJ'),
                      value: TipoDocumento.cnpj,
                    ),
                  ),
                ]),
              ),
              TextFormField(
                controller: _cnpjController,
                decoration: InputDecoration(
                    labelText: _tipoDocumento == TipoDocumento.cpf
                        ? 'CPF'
                        : 'CNPJ',
                    border: const OutlineInputBorder()),
                keyboardType: TextInputType.number,
                inputFormatters: [_documentoFormatter],
              ),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),

              // ── Endereço e Contato ─────────────────────────────────────
              const Text('Endereço e Contato',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(
                    labelText: 'Telefone / Whatsapp',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone)),
                keyboardType: TextInputType.phone,
                inputFormatters: [_telefoneFormatter],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _cepController,
                decoration: const InputDecoration(
                    labelText: 'CEP',
                    border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                inputFormatters: [_cepFormatter],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _enderecoController,
                decoration: const InputDecoration(
                    labelText: 'Endereço (Rua, Nº, Bairro)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _cidadeController,
                      decoration: const InputDecoration(
                          labelText: 'Cidade',
                          border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _estadoController,
                      decoration: const InputDecoration(
                          labelText: 'UF',
                          border: OutlineInputBorder()),
                      maxLength: 2,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSalvando ? null : _salvarParceiro,
                  child: _isSalvando
                      ? const CircularProgressIndicator(
                      color: Colors.white)
                      : const Text('SALVAR DADOS'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}