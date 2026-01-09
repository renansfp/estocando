// Salve como: lib/telas/cadastros/tela_cadastro_parceiro.dart
// (VERSÃO CORRIGIDA v13.1 - Com Enum TipoDocumento)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter/services.dart';
import 'package:protecin_producao/models/parceiro.dart';
// Se você tiver um arquivo de validadores, mantenha o import.
// Caso não tenha, remova a linha abaixo e a validação dentro do código.
import '../../utils/validadores.dart';

// --- AQUI ESTAVA FALTANDO ESTE ENUM ---
enum TipoDocumento { cpf, cnpj }
// --------------------------------------

class TelaCadastroParceiro extends StatefulWidget {
  final QueryDocumentSnapshot? parceiroParaEditar;
  const TelaCadastroParceiro({super.key, this.parceiroParaEditar});
  @override
  State<TelaCadastroParceiro> createState() => _TelaCadastroParceiroState();
}

class _TelaCadastroParceiroState extends State<TelaCadastroParceiro> {
  final _formKey = GlobalKey<FormState>();

  String? _empresaId;
  bool _carregandoDadosIniciais = true;

  // Controllers
  final _codigoController = TextEditingController();
  final _nomeController = TextEditingController();
  final _cnpjController = TextEditingController();

  // Novos Controllers de Endereço
  final _telefoneController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _estadoController = TextEditingController();
  final _cepController = TextEditingController();

  TipoParceiro _tipoParceiro = TipoParceiro.cliente;
  TipoDocumento _tipoDocumento = TipoDocumento.cpf;
  bool _isSalvando = false;

  bool get _modoEdicao => widget.parceiroParaEditar != null;

