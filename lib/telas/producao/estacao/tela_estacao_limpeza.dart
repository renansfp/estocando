// lib/telas/producao/estacao/tela_estacao_limpeza.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/widgets/botao_condenar.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_triagem_limpeza.dart';
import 'package:protecin_producao/telas/estoque/tela_criar_requisicao.dart';
import 'package:protecin_producao/utils/mapeador_custos.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';

class TelaEstacaoLimpeza extends StatefulWidget {
  final String osId;
  const TelaEstacaoLimpeza({Key? key, required this.osId}) : super(key: key);

  @override
  _TelaEstacaoLimpezaState createState() => _TelaEstacaoLimpezaState();
}

class _TelaEstacaoLimpezaState extends State<TelaEstacaoLimpeza> {
  final TextEditingController _scannerController = TextEditingController();

  String _limparCodigo(String valor) {
    String limpo = valor.trim().toUpperCase();
    if (limpo.contains('HTTP')) limpo = limpo.split('/').last;
    return limpo.replaceAll('R-', '');
  }

  Future<void> _processarBipe(String codigo) async {
    if (codigo.isEmpty) return;
    String idCracha = _limparCodigo(codigo);

    try {
      final empresaId = context.read<UsuarioProvider>().usuario?.empresaId ?? '';
      final item = await context.read<ItemOsProvider>().buscarItemPorCracha(
        widget.osId,
        idCracha,
        'aguardando_limpeza', empresaId,
      );

      if (item != null) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TelaTriagemLimpeza(
              itemOsId: item['id'],
              idRastreio: idCracha,
              tipoAgente: item['tipoAgente'] ?? '?',
              equipamentoId: item['equipamentoId'] ?? '',
              osId: widget.osId,
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Crachá não encontrado nesta OS ou já processado.')),
        );
      }
    } finally {
      _scannerController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final empresaId = context.read<UsuarioProvider>().usuario?.empresaId ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estação: Limpeza & Triagem'),
        backgroundColor: const Color(0xFF1565C0),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            color: Colors.blue.shade50,
            child: CampoComScanner(
              controller: _scannerController,
              label: 'Bipar Crachá do Cilindro',
              onSubmitted: _processarBipe,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: context
                  .read<ItemOsProvider>()
                  .streamItensPorOsEStatus(widget.osId, 'aguardando_limpeza', empresaId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final itens = snapshot.data!;
                if (itens.isEmpty) return _buildTelaConclusao();

                return ListView.builder(
                  itemCount: itens.length,
                  itemBuilder: (context, index) {
                    final item = itens[index];
                    final idCracha = item['idCrachaTemporario'] ?? '???';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.cleaning_services,
                            color: Color(0xFF1565C0)),
                        title: Text('Crachá: $idCracha'),
                        subtitle: Text('Agente: ${item['tipoAgente']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BotaoCondenar(item: item, etapa: 'limpeza'),
                            IconButton(
                              icon: const Icon(Icons.shopping_cart_checkout,
                                  color: Colors.blue),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TelaCriarRequisicao(
                                      osPrePreenchida: widget.osId,
                                      ccPrePreenchido: MapeadorCustos.obterCC(
                                          'DESCARGA E PREPARAÇÃO'),
                                      subTipoPrePreenchido: 'OS',
                                    ),
                                  ),
                                );
                              },
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TelaTriagemLimpeza(
                              itemOsId: item['id'],
                              idRastreio: idCracha,
                              tipoAgente: item['tipoAgente'],
                              equipamentoId: item['equipamentoId'] ?? '',
                              osId: widget.osId,
                            ),
                          ),
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

  Widget _buildTelaConclusao() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: Colors.green),
          const SizedBox(height: 20),
          const Text('Limpeza Concluída!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('Lote enviado para a Lixa.'),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('VOLTAR PARA A FILA'),
          ),
        ],
      ),
    );
  }
}