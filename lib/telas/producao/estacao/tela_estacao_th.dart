// Salve como: lib/telas/producao/estacao/tela_estacao_th.dart
// (VERSÃO v3.1 - Correção: Grava 'anoUltimoTH' no Cadastro)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // <--- ADICIONADO PARA FORMATAR A DATA
import 'package:protecin_producao/models/equipamento.dart';

class TelaEstacaoTH extends StatefulWidget {
  final String usuarioNome;
  final String estacaoNome;
  final String? osIdAtual;

  const TelaEstacaoTH({
    super.key,
    required this.usuarioNome,
    required this.estacaoNome,
    this.osIdAtual,
  });

  @override
  State<TelaEstacaoTH> createState() => _TelaEstacaoTHState();
}

class _TelaEstacaoTHState extends State<TelaEstacaoTH> {
  final _controllerEtiqueta = TextEditingController();
  final _focusEtiqueta = FocusNode();
  Equipamento? _equipamentoAtual;
  bool _buscando = false;

  // Variável de controle do tipo de teste
  bool _isAltaPressao = false; // True = CO2, False = PQS/Agua

  final _taraEstampadaController = TextEditingController();
  final _pesoAtualController = TextEditingController();
  final _pressaoTesteController = TextEditingController();
  final _motivoReprovaController = TextEditingController();

  double _porcentagemPerda = 0.0;
  bool _alertaPerdaMassa = false;

  // Checklist de Baixa Pressão
  bool _semVazamento = false;
  bool _semDeformacao = false;

  @override
  void initState() {
    super.initState();
    _taraEstampadaController.addListener(_calcularPerdaMassa);
    _pesoAtualController.addListener(_calcularPerdaMassa);
  }

  @override
  void dispose() {
    _taraEstampadaController.dispose();
    _pesoAtualController.dispose();
    _pressaoTesteController.dispose();
    _motivoReprovaController.dispose();
    _controllerEtiqueta.dispose();
    super.dispose();
  }

  void _calcularPerdaMassa() {
    if (_equipamentoAtual == null || !_isAltaPressao) return;

    double tg = double.tryParse(_taraEstampadaController.text.replaceAll(',', '.')) ?? 0.0;
    double ta = double.tryParse(_pesoAtualController.text.replaceAll(',', '.')) ?? 0.0;

    if (tg > 0 && ta > 0) {
      double perda = ((tg - ta) / tg) * 100;
      setState(() {
        _porcentagemPerda = perda;
        _alertaPerdaMassa = perda > 5.0; // Norma: >5% condena
      });
    } else {
      setState(() { _porcentagemPerda = 0.0; _alertaPerdaMassa = false; });
    }
  }

