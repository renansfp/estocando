// lib/telas/producao/estacao/tela_triagem_limpeza.dart
// Migrada para Repository Pattern — sem acesso direto ao Firestore.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/models/equipamento.dart';
import 'package:protecin_producao/models/usuario.dart';
import 'package:protecin_producao/provider/equipamento_provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/widgets/seletor_operador.dart';

class TelaTriagemLimpeza extends StatefulWidget {
  final String itemOsId;
  final String idRastreio;
  final String tipoAgente;
  final String equipamentoId;
  final String osId;

  const TelaTriagemLimpeza({
    super.key,
    required this.itemOsId,
    required this.idRastreio,
    required this.tipoAgente,
    required this.equipamentoId,
    required this.osId,
  });

  @override
  State<TelaTriagemLimpeza> createState() => _TelaTriagemLimpezaState();
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
    if (widget.equipamentoId.isEmpty) {
      if (mounted) {
        setState(() {
          _testeVencidoReal = true;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      // Usa EquipamentoProvider em vez de Firestore direto
      final dados = await context
          .read<EquipamentoProvider>()
          .buscarPorId(widget.equipamentoId);

      if (dados != null) {
        bool venceu = true;
        final anoAtual = DateTime.now().year;

        if (dados.anoUltimoTH != null && dados.anoUltimoTH!.isNotEmpty) {
          int? anoTH;
          if (dados.anoUltimoTH!.contains('/')) {
            final partes = dados.anoUltimoTH!.split('/');
            if (partes.length >= 2) anoTH = int.tryParse(partes[1]);
          } else {
            anoTH = int.tryParse(dados.anoUltimoTH!);
          }
          if (anoTH != null && (anoAtual - anoTH) < 5) venceu = false;
        } else {
          try {
            final partes = dados.anoFabricacao.split('/');
            if (partes.length == 2) {
              final anoFab = int.parse(partes[1]);
              if ((anoAtual - anoFab) < 5) venceu = false;
            }
          } catch (_) {
            venceu = true;
          }
        }

        if (mounted) {
          setState(() {
            _equipamento = dados;
            _testeVencidoReal = venceu;
            if (venceu) _precisaPintura = true;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _testeVencidoReal = true;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _gerarRoteiroCompleto() {
    final String agente = widget.tipoAgente.toUpperCase();
    List<String> roteiro = ['descarga', 'limpeza'];

    if (agente.contains('CO2')) {
      if (_precisaPintura || _testeVencidoReal) roteiro.add('lixa');
      roteiro.addAll(['manutencao_valvula', 'saque_valvula']);
      if (_testeVencidoReal) roteiro.add('th');
      if (_precisaPintura || _testeVencidoReal) roteiro.add('pintura');
      roteiro.addAll(['recarga_co2', 'estanqueidade_co2']);
    } else {
      String sufixo = agente.contains('ABC')
          ? 'abc'
          : (agente.contains('BC') ? 'bc' : 'agua_espuma');
      if (_precisaPintura || _testeVencidoReal) roteiro.add('lixa');
      if (_testeVencidoReal) roteiro.add('th');
      if (_precisaPintura || _testeVencidoReal) roteiro.add('pintura');
      if (agente.contains('ABC') || agente.contains('BC')) {
        roteiro.add('manutencao_valvula_po');
      }
      roteiro.addAll(['recarga_$sufixo', 'estanqueidade_$sufixo']);
    }

    roteiro.addAll(['pre_montagem', 'montagem', 'expedicao']);
    return roteiro;
  }

  Future<void> _confirmarTriagem() async {
    setState(() => _isSaving = true);
    try {
      final roteiroFinal = _gerarRoteiroCompleto();
      final proximaEstacao =
      roteiroFinal[roteiroFinal.indexOf('limpeza') + 1];
      final proximoStatus = 'aguardando_$proximaEstacao';

      final operador = context.read<UsuarioProvider>().operadorAtivo?.nome ?? 'Operador';
      await context.read<ItemOsProvider>().confirmarTriagem(
        itemId: widget.itemOsId,
        osId: widget.osId,
        roteiro: roteiroFinal,
        proximoStatus: proximoStatus,
        proximaEstacao: proximaEstacao,
        precisaPintura: _precisaPintura,
        testeVencido: _testeVencidoReal,
        operador: operador,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Triagem Técnica'),
        backgroundColor: _corPrincipal,
        foregroundColor: Colors.white,
        actions: const [
          SeletorOperador(estacao: EstacaoProducao.limpeza),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCardInfo(),
            const SizedBox(height: 20),
            _buildCardPintura(),
            const Spacer(),
            _buildBotaoConfirmar(),
          ],
        ),
      ),
    );
  }

  Widget _buildCardInfo() {
    return Card(
      elevation: 4,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Item: ${widget.idRastreio}',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _corPrincipal),
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
                Text(
                    'Último TH: ${_equipamento?.anoUltimoTH ?? "Original"}'),
              ],
            ),
            const SizedBox(height: 15),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _testeVencidoReal
                    ? Colors.orange.shade100
                    : Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color:
                    _testeVencidoReal ? Colors.orange : Colors.green),
              ),
              child: Text(
                _testeVencidoReal ? 'TESTE VENCIDO' : 'TESTE EM DIA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _testeVencidoReal
                      ? Colors.deepOrange
                      : Colors.green[800],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardPintura() {
    return Card(
      elevation: 2,
      color: _testeVencidoReal ? Colors.grey.shade200 : null,
      child: SwitchListTile(
        title: const Text('Pintura / Casco Ruim?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_testeVencidoReal
            ? 'OBRIGATÓRIO: TH exige pintura'
            : 'Ativar para enviar para LIXA'),
        value: _precisaPintura,
        activeColor: Colors.deepOrange,
        secondary: Icon(Icons.format_paint,
            color: _testeVencidoReal ? Colors.grey : Colors.deepOrange),
        onChanged: _testeVencidoReal
            ? null
            : (val) => setState(() => _precisaPintura = val),
      ),
    );
  }

  Widget _buildBotaoConfirmar() {
    return SizedBox(
      height: 60,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.check_circle),
        label: const Text('CONFIRMAR TRIAGEM',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
            backgroundColor: _corPrincipal, foregroundColor: Colors.white),
        onPressed: _isSaving ? null : _confirmarTriagem,
      ),
    );
  }
}