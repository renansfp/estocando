// lib/telas/producao/estacao/tela_estacao_th.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/widgets/botao_condenar.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_ensaio_th.dart';
import 'package:protecin_producao/telas/estoque/tela_criar_requisicao.dart';
import 'package:protecin_producao/utils/mapeador_custos.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';

class TelaEstacaoTH extends StatefulWidget {
  final String osIdAtual;
  const TelaEstacaoTH({super.key, required this.osIdAtual});

  @override
  State<TelaEstacaoTH> createState() => _TelaEstacaoTHState();
}

class _TelaEstacaoTHState extends State<TelaEstacaoTH> {
  final TextEditingController _scannerController = TextEditingController();

  String _limparCodigo(String valor) {
    String limpo = valor.trim().toUpperCase();
    if (limpo.contains('HTTP')) limpo = limpo.split('/').last;
    return limpo.replaceAll('R-', '');
  }

  Future<void> _processarBipe(String codigo) async {
    if (codigo.isEmpty) return;
    final idCracha = _limparCodigo(codigo);

    try {
      final empresaId = context.read<UsuarioProvider>().usuario?.empresaId ?? '';
      final item = await context.read<ItemOsProvider>().buscarItemPorCracha(
        widget.osIdAtual,
        idCracha,
        'aguardando_th', empresaId,
      );

      if (item != null) {
        _irParaEnsaio(item);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Crachá não encontrado nesta OS ou já processado.')),
          );
        }
      }
    } finally {
      _scannerController.clear();
    }
  }

  void _irParaEnsaio(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TelaEnsaioTH(
          itemOsId: item['id'],
          osId: widget.osIdAtual,
          dadosItem: item,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final empresaId = context.read<UsuarioProvider>().usuario?.empresaId ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bancada: Teste Hidrostático'),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
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
              label: 'Bipar Crachá para TH',
              onSubmitted: _processarBipe,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: context
                  .read<ItemOsProvider>()
                  .streamItensPorOsEStatus(widget.osIdAtual, 'aguardando_th', empresaId),
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
                        leading:
                        Icon(Icons.science, color: Colors.blue.shade900),
                        title: Text('Crachá: $idCracha'),
                        subtitle: Text(
                            'Agente: ${item['tipoAgente']} | Cap: ${item['capacidade'] ?? item['carga'] ?? ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BotaoCondenar(item: item, etapa: 'th'),
                            IconButton(
                              icon: const Icon(Icons.shopping_cart_checkout,
                                  color: Colors.blue),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TelaCriarRequisicao(
                                      osPrePreenchida: widget.osIdAtual,
                                      ccPrePreenchido:
                                      MapeadorCustos.obterCC(
                                          'TESTE HIDROSTÁTICO'),
                                      subTipoPrePreenchido: 'OS',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        onTap: () => _irParaEnsaio(item),
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
          const Text('Teste Hidro Concluído!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('Todos os itens foram processados.'),
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