// lib/telas/producao/estacao/tela_estacao_estanqueidade.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/models/usuario.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/widgets/botao_condenar.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';
import 'package:protecin_producao/widgets/seletor_operador.dart';

class TelaEstacaoEstanqueidade extends StatefulWidget {
  final String osId;
  final List<String> filtrosAgente;
  const TelaEstacaoEstanqueidade(
      {super.key, required this.osId, required this.filtrosAgente});

  @override
  State<TelaEstacaoEstanqueidade> createState() =>
      _TelaEstacaoEstanqueidadeState();
}

class _TelaEstacaoEstanqueidadeState
    extends State<TelaEstacaoEstanqueidade> {
  final TextEditingController _scannerController = TextEditingController();
  bool _processando = false;

  Stream<List<Map<String, dynamic>>>? _streamItens;
  String? _empresaIdEscutando;
  List<Map<String, dynamic>> _itensSnapshot = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final empresaId = context.watch<UsuarioProvider>().usuario?.empresaId;
    if (empresaId != null &&
        empresaId.isNotEmpty &&
        empresaId != _empresaIdEscutando) {
      _empresaIdEscutando = empresaId;
      _streamItens = context
          .read<ItemOsProvider>()
          .streamItensPorOsEStatus(
          widget.osId, 'aguardando_estanqueidade', empresaId);
    }
  }

  String _limparCodigo(String valor) {
    String limpo = valor.trim().toUpperCase();
    if (limpo.contains('HTTP')) limpo = limpo.split('/').last;
    return limpo.replaceAll('R-', '');
  }

  // ── CORREÇÃO BUG 2 ────────────────────────────────────────────────────────
  // Deriva o statusDestino correto para reprovar um item de volta à recarga.
  // Antes estava hardcoded como 'aguardando_recarga', o que fazia os itens
  // desaparecerem — as telas de recarga filtram por 'aguardando_recarga_co2',
  // 'aguardando_recarga_abc' etc., e nunca encontravam esses itens.
  //
  // Lógica: no roteiro do item, a etapa imediatamente ANTES de 'estanqueidade'
  // é sempre a etapa de recarga correspondente. Ex:
  //   roteiro CO2:  [..., 'recarga_co2',  'estanqueidade_co2',  ...]
  //   roteiro ABC:  [..., 'recarga_abc',  'estanqueidade_abc',  ...]
  //   roteiro BC:   [..., 'recarga_bc',   'estanqueidade_bc',   ...]
  // ─────────────────────────────────────────────────────────────────────────
  String _statusDestinoRecarga(Map<String, dynamic> item) {
    final List<String> roteiro = List<String>.from(item['roteiro'] ?? []);
    final int idxEstan =
    roteiro.indexWhere((e) => e.contains('estanqueidade'));
    if (idxEstan > 0) {
      // A etapa anterior no roteiro é sempre a recarga correspondente
      return 'aguardando_${roteiro[idxEstan - 1]}';
    }
    // Fallback por tipoAgente (segurança extra caso roteiro esteja vazio)
    final agente = (item['tipoAgente'] ?? '').toString().toLowerCase();
    if (agente.contains('co2')) return 'aguardando_recarga_co2';
    if (agente.contains('abc')) return 'aguardando_recarga_abc';
    if (agente.contains('bc')) return 'aguardando_recarga_bc';
    if (agente.contains('ap') || agente.contains('esp') || agente.contains('agua')) return 'aguardando_recarga_agua_espuma';
    return 'aguardando_recarga_abc';
  }

  Future<void> _aprovarItem(Map<String, dynamic> item) async {
    setState(() => _processando = true);
    try {
      final List<String> roteiro =
      List<String>.from(item['roteiro'] ?? []);
      int indexAtual =
      roteiro.indexWhere((etapa) => etapa.contains('estanqueidade'));
      String proximaEtapa =
      (indexAtual != -1 && indexAtual + 1 < roteiro.length)
          ? roteiro[indexAtual + 1]
          : 'pre_montagem';

      await context.read<ItemOsProvider>().confirmarEtapa(
        itemId: item['id'],
        dadosItem: {
          'estanqueidade': {
            'data': DateTime.now(),
            'resultado': 'APROVADO',
            'operador': context.read<UsuarioProvider>().operadorAtivo?.nome ?? 'Operador',
          }
        },
        osId: widget.osId,
        statusPendente: 'aguardando_estanqueidade',
        proximaEstacao: proximaEtapa,
      );

      _notificar(
          'Aprovado! Segue para: ${proximaEtapa.toUpperCase()}', Colors.green);
    } catch (e) {
      _notificar('Erro no DNA do Roteiro: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  // Recebe o item completo para derivar o statusDestino correto
  void _escolherMotivoReprovacao(Map<String, dynamic> item, String cracha) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Reprovar: $cracha — Voltar para Recarga',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              const Text('Selecione o componente com falha:',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              _itemMotivoRecarga(item, 'BICO', Icons.ev_station),
              _itemMotivoRecarga(item, 'MANOMETRO', Icons.speed),
              _itemMotivoRecarga(item, 'ROSCA', Icons.sync),
            ],
          ),
        );
      },
    );
  }

  // Agora recebe o item completo para calcular o statusDestino correto
  Widget _itemMotivoRecarga(
      Map<String, dynamic> item, String motivo, IconData icone) {
    return ListTile(
      leading: Icon(icone, color: Colors.orange),
      title: Text(motivo),
      onTap: () async {
        Navigator.pop(context);
        setState(() => _processando = true);

        final statusDestino = _statusDestinoRecarga(item);

        await context.read<ItemOsProvider>().reprovarItem(
          itemId: item['id'],
          osId: widget.osId,
          statusAtual: 'aguardando_estanqueidade',
          statusDestino: statusDestino,
          dadosFalha: {
            'estanqueidade_falha': {'motivo': motivo}
          },
        );

        _notificar('Voltou para Recarga! ($motivo)', Colors.orange);
        if (mounted) setState(() => _processando = false);
      },
    );
  }

  Future<void> _processarBipe(String codigo) async {
    if (codigo.isEmpty) return;
    String idCracha = _limparCodigo(codigo);
    final empresaId = context.read<UsuarioProvider>().usuario?.empresaId ?? '';
    // Busca local — scan instantâneo (sem round-trip Firestore)
    Map<String, dynamic>? item;
    if (_itensSnapshot.isNotEmpty) {
      try {
        item = _itensSnapshot.firstWhere(
              (i) => i['idCrachaTemporario']?.toString() == idCracha,
        );
      } catch (_) {
        item = null;
      }
    }
    // Fallback ao Firestore apenas se o snapshot ainda não chegou
    if (item == null && _itensSnapshot.isEmpty) {
      item = await context.read<ItemOsProvider>().buscarItemPorCracha(
        widget.osId, idCracha, 'aguardando_estanqueidade', empresaId,
      );
    }

    if (item != null) {
      await _aprovarItem(item);
    } else {
      _notificar('Item não pendente neste setor.', Colors.red);
    }
    _scannerController.clear();
  }

  void _notificar(String msg, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: cor,
        duration: const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Estanqueidade: OS ${widget.osId}'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        actions: const [
          SeletorOperador(estacao: EstacaoProducao.estanqueidade),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: CampoComScanner(
              controller: _scannerController,
              label: 'Bipar Crachá para Aprovar',
              onSubmitted: _processarBipe,
            ),
          ),
          const Divider(height: 1),
          if (_processando) const LinearProgressIndicator(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _streamItens,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                _itensSnapshot = snap.data!;
                final itensDaBancada = snap.data!.where((item) {
                  final agente =
                  (item['tipoAgente'] ?? '').toString().toUpperCase();
                  return widget.filtrosAgente.any((f) {
                    String filtro = f.toUpperCase();
                    if (filtro == 'BC') {
                      return agente == 'BC' ||
                          (agente.contains('BC') &&
                              !agente.contains('ABC'));
                    }
                    return agente.contains(filtro);
                  });
                }).toList();

                if (itensDaBancada.isEmpty) {
                  return const Center(child: Text('Lote concluído!'));
                }

                return ListView.builder(
                  itemCount: itensDaBancada.length,
                  itemBuilder: (context, index) {
                    final item = itensDaBancada[index];
                    final String cracha =
                        item['idCrachaTemporario'] ?? '---';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.water_drop,
                            color: Colors.teal),
                        title: Text('Crachá: $cracha'),
                        subtitle: Text(
                            '${item['tipoAgente']} - ${item['capacidade'] ?? ""}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BotaoCondenar(
                                item: item, etapa: 'estanqueidade'),
                            IconButton(
                              icon: const Icon(Icons.thumb_down,
                                  color: Colors.orange),
                              tooltip: 'Reprovar → volta para recarga',
                              // Passa o item completo para derivar o statusDestino
                              onPressed: () =>
                                  _escolherMotivoReprovacao(item, cracha),
                            ),
                            IconButton(
                              icon: const Icon(Icons.thumb_up,
                                  color: Colors.green),
                              onPressed: () => _aprovarItem(item),
                            ),
                          ],
                        ),
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
}