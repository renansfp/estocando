// CÓDIGO COMPLETO E CORRETO PARA TELA DE CADASTRO DE PARCEIRO

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

enum TipoParceiro { cliente, fornecedor }
enum TipoDocumento { cpf, cnpj }
// O enum TipoTelefone foi removido pois não é mais necessário

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
  // Controllers de telefone e endereço removidos

  TipoParceiro _tipoParceiro = TipoParceiro.cliente;
  TipoDocumento _tipoDocumento = TipoDocumento.cpf;
  // Variável _tipoTelefone removida
  bool _isSalvando = false;

  bool get _modoEdicao => widget.parceiroParaEditar != null;

  final _documentoFormatter = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});
  // Formatter de telefone removido

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
        _tipoDocumento = cnpj.length > 14 ? TipoDocumento.cnpj : TipoDocumento.cpf; // Ajustado para o tamanho real do CNPJ com máscara
        _documentoFormatter.updateMask(mask: _tipoDocumento == TipoDocumento.cnpj ? '##.###.###/####-##' : '###.###.###-##');
        _cnpjController.text = _documentoFormatter.maskText(cnpj);
      }
      // Lógica de telefone e endereço removida do initState
    }
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _nomeController.dispose();
    _cnpjController.dispose();
    // Controllers de telefone e endereço removidos do dispose
    super.dispose();
  }

  void _salvarParceiro() async {
    if (_formKey.currentState!.validate() && !_isSalvando) {
      setState(() { _isSalvando = true; });

      final db = FirebaseFirestore.instance;
      final codigo = _codigoController.text.trim();
      final cnpjLimpo = _documentoFormatter.unmaskText(_cnpjController.text);

      try {
        var queryCodigo = await db.collection('parceiros').where('codigo', isEqualTo: codigo).get();
        if (queryCodigo.docs.isNotEmpty) {
          if (!_modoEdicao || (_modoEdicao && queryCodigo.docs.first.id != widget.parceiroParaEditar!.id)) {
            throw Exception('Este código de parceiro já está em uso.');
          }
        }

        if (cnpjLimpo.isNotEmpty) {
          var queryCnpj = await db.collection('parceiros').where('cnpj', isEqualTo: cnpjLimpo).where('tipo', isEqualTo: _tipoParceiro.name).get();
          if (queryCnpj.docs.isNotEmpty) {
            if (!_modoEdicao || (_modoEdicao && queryCnpj.docs.first.id != widget.parceiroParaEditar!.id)) {
              throw Exception('Já existe um parceiro deste tipo com este CNPJ/CPF.');
            }
          }
        }

        // Mapa de dados simplificado, sem telefone e endereço
        final dadosParceiro = {
          'codigo': codigo,
          'nome': _nomeController.text.trim(),
          'tipo': _tipoParceiro.name,
          'cnpj': cnpjLimpo,
          'timestamp': FieldValue.serverTimestamp(),
        };

        if (_modoEdicao) {
          await db.collection('parceiros').doc(widget.parceiroParaEditar!.id).update(dadosParceiro);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parceiro atualizado!'), backgroundColor: Colors.blue));
        } else {
          await db.collection('parceiros').add(dadosParceiro);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parceiro salvo com sucesso!'), backgroundColor: Colors.green));
        }

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
      appBar: AppBar(title: Text(_modoEdicao ? 'Editar Parceiro' : 'Novo Parceiro'), backgroundColor: const Color.fromRGBO(17, 52, 82, 1)), // Usando a cor da marca
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
              TextFormField(controller: _cnpjController, decoration: InputDecoration(labelText: _tipoDocumento == TipoDocumento.cpf ? 'CPF' : 'CNPJ'), keyboardType: TextInputType.number, inputFormatters: [_documentoFormatter]),

              // SEÇÃO DE TELEFONE E ENDEREÇO REMOVIDA

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