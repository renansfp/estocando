// Salve como: lib/telas/producao/tela_cadastro_equipamento.dart
// (VERSÃO v13.0 - COMPLETA: Lógica de Alerta + Campos de Data/Origem)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:protecin_producao/models/equipamento.dart';
import 'package:protecin_producao/models/parceiro.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/widgets/autocomplete_parceiro.dart';
import 'package:protecin_producao/models/dados_tecnicos.dart';
import 'package:provider/provider.dart';

class TelaCadastroEquipamento extends StatefulWidget {
  final Parceiro? clientePreSelecionado;
  final String? numeroCascoPreenchido;
  final Equipamento? equipamentoParaEditar;

  const TelaCadastroEquipamento({
    super.key,
    this.clientePreSelecionado,
    this.numeroCascoPreenchido,
    this.equipamentoParaEditar,
  });

  @override
  State<TelaCadastroEquipamento> createState() => _TelaCadastroEquipamentoState();
}

class _TelaCadastroEquipamentoState extends State<TelaCadastroEquipamento> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // --- CONTROLLERS ---
  final _cilindroController = TextEditingController();
  final _ativoFixoController = TextEditingController();
  final _fabricanteController = TextEditingController();
  final _pinturaController = TextEditingController();

  // Dados Técnicos
  final _projetoController = TextEditingController();
  final _capExtintoraController = TextEditingController();
  final _normaController = TextEditingController();
  final _pressaoController = TextEditingController();

  // Datas
  final _anoFabController = TextEditingController();
  final _ultimoTHController = TextEditingController();
  final _ultimaRecargaController = TextEditingController();
  final _ultimaTrocaPoController = TextEditingController(); // IMPORTANTE

  // Pó Químico
  final _lotePoController = TextEditingController();
  bool _substituirPo = false;
  int _statusAlertaPo = 0; // 0=Verde, 1=Amarelo, 2=Vermelho

  // Opções: 'FABRICA', 'NOSSA', 'TERCEIROS'
  String _origemSelo = 'TERCEIROS';

  // --- MÁSCARAS ---
  final _dataMask = MaskTextInputFormatter(mask: '##/####', filter: {"#": RegExp(r'[0-9]')});
  final _loteMask = MaskTextInputFormatter(mask: '######', filter: {"#": RegExp(r'[0-9]')});

  // Estado
  Parceiro? _clienteSelecionado;
  String? _fabricanteSelecionado;
  String? _tipoSelecionado;
  String? _cargaSelecionada;

  List<String> _listaFabricantes = [];
  List<String> _listaTiposDisponiveis = [];
  List<String> _listaCargasDisponiveis = [];

  @override
  void initState() {
    super.initState();
    _carregarListasIniciais();
    _carregarDadosEdicaoOuNovo();

    _anoFabController.addListener(_tentarAtualizarNormaPeloAno);

    // Listeners para a lógica do pó
    _anoFabController.addListener(_calcularNecessidadeTrocaPo);
    _ultimaTrocaPoController.addListener(_calcularNecessidadeTrocaPo);
  }

  @override
  void dispose() {
    _anoFabController.removeListener(_tentarAtualizarNormaPeloAno);
    _anoFabController.removeListener(_calcularNecessidadeTrocaPo);
    _ultimaTrocaPoController.removeListener(_calcularNecessidadeTrocaPo);

    _cilindroController.dispose();
    _ativoFixoController.dispose();
    _fabricanteController.dispose();
    _pinturaController.dispose();
    _projetoController.dispose();
    _capExtintoraController.dispose();
    _normaController.dispose();
    _pressaoController.dispose();
    _anoFabController.dispose();
    _ultimoTHController.dispose();
    _ultimaRecargaController.dispose();
    _ultimaTrocaPoController.dispose();
    _lotePoController.dispose();
    super.dispose();
  }

  // --- O CÉREBRO DA REGRA DE PÓ (Sinal Verde/Amarelo/Vermelho) ---
  void _calcularNecessidadeTrocaPo() {
    if (!_isTipoPo()) return;

    bool deveTrocar = false;
    int nivelAlerta = 0; // 0=Verde, 1=Amarelo, 2=Vermelho
    final anoAtual = DateTime.now().year;

    // REGRA 1: Se veio de TERCEIROS, a troca é OBRIGATÓRIA
    if (_origemSelo == 'TERCEIROS') {
      deveTrocar = true;
      nivelAlerta = 2; // Vermelho
    }
    // REGRA 2: Se é NOSSO ou FÁBRICA
    else {
      int? anoReferenciaPo;
      try {
        if (_origemSelo == 'FABRICA') {
          if (_anoFabController.text.length >= 7) {
            anoReferenciaPo = int.parse(_anoFabController.text.split('/').last);
          }
        } else {
          // Origem NOSSA
          if (_ultimaTrocaPoController.text.length >= 7) {
            anoReferenciaPo = int.parse(_ultimaTrocaPoController.text.split('/').last);
          } else if (_anoFabController.text.length >= 7) {
            // Se nunca trocou, considera a fabricação
            anoReferenciaPo = int.parse(_anoFabController.text.split('/').last);
          }
        }
      } catch (e) {}

      if (anoReferenciaPo != null) {
        int idadePo = anoAtual - anoReferenciaPo;

        if (idadePo >= 5) {
          // VENCEU (5 anos ou mais) -> TROCA
          deveTrocar = true;
          nivelAlerta = 2; // Vermelho
        } else if (idadePo == 4) {
          // QUASE VENCENDO (4 anos) -> ATENÇÃO (Mas permite reutilizar)
          deveTrocar = false;
          nivelAlerta = 1; // Amarelo
        } else {
          // NOVO (0 a 3 anos) -> REUTILIZA
          deveTrocar = false;
          nivelAlerta = 0; // Verde
        }
      }
    }

    // Atualiza a tela se algo mudou
    if (_substituirPo != deveTrocar || _statusAlertaPo != nivelAlerta) {
      setState(() {
        _substituirPo = deveTrocar;
        _statusAlertaPo = nivelAlerta;
      });
    }
  }

  void _tentarAtualizarNormaPeloAno() {
    if (_fabricanteSelecionado == null || _tipoSelecionado == null || _cargaSelecionada == null) return;
    String textoData = _anoFabController.text;
    if (textoData.length < 7) return;

    try {
      String parteAno = textoData.split('/').last;
      int ano = int.parse(parteAno);

      final dados = TABELA_TECNICA.firstWhere((e) =>
      e.fabricante == _fabricanteSelecionado &&
          e.tipo == _tipoSelecionado &&
          e.carga == _cargaSelecionada
      );

      String normaCalculada = dados.getNormaCorreta(ano);
      if (_normaController.text != normaCalculada) {
        setState(() => _normaController.text = normaCalculada);
      }
    } catch (e) {}
  }

  void _carregarListasIniciais() {
    final fabricantes = TABELA_TECNICA.map((e) => e.fabricante).toSet().toList();
    fabricantes.sort();
    setState(() => _listaFabricantes = fabricantes);
  }

  void _aoSelecionarFabricante(String fab) {
    setState(() {
      _fabricanteSelecionado = fab;
      _fabricanteController.text = fab;
      _resetarCascata(nivel: 1);

      _listaTiposDisponiveis = TABELA_TECNICA
          .where((e) => e.fabricante == fab)
          .map((e) => e.tipo)
          .toSet()
          .toList();
      _listaTiposDisponiveis.sort();

      if (_listaTiposDisponiveis.length == 1) {
        _aoSelecionarTipo(_listaTiposDisponiveis.first);
      }
    });
  }

  void _aoSelecionarTipo(String? tipo) {
    if (tipo == null || _fabricanteSelecionado == null) return;
    setState(() {
      _tipoSelecionado = tipo;
      _resetarCascata(nivel: 2);

      _listaCargasDisponiveis = TABELA_TECNICA
          .where((e) => e.fabricante == _fabricanteSelecionado && e.tipo == tipo)
          .map((e) => e.carga)
          .toSet()
          .toList();

      _listaCargasDisponiveis.sort((a, b) => a.compareTo(b));

      if (_listaCargasDisponiveis.length == 1) {
        _aoSelecionarCarga(_listaCargasDisponiveis.first);
      }
    });
  }

  void _aoSelecionarCarga(String? carga) {
    if (carga == null) return;
    setState(() {
      _cargaSelecionada = carga;
      // Ao trocar o tipo de carga, recalcula se precisa trocar pó
      Future.delayed(Duration.zero, _calcularNecessidadeTrocaPo);
    });

    try {
      final dados = TABELA_TECNICA.firstWhere((e) =>
      e.fabricante == _fabricanteSelecionado &&
          e.tipo == _tipoSelecionado &&
          e.carga == carga
      );

      setState(() {
        _projetoController.text = dados.projeto;
        _capExtintoraController.text = dados.capacidadeExtintora;
        _normaController.text = dados.norma;
        _pressaoController.text = dados.pressaoTrabalho;
      });
      _tentarAtualizarNormaPeloAno();
    } catch (e) {}
  }

  void _resetarCascata({required int nivel}) {
    if (nivel <= 1) {
      _tipoSelecionado = null;
      _listaTiposDisponiveis = [];
    }
    if (nivel <= 2) {
      _cargaSelecionada = null;
      _listaCargasDisponiveis = [];
      _projetoController.clear();
      _capExtintoraController.clear();
      _pressaoController.clear();
    }
  }

  void _carregarDadosEdicaoOuNovo() {
    if (widget.equipamentoParaEditar != null) {
      final e = widget.equipamentoParaEditar!;

      _cilindroController.text = e.numeroCilindro;
      _ativoFixoController.text = e.ativoFixo;
      _fabricanteController.text = e.fabricante;
      _pinturaController.text = e.numeroPintura ?? '';

      _anoFabController.text = e.anoFabricacao;
      _ultimoTHController.text = e.anoUltimoTH ?? '';
      _ultimaRecargaController.text = e.ultimaRecarga ?? '';

      // Carrega a data da troca do pó
      _ultimaTrocaPoController.text = e.ultimaTrocaPo ?? '';

      _normaController.text = e.normaFabricacao;
      _capExtintoraController.text = e.capacidadeExtintora;
      _projetoController.text = e.projeto ?? '';
      _pressaoController.text = e.pressaoTrabalho ?? '';

      _lotePoController.text = e.lotePo ?? '';
      _substituirPo = e.substituirPo;

      if (e.origemSelo != null && e.origemSelo!.isNotEmpty) {
        _origemSelo = e.origemSelo!;
      }

      if (_listaFabricantes.contains(e.fabricante)) {
        _fabricanteSelecionado = e.fabricante;
        _listaTiposDisponiveis = TABELA_TECNICA.where((i) => i.fabricante == e.fabricante).map((i) => i.tipo).toSet().toList();
        _listaTiposDisponiveis.sort();
        if (_listaTiposDisponiveis.contains(e.tipo)) {
          _tipoSelecionado = e.tipo;
          _listaCargasDisponiveis = TABELA_TECNICA.where((i) => i.fabricante == e.fabricante && i.tipo == e.tipo).map((i) => i.carga).toSet().toList();
          if (_listaCargasDisponiveis.contains(e.capacidade)) {
            _cargaSelecionada = e.capacidade;
          }
        }
      } else {
        _fabricanteSelecionado = e.fabricante;
        _tipoSelecionado = e.tipo;
        _cargaSelecionada = e.capacidade;
      }
    } else {
      if (widget.clientePreSelecionado != null) _clienteSelecionado = widget.clientePreSelecionado;
      if (widget.numeroCascoPreenchido != null) _ativoFixoController.text = widget.numeroCascoPreenchido!;
    }
  }

  bool _isTipoPo() {
    if (_tipoSelecionado == null) return false;
    final t = _tipoSelecionado!.toUpperCase();
    return t.contains('PO') || t.contains('ABC') || t.contains('BC') || t == 'PQS';
  }

  Future<void> _condenarEquipamento() async {
    final motivoController = TextEditingController();
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Condenar Equipamento', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Atenção: BAIXAR/CONDENAR.'),
            TextField(controller: motivoController, decoration: const InputDecoration(labelText: 'Motivo')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );
    if (confirmou == true) await _salvarGeral(status: StatusEquipamento.baixado, motivoCondenacao: motivoController.text);
  }

  Future<void> _salvar() async {
    await _salvarGeral(status: widget.equipamentoParaEditar?.status ?? StatusEquipamento.ativo);
  }

  Future<void> _salvarGeral({required StatusEquipamento status, String? motivoCondenacao}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_clienteSelecionado == null && widget.equipamentoParaEditar == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione o Cliente.')));
      return;
    }

    final fabricanteFinal = _fabricanteSelecionado ?? _fabricanteController.text.toUpperCase();
    final tipoFinal = _tipoSelecionado ?? 'OUTROS';
    final cargaFinal = _cargaSelecionada ?? 'N/A';

    final usuario = Provider.of<UsuarioProvider>(context, listen: false).usuario;
    if (usuario == null) return;

    setState(() => _isSaving = true);

    try {
      final eq = Equipamento(
        id: widget.equipamentoParaEditar?.id ?? '',
        empresaId: usuario.empresaId,
        clienteId: widget.equipamentoParaEditar?.clienteId ?? _clienteSelecionado!.id,
        clienteNome: widget.equipamentoParaEditar?.clienteNome ?? _clienteSelecionado!.nome,
        numeroCilindro: _cilindroController.text.trim().toUpperCase(),
        ativoFixo: _ativoFixoController.text.trim().toUpperCase(),
        numeroPintura: _pinturaController.text.trim(),

        tipo: tipoFinal,
        capacidade: cargaFinal,
        capacidadeExtintora: _capExtintoraController.text.trim().toUpperCase(),
        projeto: _projetoController.text.trim(),
        pressaoTrabalho: _pressaoController.text.trim(),
        fabricante: fabricanteFinal,
        normaFabricacao: _normaController.text.trim(),

        anoFabricacao: _anoFabController.text.trim(),
        anoUltimoTH: _ultimoTHController.text.trim(),
        ultimaRecarga: _ultimaRecargaController.text.trim(),

        lotePo: _isTipoPo() ? _lotePoController.text.trim() : null,
        substituirPo: _isTipoPo() ? _substituirPo : false,

        // Salva a origem apenas se for pó (ou salva sempre, mas o input só aparece se for pó)
        origemSelo: _isTipoPo() ? _origemSelo : null,
        ultimaTrocaPo: _isTipoPo() ? _ultimaTrocaPoController.text.trim() : null,

        motivoCondenacao: motivoCondenacao,
        status: status,
        isAbcPremium: false,
      );

      final col = FirebaseFirestore.instance.collection('equipamentos');
      if (widget.equipamentoParaEditar != null) {
        await col.doc(eq.id).update(eq.toJson());
      } else {
        final docRef = await col.add(eq.toJson());
        final novoComId = Equipamento.fromJson(eq.toJson(), docRef.id);
        if (mounted) Navigator.of(context).pop(novoComId);
        return;
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = Provider.of<UsuarioProvider>(context, listen: false).usuario;
    if (usuario == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final isEdit = widget.equipamentoParaEditar != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar Extintor' : 'Novo Extintor'),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (!isEdit && widget.clientePreSelecionado == null)
                AutocompleteParceiroWidget(
                  empresaId: usuario.empresaId,
                  tipoParceiro: TipoParceiro.cliente,
                  onParceiroSelected: (p) => setState(() => _clienteSelecionado = p),
                ),
              if (isEdit)
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(widget.equipamentoParaEditar!.clienteNome),
                  subtitle: const Text('Proprietário'),
                ),
              const Divider(),

              // --- DADOS TÉCNICOS ---
              Card(
                color: Colors.blueGrey.shade50,
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Autocomplete<String>(
                        optionsBuilder: (v) {
                          if (v.text.isEmpty) return const Iterable<String>.empty();
                          return _listaFabricantes.where((o) => o.contains(v.text.toUpperCase()));
                        },
                        onSelected: _aoSelecionarFabricante,
                        fieldViewBuilder: (ctx, ctrl, focus, onSub) {
                          if (_fabricanteSelecionado != null && ctrl.text != _fabricanteSelecionado) {
                            ctrl.text = _fabricanteSelecionado!;
                          }
                          return TextFormField(
                            controller: ctrl, focusNode: focus,
                            decoration: const InputDecoration(labelText: 'Fabricante *', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                            validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: DropdownButtonFormField<String>(
                            value: _tipoSelecionado, isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                            items: _listaTiposDisponiveis.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: _listaTiposDisponiveis.isEmpty ? null : _aoSelecionarTipo,
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: DropdownButtonFormField<String>(
                            value: _cargaSelecionada, isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Carga', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                            items: _listaCargasDisponiveis.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: _listaCargasDisponiveis.isEmpty ? null : _aoSelecionarCarga,
                          )),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(child: TextFormField(
                    controller: _ativoFixoController, textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Ativo Fixo *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.qr_code)),
                    validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(
                    controller: _cilindroController, textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Nº Cilindro *', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                  )),
                ],
              ),
              const SizedBox(height: 12),

              // --- DATAS E NORMA ---
              Row(
                children: [
                  Expanded(child: TextFormField(
                    controller: _anoFabController, inputFormatters: [_dataMask], keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Ano Fab. *', hintText: 'MM/AAAA', border: OutlineInputBorder()),
                    validator: (v) => v!.length < 7 ? 'Inválido' : null,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(
                    controller: _ultimoTHController, inputFormatters: [_dataMask], keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Último TH', hintText: 'MM/AAAA', border: OutlineInputBorder()),
                  )),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(child: TextFormField(
                    controller: _ultimaRecargaController, inputFormatters: [_dataMask], keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Última Recarga', hintText: 'MM/AAAA', border: OutlineInputBorder()),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(
                    controller: _normaController, decoration: const InputDecoration(labelText: 'Norma Fab.', border: OutlineInputBorder()),
                  )),
                ],
              ),

              const SizedBox(height: 12),
              TextFormField(
                  controller: _pinturaController,
                  decoration: const InputDecoration(labelText: 'Nº Pintura (Opcional)', border: OutlineInputBorder())
              ),

              // --- SEÇÃO DE PÓ QUÍMICO COMPLETA ---
              if (_isTipoPo()) ...[
                const SizedBox(height: 20),
                const Divider(thickness: 2),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text("GESTÃO DO AGENTE EXTINTOR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
                ),

                // 1. Origem
                DropdownButtonFormField<String>(
                  value: _origemSelo,
                  decoration: InputDecoration(
                    labelText: 'Origem da Manutenção Anterior',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: _origemSelo == 'TERCEIROS' ? Colors.orange.shade50 : Colors.green.shade50,
                    prefixIcon: const Icon(Icons.history),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'TERCEIROS', child: Text('Terceiros / Desconhecido (Trocar)')),
                    DropdownMenuItem(value: 'NOSSA', child: Text('Nossa Empresa (Verif. Validade)')),
                    DropdownMenuItem(value: 'FABRICA', child: Text('Fábrica / Original (Verif. Data)')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _origemSelo = v);
                      _calcularNecessidadeTrocaPo();
                    }
                  },
                ),

                const SizedBox(height: 12),

                // 2. Data da Troca do Pó
                TextFormField(
                  controller: _ultimaTrocaPoController,
                  inputFormatters: [_dataMask],
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Data da Última Troca de Pó',
                      hintText: 'MM/AAAA',
                      border: OutlineInputBorder(),
                      helperText: 'Base para cálculo da validade (5 anos)'
                  ),
                ),

                const SizedBox(height: 12),

                // 3. Alerta Visual (Sinal Verde/Amarelo/Vermelho)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: _statusAlertaPo == 2 ? Colors.red
                            : _statusAlertaPo == 1 ? Colors.orange
                            : Colors.green
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: _statusAlertaPo == 2 ? Colors.red.shade50
                        : _statusAlertaPo == 1 ? Colors.orange.shade50
                        : Colors.green.shade50,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          if (_statusAlertaPo == 2)
                            const Chip(
                                avatar: Icon(Icons.close, color: Colors.white, size: 16),
                                label: Text('TROCA OBRIGATÓRIA (Venceu/3º)', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                backgroundColor: Colors.red
                            )
                          else if (_statusAlertaPo == 1)
                            const Chip(
                                avatar: Icon(Icons.warning_amber, color: Colors.black, size: 16),
                                label: Text('ATENÇÃO: PÓ COM 4 ANOS', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                                backgroundColor: Colors.amber
                            )
                          else
                            const Chip(
                                avatar: Icon(Icons.check, color: Colors.white, size: 16),
                                label: Text('REUTILIZAR (Novo)', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                backgroundColor: Colors.green
                            )
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _lotePoController,
                              inputFormatters: [_loteMask],
                              keyboardType: TextInputType.number,
                              enabled: !_substituirPo,
                              decoration: const InputDecoration(
                                labelText: 'Lote Atual',
                                border: OutlineInputBorder(),
                                counterText: '',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: SwitchListTile(
                              title: const Text('Substituir Pó?'),
                              subtitle: Text(
                                  _statusAlertaPo == 2 ? 'Troca Obrigatória' :
                                  _statusAlertaPo == 1 ? 'Avalie com Cuidado' : 'Pó em dia'
                              ),
                              value: _substituirPo,
                              onChanged: _statusAlertaPo == 2
                                  ? null // Trava se for obrigatório
                                  : (v) => setState(() => _substituirPo = v),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                  onPressed: _isSaving ? null : _salvar,
                  child: Text(_isSaving ? 'SALVANDO...' : 'SALVAR EQUIPAMENTO', style: const TextStyle(color: Colors.white)),
                ),
              ),

              if (isEdit) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    icon: const Icon(Icons.block, color: Colors.red),
                    label: const Text('CONDENAR ESTE EQUIPAMENTO'),
                    onPressed: _condenarEquipamento,
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}