  void _buscarEquipamento(String codigo) async {
    if (codigo.isEmpty) return;
    setState(() => _buscando = true);
    _limparTela(manterTextoBusca: true);

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('equipamentos').doc(codigo).get();

      if (!doc.exists) {
        final query = await FirebaseFirestore.instance.collection('equipamentos')
            .where('idRastreioInterno', isEqualTo: codigo).limit(1).get();
        if (query.docs.isNotEmpty) doc = query.docs.first;
      }

      if (doc.exists) {
        final eq = Equipamento.fromJson(doc.data() as Map<String, dynamic>, doc.id);

        // --- DETECÇÃO INTELIGENTE DE TIPO ---
        String t = eq.tipo.toUpperCase();
        bool alta = t.contains('CO') || t.contains('DIOXIDO');

        setState(() {
          _equipamentoAtual = eq;
          _isAltaPressao = alta;

          // Sugestão de Pressão baseada na norma
          if (alta) {
            _pressaoTesteController.text = '250'; // Alta Pressão
          } else {
            _pressaoTesteController.text = '27'; // Baixa Pressão
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Equipamento não encontrado!')));
        _limparTela();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      setState(() => _buscando = false);
      _controllerEtiqueta.clear();
    }
  }

  void _limparTela({bool manterTextoBusca = false}) {
    setState(() {
      if(!manterTextoBusca) _equipamentoAtual = null;
      _taraEstampadaController.clear();
      _pesoAtualController.clear();
      _pressaoTesteController.clear();
      _motivoReprovaController.clear();
      _porcentagemPerda = 0.0;
      _alertaPerdaMassa = false;
      _semVazamento = false;
      _semDeformacao = false;
    });
    if(!manterTextoBusca) _focusEtiqueta.requestFocus();
  }

  // --- AQUI ESTÁ A CORREÇÃO PRINCIPAL ---
  Future<void> _salvarProcesso(bool aprovado) async {
    if (_equipamentoAtual == null) return;

    // --- VALIDAÇÕES DE NORMA ---
    if (aprovado) {
      if (_isAltaPressao) {
        if (_taraEstampadaController.text.isEmpty || _pesoAtualController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CO2: Informe a Tara Gravada e Atual.')));
          return;
        }
        if (_alertaPerdaMassa) {
          bool forcar = await showDialog(context: context, builder: (c) => AlertDialog(
            title: const Text('ALERTA CRÍTICO'),
            content: const Text('Perda de massa > 5%. Norma obriga CONDENAÇÃO.\nDeseja aprovar mesmo assim?'),
            actions: [
              TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text('Cancelar')),
              TextButton(onPressed: ()=>Navigator.pop(c, true), child: const Text('Forçar (Não Recomendado)', style: TextStyle(color: Colors.red))),
            ],
          )) ?? false;
          if (!forcar) return;
        }
      } else {
        if (!_semVazamento || !_semDeformacao) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Confirme que não houve vazamento nem deformação.')));
          return;
        }
      }
    }

    setState(() => _buscando = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Formata a data para o padrão de cadastro (MM/yyyy)
      final String novoAnoTH = DateFormat('MM/yyyy').format(DateTime.now());

      // 1. Atualiza Equipamento
      final equipRef = FirebaseFirestore.instance.collection('equipamentos').doc(_equipamentoAtual!.id);

      Map<String, dynamic> dadosTH = {
        'status': aprovado ? 'EM_PROCESSO' : 'baixado',
        'etapa': aprovado ? 'PINTURA' : 'SUCATA',

        // --- CORREÇÃO: Atualiza os DOIS campos ---
        'dataUltimoTH': DateTime.now().toIso8601String(), // Para logs técnicos
        'anoUltimoTH': aprovado ? novoAnoTH : null, // <--- CAMPO CHAVE PARA O CADASTRO!

        'th_pressaoEnsaio': _pressaoTesteController.text,
        'th_aprovado': aprovado,
        'th_responsavel': widget.usuarioNome,
        'motivoCondenacao': aprovado ? null : _motivoReprovaController.text,
      };

      if (_isAltaPressao) {
        dadosTH['th_taraGravada'] = _taraEstampadaController.text;
        dadosTH['th_taraAtual'] = _pesoAtualController.text;
        dadosTH['th_perdaMassaPorcentagem'] = _porcentagemPerda;
      } else {
        dadosTH['th_semVazamento'] = _semVazamento;
        dadosTH['th_semDeformacao'] = _semDeformacao;
      }

      batch.update(equipRef, dadosTH);

      // 2. Atualiza Fluxo (Item OS)
      final itemQuery = await FirebaseFirestore.instance
          .collection('itens_os')
          .where('equipamentoId', isEqualTo: _equipamentoAtual!.id)
          .where('status', isEqualTo: 'aguardando_teste_hidro')
          .get();

      for (var doc in itemQuery.docs) {
        if (aprovado) {
          batch.update(doc.reference, {
            'status': 'aguardando_pintura',
            'th': { 'data': FieldValue.serverTimestamp(), 'resultado': 'APROVADO' }
          });
        } else {
          batch.update(doc.reference, {
            'status': 'condenado',
            'etapa': 'SUCATA',
            'motivoCondenacao': _motivoReprovaController.text,
            'th': { 'data': FieldValue.serverTimestamp(), 'resultado': 'REPROVADO' }
          });
        }
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(aprovado ? 'Aprovado! Vai para Pintura.' : 'Equipamento Condenado.'),
        backgroundColor: aprovado ? Colors.green : Colors.red,
      ));

      _limparTela();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    } finally {
      setState(() => _buscando = false);
    }
  }