  // Formatadores
  final _documentoFormatter = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});
  final _telefoneFormatter = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  final _cepFormatter = MaskTextInputFormatter(mask: '#####-###', filter: {"#": RegExp(r'[0-9]')});

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();

    if (_modoEdicao) {
      final dados = widget.parceiroParaEditar!.data() as Map<String, dynamic>;
      _codigoController.text = dados['codigo'] ?? '';
      _nomeController.text = dados['nome'] ?? '';
      _tipoParceiro = TipoParceiro.values.byName(dados['tipo'] ?? 'cliente');

      // Preencher novos campos (com verificação de nulo)
      if (dados['telefone'] != null) _telefoneController.text = _telefoneFormatter.maskText(dados['telefone']);
      if (dados['endereco'] != null) _enderecoController.text = dados['endereco'];
      if (dados['cidade'] != null) _cidadeController.text = dados['cidade'];
      if (dados['estado'] != null) _estadoController.text = dados['estado'];
      if (dados['cep'] != null) _cepController.text = _cepFormatter.maskText(dados['cep']);

      final cnpj = dados['cnpj'] ?? '';
      if (cnpj.isNotEmpty) {
        _tipoDocumento = cnpj.length > 14 ? TipoDocumento.cnpj : TipoDocumento.cpf;
        _documentoFormatter.updateMask(mask: _tipoDocumento == TipoDocumento.cnpj ? '##.###.###/####-##' : '###.###.###-##');
        _cnpjController.text = _documentoFormatter.maskText(cnpj);
      }
    }
  }

  Future<void> _carregarDadosIniciais() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (mounted && userDoc.exists) {
        setState(() {
          _empresaId = (userDoc.data() as Map<String, dynamic>)['empresaId'];
          _carregandoDadosIniciais = false;
        });
      }
    } else {
      setState(() { _carregandoDadosIniciais = false; });
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

  void _salvarParceiro() async {
    if (_empresaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro: Empresa não identificada.'), backgroundColor: Colors.red));
      return;
    }

    if (_formKey.currentState!.validate() && !_isSalvando) {
      setState(() { _isSalvando = true; });

      final db = FirebaseFirestore.instance;
      final codigo = _codigoController.text.trim();
      final cnpjLimpo = _documentoFormatter.unmaskText(_cnpjController.text);
      final telefoneLimpo = _telefoneFormatter.unmaskText(_telefoneController.text);
      final cepLimpo = _cepFormatter.unmaskText(_cepController.text);

      try {
        // Verifica duplicidade de código
        final query = await db.collection('parceiros')
            .where('empresaId', isEqualTo: _empresaId)
            .where('codigo', isEqualTo: codigo)
            .get();

        if (query.docs.isNotEmpty) {
          if (!_modoEdicao || (_modoEdicao && query.docs.first.id != widget.parceiroParaEditar!.id)) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro: Código já existe.'), backgroundColor: Colors.red));
            setState(() { _isSalvando = false; });
            return;
          }
        }

        final dadosParceiro = {
          'empresaId': _empresaId,
          'codigo': codigo,
          'nome': _nomeController.text.trim().toUpperCase(),
          'tipo': _tipoParceiro.name,
          'cnpj': cnpjLimpo,
          'telefone': telefoneLimpo,
          'endereco': _enderecoController.text.trim(),
          'cidade': _cidadeController.text.trim(),
          'estado': _estadoController.text.trim(),
          'cep': cepLimpo,
          'timestamp': FieldValue.serverTimestamp(),
        };

        if (_modoEdicao) {
          await db.collection('parceiros').doc(widget.parceiroParaEditar!.id).update(dadosParceiro);
        } else {
          await db.collection('parceiros').add(dadosParceiro);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo com sucesso!'), backgroundColor: Colors.green));
          Navigator.of(context).pop();
        }

      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
        }
      } finally {
        if(mounted) setState(() { _isSalvando = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_modoEdicao ? 'Editar Parceiro' : 'Novo Parceiro')),
      body: _carregandoDadosIniciais
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- DADOS BÁSICOS ---
              const Text('Dados Básicos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _codigoController,
                      decoration: const InputDecoration(labelText: 'Código', border: OutlineInputBorder()),
                      inputFormatters: [LengthLimitingTextInputFormatter(7)],
                      validator: (t) => (t == null || t.trim().isEmpty) ? 'Obrigatório' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _nomeController,
                      decoration: const InputDecoration(labelText: 'Nome / Razão Social', border: OutlineInputBorder()),
                      validator: (t) => (t == null || t.trim().isEmpty) ? 'Obrigatório' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: RadioListTile<TipoParceiro>(title: const Text('Cliente'), value: TipoParceiro.cliente, groupValue: _tipoParceiro, onChanged: (v) => setState(() => _tipoParceiro = v!))),
                Expanded(child: RadioListTile<TipoParceiro>(title: const Text('Fornecedor'), value: TipoParceiro.fornecedor, groupValue: _tipoParceiro, onChanged: (v) => setState(() => _tipoParceiro = v!)))
              ]),

              // --- DOCUMENTO ---
              Row(children: [
                Expanded(child: RadioListTile<TipoDocumento>(dense: true, title: const Text('CPF'), value: TipoDocumento.cpf, groupValue: _tipoDocumento, onChanged: (v) {setState(() { _tipoDocumento = v!; _documentoFormatter.updateMask(mask: '###.###.###-##'); _cnpjController.clear(); });})),
                Expanded(child: RadioListTile<TipoDocumento>(dense: true, title: const Text('CNPJ'), value: TipoDocumento.cnpj, groupValue: _tipoDocumento, onChanged: (v) { setState(() { _tipoDocumento = v!; _documentoFormatter.updateMask(mask: '##.###.###/####-##'); _cnpjController.clear(); });}))
              ]),
              TextFormField(
                controller: _cnpjController,
                decoration: InputDecoration(labelText: _tipoDocumento == TipoDocumento.cpf ? 'CPF' : 'CNPJ', border: const OutlineInputBorder()),
                keyboardType: TextInputType.number,
                inputFormatters: [_documentoFormatter],
              ),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),

              // --- ENDEREÇO E CONTATO ---
              const Text('Endereço e Contato', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 10),

              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(labelText: 'Telefone / Whatsapp', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                keyboardType: TextInputType.phone,
                inputFormatters: [_telefoneFormatter],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _cepController,
                decoration: const InputDecoration(labelText: 'CEP', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                inputFormatters: [_cepFormatter],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _enderecoController,
                decoration: const InputDecoration(labelText: 'Endereço (Rua, Nº, Bairro)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _cidadeController,
                      decoration: const InputDecoration(labelText: 'Cidade', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _estadoController,
                      decoration: const InputDecoration(labelText: 'UF', border: OutlineInputBorder()),
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
                    child: _isSalvando ? const CircularProgressIndicator(color: Colors.white) : const Text('SALVAR DADOS')
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}