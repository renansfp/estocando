// Salve como: lib/telas/producao/estacao/tela_estacao_manutencao_valvula.dart
// (VERSÃO v2.0 - Checklist Ajustado + Cálculo Automático de Peso)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:protecin_producao/models/equipamento.dart';

class TelaEstacaoManutencaoValvula extends StatefulWidget {
  final String usuarioNome;
  final String estacaoNome;
  final String? codigoPreDefinido;

  const TelaEstacaoManutencaoValvula({
    super.key,
    required this.usuarioNome,
    required this.estacaoNome,
    this.codigoPreDefinido,
  });

  @override
  State<TelaEstacaoManutencaoValvula> createState() => _TelaEstacaoManutencaoValvulaState();
}

class _TelaEstacaoManutencaoValvulaState extends State<TelaEstacaoManutencaoValvula> {
  // Controles
  final _controllerEtiqueta = TextEditingController();
  final _focusEtiqueta = FocusNode();
  Equipamento? _equipamentoAtual;
  bool _buscando = false;

  // Campos de Peso
  final _pesoVazioController = TextEditingController();
  final _pesoCheioController = TextEditingController(); // Agora será automático

  // Novo Checklist
  bool _kitSegurancaTrocado = false; // Antes: Anel Trocado
  bool _valvulaManutenida = false;   // Antes: Válvula Limpa

  // Peças trocadas (mantive para registro detalhado se precisar)
  bool _trocouOring = false;
  bool _trocouVeda = false;