  Widget _buildListaSelecaoRapida() {
    if (widget.osIdAtual == null) return const SizedBox.shrink();
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 20, bottom: 10),
            child: Text("Pendentes nesta OS:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('itens_os')
                  .where('osId', isEqualTo: widget.osIdAtual)
                  .where('status', isEqualTo: 'aguardando_teste_hidro')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final itens = snapshot.data!.docs;
                if (itens.isEmpty) return const Center(child: Text("Lote Finalizado no TH!", style: TextStyle(color: Colors.green)));

                return ListView.builder(
                  itemCount: itens.length,
                  itemBuilder: (context, index) {
                    final dados = itens[index].data() as Map<String, dynamic>;
                    final codigo = dados['idCrachaTemporario'] ?? '---';
                    final tipo = dados['tipoAgente'] ?? '';
                    final equipId = dados['equipamentoId'];

                    bool isCO2 = tipo.toString().toUpperCase().contains('CO');

                    return Card(
                      child: ListTile(
                        leading: Icon(Icons.touch_app, color: isCO2 ? Colors.orange : Colors.blue),
                        title: Text(codigo),
                        subtitle: Text(tipo),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () => _buscarEquipamento(equipId),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Estação TH - ${widget.usuarioNome}'),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_equipamentoAtual != null) ...[
              // --- CABEÇALHO DO ITEM ---
              Card(
                color: _isAltaPressao ? Colors.orange.shade50 : Colors.blue.shade50,
                child: ListTile(
                  title: Text('${_equipamentoAtual!.tipo} - ${_equipamentoAtual!.fabricante}'),
                  subtitle: Text('Cliente: ${_equipamentoAtual!.clienteNome}\nCilindro: ${_equipamentoAtual!.numeroCilindro}'),
                  trailing: Chip(
                    label: Text(_isAltaPressao ? "ALTA PRESSÃO" : "BAIXA PRESSÃO"),
                    backgroundColor: _isAltaPressao ? Colors.orange : Colors.blue,
                    labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: 15),

                    // --- ÁREA DINÂMICA (ALTA vs BAIXA) ---
                    if (_isAltaPressao) ...[
                      // FORMULÁRIO ALTA PRESSÃO (CO2)
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _taraEstampadaController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tara Gravada (TG)', border: OutlineInputBorder()))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: _pesoAtualController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Peso Atual (TA)', border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_porcentagemPerda != 0)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: _alertaPerdaMassa ? Colors.red[100] : Colors.green[100],
                              border: Border.all(color: _alertaPerdaMassa ? Colors.red : Colors.green)
                          ),
                          child: Text(
                            'Perda de Massa: ${_porcentagemPerda.toStringAsFixed(2)}% ${_alertaPerdaMassa ? "(CONDENAR)" : "(OK)"}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: _alertaPerdaMassa ? Colors.red : Colors.green[900]),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ] else ...[
                      // FORMULÁRIO BAIXA PRESSÃO (PQS/ÁGUA)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(border: Border.all(color: Colors.blue.shade200), borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          children: [
                            CheckboxListTile(
                              title: const Text("Sem Vazamento?"),
                              subtitle: const Text("Manômetro estabilizado / Sem bolhas"),
                              value: _semVazamento,
                              onChanged: (v) => setState(() => _semVazamento = v ?? false),
                            ),
                            CheckboxListTile(
                              title: const Text("Sem Deformação Permanente?"),
                              subtitle: const Text("Cilindro não estufou"),
                              value: _semDeformacao,
                              onChanged: (v) => setState(() => _semDeformacao = v ?? false),
                            ),
                          ],
                        ),
                      )
                    ],

                    const SizedBox(height: 15),
                    // PRESSÃO DE ENSAIO
                    TextField(
                        controller: _pressaoTesteController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Pressão Aplicada (kgf/cm²)',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.speed)
                        )
                    ),

                    const SizedBox(height: 20),
                    // BOTÕES DE AÇÃO
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 15)),
                            icon: const Icon(Icons.thumb_down, color: Colors.white),
                            label: const Text('REPROVAR', style: TextStyle(color: Colors.white)),
                            onPressed: () {
                              showDialog(context: context, builder: (c) => AlertDialog(
                                title: const Text('Motivo da Reprovação'),
                                content: TextField(controller: _motivoReprovaController, decoration: const InputDecoration(hintText: 'Ex: Furo, Rosca ruim, Perda Massa')),
                                actions: [
                                  TextButton(onPressed: ()=>Navigator.pop(c), child: const Text('Cancelar')),
                                  ElevatedButton(onPressed: (){ Navigator.pop(c); _salvarProcesso(false); }, child: const Text('Confirmar')),
                                ],
                              ));
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 15)),
                            icon: const Icon(Icons.thumb_up, color: Colors.white),
                            label: const Text('APROVAR', style: TextStyle(color: Colors.white)),
                            onPressed: () => _salvarProcesso(true),
                          ),
                        ),
                      ],
                    ),
                    TextButton(onPressed: _limparTela, child: const Text("Cancelar / Trocar Item"))
                  ],
                ),
              ),
            ] else ...[
              TextField(
                controller: _controllerEtiqueta,
                focusNode: _focusEtiqueta,
                decoration: const InputDecoration(labelText: 'Bipar Código / QR Code', border: OutlineInputBorder(), prefixIcon: Icon(Icons.qr_code_scanner), filled: true, fillColor: Colors.white),
                onSubmitted: _buscarEquipamento,
              ),
              if (_buscando) const LinearProgressIndicator(),
              _buildListaSelecaoRapida(),
            ],
          ],
        ),
      ),
    );
  }
}