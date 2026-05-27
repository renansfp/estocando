// lib/telas/producao/estacao/tela_estacao_saque.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/models/usuario.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/widgets/botao_condenar.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';
import 'package:protecin_producao/telas/estoque/tela_criar_requisicao.dart';
import 'package:protecin_producao/utils/mapeador_custos.dart';
import 'package:protecin_producao/widgets/seletor_operador.dart';

class TelaEstacaoSaque extends StatefulWidget {
  final String numeroLote;
  const TelaEstacaoSaque({super.key, required this.numeroLote});

  @override
  State<TelaEstacaoSaque> createState() => _TelaEstacaoSaqueState();
}

class _TelaEstacaoSaqueState extends State<TelaEstacaoSaque> {
  final Color _corSetor = Colors.red.shade700;
  final TextEditingController _scannerController = TextEditingController();

  String _limparCodigo(String valor) {
    String limpo = valor.trim().toUpperCase();
    if (limpo.contains('HTTP')) limpo = limpo.split('/').last;
    return limpo.replaceAll('R-', '');
  }

  Future<void> _processarBipe(String codigo) async {
    String idLimpo = _limparCodigo(codigo);
    _scannerController.clear();
    final empresaId = context.read<UsuarioProvider>().usuario?.empresaId ?? '';
    final item = await context.read<ItemOsProvider>().buscarItemPorCracha(
      widget.numeroLote,
      idLimpo,
      'aguardando_saque_valvula', empresaId
    );

    if (item != null) {
      _mostrarDialogoExecucao(item);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Crachá não encontrado nesta OS ou já processado.')),
        );
      }
    }
  }

  Future<void> _confirmarSaque(Map<String, dynamic> item) async {
    try {
      final List<String> roteiro =
      List<String>.from(item['roteiro'] ?? []);
      int indexAtual = roteiro.indexOf('saque_valvula');
      String proximaEstacao = roteiro[indexAtual + 1];
      final operador = context.read<UsuarioProvider>().operadorAtivo?.nome ?? 'Operador';

      await context.read<ItemOsProvider>().confirmarEtapa(
        itemId: item['id'],
        dadosItem: {
          'saque': {
            'data': DateTime.now(),
            'operador': operador,
            'inspecoes': {'interna': true, 'rosca': true},
          }
        },
        osId: widget.numeroLote,
        statusPendente: 'aguardando_saque_valvula',
        proximaEstacao: proximaEstacao,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Erro ao confirmar saque: $e');
    }
  }

  void _mostrarDialogoExecucao(Map<String, dynamic> item) {
    bool inspInterna = false;
    bool inspRosca = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Inspeção: ${item['idCrachaTemporario']}',
              style: TextStyle(color: _corSetor)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  title: const Text('Inspeção Interna OK?'),
                  value: inspInterna,
                  onChanged: (v) => setStateDialog(() => inspInterna = v!),
                ),
                CheckboxListTile(
                  title: const Text('Rosca em bom estado?'),
                  value: inspRosca,
                  onChanged: (v) => setStateDialog(() => inspRosca = v!),
                ),
                const Divider(),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: (inspInterna && inspRosca)
                  ? () => _confirmarSaque(item)
                  : null,
              style:
              ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('APROVAR',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final empresaId = context.read<UsuarioProvider>().usuario?.empresaId ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Execução: Saque'),
        backgroundColor: _corSetor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () =>
              Navigator.of(context).popUntil((r) => r.isFirst),
        ),
        actions: [
          const SeletorOperador(estacao: EstacaoProducao.saque),
          IconButton(
            icon: const Icon(Icons.shopping_cart_checkout),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => TelaCriarRequisicao(
                  osPrePreenchida: widget.numeroLote,
                  ccPrePreenchido:
                  MapeadorCustos.obterCC('MANUTENÇÃO DE COMPONENTES'),
                  subTipoPrePreenchido: 'OS',
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.red.shade50,
            child: CampoComScanner(
              controller: _scannerController,
              label: 'Bipar Crachá para Saque',
              onSubmitted: _processarBipe,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: context
                  .read<ItemOsProvider>()
                  .streamItensPorOsEStatus(
                  widget.numeroLote, 'aguardando_saque_valvula', empresaId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final itens = snapshot.data!;
                if (itens.isEmpty) {
                  return const Center(child: Text('Lote concluído!'));
                }

                return ListView.builder(
                  itemCount: itens.length,
                  padding: const EdgeInsets.all(10),
                  itemBuilder: (ctx, i) {
                    final item = itens[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.qr_code_scanner,
                            color: Colors.red),
                        title: Text(
                            'Crachá: ${item['idCrachaTemporario']}'),
                        subtitle:
                        Text('Agente: ${item['tipoAgente']}'),
                        trailing: BotaoCondenar(
                            item: item, etapa: 'saque_valvula'),
                        onTap: () => _mostrarDialogoExecucao(item),
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