  @override
  void initState() {
    super.initState();
    // O ouvinte dispara sempre que o texto do peso vazio muda
    _pesoVazioController.addListener(_calcularPesoFinal);

    if (widget.codigoPreDefinido != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controllerEtiqueta.text = widget.codigoPreDefinido!;
        _buscarEquipamento(widget.codigoPreDefinido!);
      });
    }
  }

  @override
  void dispose() {
    _controllerEtiqueta.dispose();
    _pesoVazioController.dispose();
    _pesoCheioController.dispose();
    _focusEtiqueta.dispose();
    super.dispose();
  }

  // --- O CÉREBRO DO PESO ---
  void _calcularPesoFinal() {
    if (_equipamentoAtual == null) return;

    // Só calcula se for CO2 (segurança)
    if (!_equipamentoAtual!.tipo.toUpperCase().contains('CO')) return;

    try {
      String textoDigitado = _pesoVazioController.text.replaceAll(',', '.');

      // Se não digitou nada, limpa o cheio
      if (textoDigitado.isEmpty) {
        _pesoCheioController.clear();
        return;
      }

      double vazio = double.parse(textoDigitado);
      double capacidadeCarga = 0.0;

      // Extrai o número da capacidade (ex: "6 KG" -> 6.0)
      final numeros = RegExp(r'[0-9]+').firstMatch(_equipamentoAtual!.capacidade);
      if (numeros != null) {
        capacidadeCarga = double.parse(numeros.group(0)!);
      }

      // A Mágica: Peso Cheio = Vazio + Carga
      double cheio = vazio + capacidadeCarga;

      // Atualiza o campo visualmente
      _pesoCheioController.text = cheio.toStringAsFixed(2).replaceAll('.', ',');

    } catch (e) {
      // Se digitar algo inválido, não faz nada
    }
  }

  void _buscarEquipamento(String codigo) async {
    if (codigo.isEmpty) return;
    setState(() => _buscando = true);
    _limparFormulario();

    try {
      final doc = await FirebaseFirestore.instance.collection('equipamentos').doc(codigo).get();

      if (doc.exists) {
        final eq = Equipamento.fromJson(doc.data() as Map<String, dynamic>, doc.id);
        setState(() {
          _equipamentoAtual = eq;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Equipamento não encontrado!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      setState(() => _buscando = false);
      if (widget.codigoPreDefinido == null) {
        _controllerEtiqueta.clear();
        // Foca direto no Peso Vazio para agilizar a produção
        // (Usei um pequeno delay para garantir que a tela redesenhou)
        Future.delayed(const Duration(milliseconds: 100), () {
          // FocusScope.of(context).requestFocus(_focusPesoVazio); // Se quiser implementar
        });
      }
    }
  }

  void _limparFormulario() {
    _pesoVazioController.clear();
    _pesoCheioController.clear();
    _kitSegurancaTrocado = false;
    _valvulaManutenida = false;
    _trocouOring = false;
    _trocouVeda = false;
  }

  Future<void> _salvarManutencao() async {
    if (_equipamentoAtual == null) return;

    // --- VALIDAÇÕES ---
    if (!_kitSegurancaTrocado) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ERRO: Confirme a troca do Kit de Segurança.')));
      return;
    }

    // Validação de Peso para CO2
    bool ehCO2 = _equipamentoAtual!.tipo.toUpperCase().contains('CO');
    if (ehCO2 && _pesoVazioController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ERRO: Informe o Peso Vazio.')));
      return;
    }

    setState(() => _buscando = true);

    try {
      // 1. Atualiza o Equipamento (Inventário)
      await FirebaseFirestore.instance.collection('equipamentos').doc(_equipamentoAtual!.id).update({
        'etapa': 'SAQUE', // Vai para o próximo setor
        'status': 'EM_PROCESSO',
        'valvula_pesoVazio': _pesoVazioController.text,
        'valvula_pesoCheioMeta': _pesoCheioController.text, // Salva o calculado
        'valvula_kitSegurancaTrocado': true,
        'valvula_manutenida': _valvulaManutenida,
        'valvula_pecasTrocadas': {'oring': _trocouOring, 'vedante': _trocouVeda},
        'valvula_responsavel': widget.usuarioNome,
        'valvula_data': DateTime.now().toIso8601String(),
      });

      // 2. Atualiza o Item na OS (Fluxo) - O VÍNCULO QUE CONSERTAMOS
      final itemQuery = await FirebaseFirestore.instance
          .collection('itens_os')
          .where('equipamentoId', isEqualTo: _equipamentoAtual!.id)
          .where('status', isEqualTo: 'aguardando_manutencao_valvula')
          .get();

      for (var doc in itemQuery.docs) {
        await doc.reference.update({
          'status': 'aguardando_saque_valvula', // Manda para o Saque
          // Opcional: Salvar histórico dentro do item
          'manutencao_valvula': {
            'data': FieldValue.serverTimestamp(),
            'operador': widget.usuarioNome,
            'pesoVazio': _pesoVazioController.text
          }
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sucesso! Enviado para Saque de Válvula.'), backgroundColor: Colors.teal));

      if (widget.codigoPreDefinido != null) {
        Navigator.pop(context);
      } else {
        setState(() {
          _equipamentoAtual = null;
          _limparFormulario();
        });
        _focusEtiqueta.requestFocus();
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    } finally {
      setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool ehCO2 = _equipamentoAtual?.tipo.toUpperCase().contains('CO') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text('Bancada Válvula - ${widget.usuarioNome}'),
        backgroundColor: Colors.teal.shade800, // Cor do setor
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Input de Bipagem
            TextField(
              controller: _controllerEtiqueta,
              focusNode: _focusEtiqueta,
              decoration: const InputDecoration(
                  labelText: 'Bipar Cilindro (Enter)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.qr_code),
                  filled: true,
                  fillColor: Colors.white
              ),
              onSubmitted: _buscarEquipamento,
            ),
            const SizedBox(height: 10),
            if (_buscando) const LinearProgressIndicator(),

            if (_equipamentoAtual != null) ...[
              // Card de Informações
              Card(
                color: Colors.teal.shade50,
                child: ListTile(
                  title: Text('${_equipamentoAtual!.tipo} - ${_equipamentoAtual!.fabricante}'),
                  subtitle: Text('Capacidade: ${_equipamentoAtual!.capacidade}\nCilindro: ${_equipamentoAtual!.numeroCilindro}'),
                  trailing: ehCO2
                      ? const Chip(label: Text("CO2"), backgroundColor: Colors.orange)
                      : const Icon(Icons.build_circle, color: Colors.teal),
                ),
              ),

              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: 15),
                    const Text("Pesagem (Kg)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                    const SizedBox(height: 10),

                    // --- LINHA DE PESOS INTELIGENTE ---
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _pesoVazioController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                                labelText: 'Peso Vazio (Atual)',
                                border: const OutlineInputBorder(),
                                // Destaque visual se for CO2
                                enabledBorder: ehCO2 ? const OutlineInputBorder(borderSide: BorderSide(color: Colors.orange, width: 2)) : null
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        const Icon(Icons.arrow_forward, color: Colors.grey),
                        const SizedBox(width: 15),
                        Expanded(
                          child: TextField(
                            controller: _pesoCheioController,
                            readOnly: true, // BLOQUEADO PARA O OPERADOR
                            decoration: const InputDecoration(
                              labelText: 'Peso Cheio (Meta)',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.black12, // Cor cinza para indicar "apenas leitura"
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const Divider(),
                    const Text("Checklist de Execução", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),

                    // --- CHECKLIST ATUALIZADO ---
                    CheckboxListTile(
                      title: const Text("Kit de segurança trocado?"),
                      subtitle: const Text("Anel, lacre, componentes"),
                      value: _kitSegurancaTrocado,
                      activeColor: Colors.teal,
                      onChanged: (v) => setState(() => _kitSegurancaTrocado = v ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text("Válvula manutenida?"),
                      subtitle: const Text("Limpeza e verificação"),
                      value: _valvulaManutenida,
                      activeColor: Colors.teal,
                      onChanged: (v) => setState(() => _valvulaManutenida = v ?? false),
                    ),
                  ],
                ),
              ),

              // Botão Finalizar
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("FINALIZAR MANUTENÇÃO", style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white
                  ),
                  onPressed: _salvarManutencao,
                ),
              )
            ] else ...[
              const Expanded(child: Center(child: Text('Aguardando bipagem...', style: TextStyle(color: Colors.grey, fontSize: 18)))),
            ]
          ],
        ),
      ),
    );
  }
}