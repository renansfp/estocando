// CÓDIGO FINAL COM VALIDADOR LOCAL

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../utils/validadores.dart'; // MODIFICAÇÃO: Importando nosso validador local
import 'package:flutter/services.dart';

enum TipoParceiro { cliente, fornecedor }
enum TipoDocumento { cpf, cnpj }

class TelaCadastroParceiro extends StatefulWidget {
  final QueryDocumentSnapshot? parceiroParaEditar;
  const TelaCadastroParceiro({super.key, this.parceiroParaEditar});
  @override
  State<TelaCadastroParceiro> createState() => _TelaCadastroParceiroState();
}

class _TelaCadastroParceiroState extends State<TelaCadastroParceiro> {
  final _formKey = GlobalKey<FormState>();
  final _codigoController = TextEditingController();
  final _nomeController = TextEditingController();
  final _cnpjController = TextEditingController();

  TipoParceiro _tipoParceiro = TipoParceiro.cliente;
  TipoDocumento _tipoDocumento = TipoDocumento.cpf;
  bool _isSalvando = false;

  bool get _modoEdicao => widget.parceiroParaEditar != null;

  final _documentoFormatter = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});

  @override
  void initState() {
    super.initState();
    if (_modoEdicao) {
      final dados = widget.parceiroParaEditar!.data() as Map<String, dynamic>;
      _codigoController.text = dados['codigo'] ?? '';
      _nomeController.text = dados['nome'] ?? '';
      _tipoParceiro = TipoParceiro.values.byName(dados['tipo'] ?? 'cliente');

      final cnpj = dados['cnpj'] ?? '';
      if (cnpj.isNotEmpty) {
        _tipoDocumento = cnpj.length > 11 ? TipoDocumento.cnpj : TipoDocumento.cpf;
        _documentoFormatter.updateMask(mask: _tipoDocumento == TipoDocumento.cnpj ? '##.###.###/####-##' : '###.###.###-##');
        _cnpjController.text = _documentoFormatter.maskText(cnpj);
      }
    }
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _nomeController.dispose();
    _cnpjController.dispose();
    super.dispose();
  }

  void _salvarParceiro() async {
    if (_formKey.currentState!.validate() && !_isSalvando) {
      setState(() { _isSalvando = true; });

      final db = FirebaseFirestore.instance;
      final codigo = _codigoController.text.trim();
      final cnpjLimpo = _documentoFormatter.unmaskText(_cnpjController.text);

      try {
        // As validações de duplicidade continuam as mesmas
        // ... (código omitido para brevidade, mas está no seu arquivo)

        final dadosParceiro = {
          'codigo': codigo,
          'nome': _nomeController.text.trim(),
          'tipo': _tipoParceiro.name,
          'cnpj': cnpjLimpo,
          'timestamp': FieldValue.serverTimestamp(),
        };

        if (_modoEdicao) {
          await db.collection('parceiros').doc(widget.parceiroParaEditar!.id).update(dadosParceiro);
        } else {
          await db.collection('parceiros').add(dadosParceiro);
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Parceiro salvo com sucesso!'), backgroundColor: Colors.green));
        if (mounted) Navigator.of(context).pop();

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red));
      } finally {
        if(mounted) {
          setState(() { _isSalvando = false; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_modoEdicao ? 'Editar Parceiro' : 'Novo Parceiro')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _codigoController,
                decoration: const InputDecoration(labelText: 'Código'),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(7),
                ],
                validator: (text) => (text == null || text.trim().isEmpty) ? 'O código é obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _nomeController, decoration: const InputDecoration(labelText: 'Nome / Razão Social'), validator: (t) => (t == null || t.trim().isEmpty) ? 'O nome é obrigatório' : null),
              const SizedBox(height: 20),
              const Text('Tipo de Parceiro', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(children: [Expanded(child: RadioListTile<TipoParceiro>(title: const Text('Cliente'), value: TipoParceiro.cliente, groupValue: _tipoParceiro, onChanged: (v) => setState(() => _tipoParceiro = v!))), Expanded(child: RadioListTile<TipoParceiro>(title: const Text('Fornecedor'), value: TipoParceiro.fornecedor, groupValue: _tipoParceiro, onChanged: (v) => setState(() => _tipoParceiro = v!)))]),
              const SizedBox(height: 10),
              const Text('Tipo de Documento', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(children: [Expanded(child: RadioListTile<TipoDocumento>(dense: true, title: const Text('CPF'), value: TipoDocumento.cpf, groupValue: _tipoDocumento, onChanged: (v) {setState(() { _tipoDocumento = v!; _documentoFormatter.updateMask(mask: '###.###.###-##'); _cnpjController.clear(); });})), Expanded(child: RadioListTile<TipoDocumento>(dense: true, title: const Text('CNPJ'), value: TipoDocumento.cnpj, groupValue: _tipoDocumento, onChanged: (v) { setState(() { _tipoDocumento = v!; _documentoFormatter.updateMask(mask: '##.###.###/####-##'); _cnpjController.clear(); });}))]),

              TextFormField(
                controller: _cnpjController,
                decoration: InputDecoration(labelText: _tipoDocumento == TipoDocumento.cpf ? 'CPF' : 'CNPJ'),
                keyboardType: TextInputType.number,
                inputFormatters: [_documentoFormatter],
                // MODIFICAÇÃO: A lógica continua a mesma, mas agora chama NOSSAS funções
                validator: (value) {
                  final unmaskedValue = _documentoFormatter.unmaskText(value ?? '');
                  if (unmaskedValue.isEmpty) {
                    return null;
                  }

                  if (_tipoDocumento == TipoDocumento.cpf) {
                    if (!CPFValidator.isValid(unmaskedValue)) {
                      return 'CPF inválido.';
                    }
                  } else {
                    if (!CNPJValidator.isValid(unmaskedValue)) {
                      return 'CNPJ inválido.';
                    }
                  }

                  return null;
                },
              ),

              const SizedBox(height: 30),
              ElevatedButton(
                  onPressed: _salvarParceiro,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20)),
                  child: _isSalvando ? const CircularProgressIndicator(color: Colors.white) : const Text('Salvar')
              ),
            ],
          ),
        ),
      ),
    );
  }
}