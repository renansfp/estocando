// Salve como: lib/telas/producao/estacao/tela_triagem_limpeza.dart
// (VERSÃO v1.0 - Tela de Triagem Completa)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/models/equipamento.dart';

class TelaTriagemLimpeza extends StatefulWidget {
  final String itemOsId;
  final String idRastreio;
  final String tipoAgente;
  final String equipamentoId;

  const TelaTriagemLimpeza({
    Key? key,
    required this.itemOsId,
    required this.idRastreio,
    required this.tipoAgente,
    required this.equipamentoId,
  }) : super(key: key);

  @override
  _TelaTriagemLimpezaState createState() => _TelaTriagemLimpezaState();
}

class _TelaTriagemLimpezaState extends State<TelaTriagemLimpeza> {
  bool _isLoading = true;
  bool _isSaving = false;

  Equipamento? _equipamento;
  bool _testeVencidoReal = false;
  bool _precisaPintura = false;

  final Color _corPrincipal = const Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    _buscarDadosReais();
  }

  Future<void> _buscarDadosReais() async {
    // Se não tiver ID de equipamento (item novo ou erro), libera a tela
    if (widget.equipamentoId.isEmpty) {
      if (mounted) setState(() { _testeVencidoReal = true; _isLoading = false; });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('equipamentos').doc(widget.equipamentoId).get();

      if (doc.exists && doc.data() != null) {
        final dados = doc.data() as Map<String, dynamic>;
        // IMPORTANTE: Certifique-se que seu Equipamento.fromJson aceita (Map, String)
        final equip = Equipamento.fromJson(dados, doc.id);

        // --- LÓGICA DE VENCIMENTO (5 ANOS) ---
        bool venceu = true;
        final anoAtual = DateTime.now().year;

        // 1. Tenta pelo Último TH
        if (equip.anoUltimoTH != null && equip.anoUltimoTH!.isNotEmpty) {
          int? anoTH;
          // Tratamento para "MM/AAAA" ou apenas "AAAA"
          if (equip.anoUltimoTH!.contains('/')) {
            final partes = equip.anoUltimoTH!.split('/');
            if (partes.length >= 2) anoTH = int.tryParse(partes[1]);
          } else {
            anoTH = int.tryParse(equip.anoUltimoTH!);
          }

          if (anoTH != null) {
            // Se a diferença for menor que 5, AINDA está válido.
            // Ex: TH 2022. Estamos em 2026. 2026 - 2022 = 4 (Válido).
            // Se for 2021. 2026 - 2021 = 5 (Venceu).
            if ((anoAtual - anoTH) < 5) {
              venceu = false;
            }
          }
        }
        // 2. Tenta pela Fabricação (se não tiver TH)
        else {
          try {
            final partes = equip.anoFabricacao.split('/'); // Espera MM/AAAA
            if (partes.length == 2) {
              final anoFab = int.parse(partes[1]);
              if ((anoAtual - anoFab) < 5) venceu = false;
            }
          } catch (e) {
            venceu = true; // Na dúvida, venceu
          }
        }

        if (mounted) {
          setState(() {
            _equipamento = equip;
            _testeVencidoReal = venceu;
            // Se venceu o teste, a pintura é obrigatória (processo de lixa)
            if (venceu) {
              _precisaPintura = true;
            }
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() { _testeVencidoReal = true; _isLoading = false; });
      }
    } catch (e) {
      print("Erro ao buscar equipamento: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _calcularDestino() {
    // 1. Pintura/Lixa tem prioridade visual
    if (_precisaPintura) return 'aguardando_lixa';

    final tipoItemUpper = widget.tipoAgente.toUpperCase();
    final tipoEquipUpper = _equipamento?.tipo.toUpperCase() ?? '';

    // 2. CO2 vai pra válvula
    if (tipoItemUpper.contains('CO') || tipoEquipUpper.contains('CO')) {
      return 'aguardando_manutencao_valvula';
    }

    // 3. Teste Hidrostático (se não caiu na lixa antes, cai aqui)
    if (_testeVencidoReal) {
      return 'aguardando_teste_hidro';
    }

    // 4. Se tá tudo lindo, vai pra recarga
    return 'aguardando_recarga';
  }

  Future<void> _confirmarTriagem() async {
    setState(() => _isSaving = true);
    try {
      if (_testeVencidoReal) _precisaPintura = true;

      final proximoStatus = _calcularDestino();

      await FirebaseFirestore.instance.collection('itens_os').doc(widget.itemOsId).update({
        'status': proximoStatus,
        'statusAtual': 'emProducao', // Garante que não volta pra 'emCadastro'
        'triagem': {
          'precisaPintura': _precisaPintura,
          'testeVencido': _testeVencidoReal,
          'data': FieldValue.serverTimestamp(),
          'operador': 'app_triagem', // Idealmente usar usuario.nome
        }
      });

      if (!mounted) return;

      final destinoLegivel = proximoStatus
          .replaceAll('aguardando_', '')
          .toUpperCase()
          .replaceAll('_', ' ');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sucesso! Enviado para: $destinoLegivel'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.pop(context); // Volta pra lista de limpeza
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Triagem Técnica'),
          backgroundColor: _corPrincipal,
          foregroundColor: Colors.white
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- CARD DE DADOS ---
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                        'Item: ${widget.idRastreio}',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _corPrincipal)
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${_equipamento?.tipo ?? widget.tipoAgente} - ${_equipamento?.capacidade ?? ""}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Fab: ${_equipamento?.anoFabricacao ?? "?"}'),
                        Text('Último TH: ${_equipamento?.anoUltimoTH ?? "Original"}'),
                      ],
                    ),
                    const SizedBox(height: 15),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _testeVencidoReal ? Colors.orange.shade100 : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _testeVencidoReal ? Colors.orange : Colors.green),
                      ),
                      child: Text(
                        _testeVencidoReal ? '⚠️ TESTE VENCIDO' : '✅ TESTE EM DIA',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _testeVencidoReal ? Colors.deepOrange : Colors.green[800]
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- CHECKBOX DE PINTURA ---
            Card(
              elevation: 2,
              color: _testeVencidoReal ? Colors.grey.shade200 : null,
              child: SwitchListTile(
                title: Text(
                    "Pintura / Casco Ruim?",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _testeVencidoReal ? Colors.grey : Colors.black
                    )
                ),
                subtitle: Text(
                  _testeVencidoReal
                      ? "OBRIGATÓRIO: Item fará Teste Hidrostático"
                      : "Ativar para enviar para LIXA",
                  style: TextStyle(
                      color: _testeVencidoReal ? Colors.orange[800] : null,
                      fontWeight: _testeVencidoReal ? FontWeight.bold : null
                  ),
                ),
                value: _precisaPintura,
                activeColor: Colors.deepOrange,
                secondary: Icon(
                    Icons.format_paint,
                    color: _testeVencidoReal ? Colors.grey : Colors.deepOrange,
                    size: 30
                ),
                onChanged: _testeVencidoReal
                    ? null // Trava se teste vencido
                    : (val) => setState(() => _precisaPintura = val),
              ),
            ),

            const Spacer(),

            // --- BOTÃO CONFIRMAR ---
            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle, size: 28),
                label: const Text('CONFIRMAR TRIAGEM', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _corPrincipal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                onPressed: _isSaving ? null : _confirmarTriagem,
              ),
            )
          ],
        ),
      ),
    );
  }
}