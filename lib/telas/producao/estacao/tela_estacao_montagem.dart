import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_execucao_montagem.dart';
import 'package:protecin_producao/telas/estoque/tela_criar_requisicao.dart';
import 'package:protecin_producao/utils/mapeador_custos.dart';

class TelaEstacaoMontagem extends StatefulWidget {
  final String osId;
  const TelaEstacaoMontagem({super.key, required this.osId});

  @override
  State<TelaEstacaoMontagem> createState() => _TelaEstacaoMontagemState();
}

class _TelaEstacaoMontagemState extends State<TelaEstacaoMontagem> {
  final TextEditingController _scannerController = TextEditingController();
  final Color corSetor = Colors.deepPurple.shade700;

  String _limparCodigo(String valor) {
    String limpo = valor.trim().toUpperCase();
    if (limpo.contains('HTTP')) limpo = limpo.split('/').last;
    return limpo.replaceAll('R-', '');
  }

  // Agora recebe Map em vez de DocumentSnapshot
  void _irParaExecucao(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TelaExecucaoMontagem(
          item: item,
          osId: widget.osId,
        ),
      ),
    );
  }

  Future<void> _processarBipe(String codigo) async {
    if (codigo.isEmpty) return;
    String idCracha = _limparCodigo(codigo);

    final item = await context.read<ItemOsProvider>().buscarItemPorCracha(
      widget.osId,
      idCracha,
      'aguardando_montagem',
    );

    if (item != null) {
      _irParaExecucao(item);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Crachá não encontrado nesta OS ou já finalizado.')),
        );
      }
    }
    _scannerController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Montagem Final: OS ${widget.osId}'),
        backgroundColor: corSetor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2),
            tooltip: 'Requisição para o Setor',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => TelaCriarRequisicao(
                  ccPrePreenchido: MapeadorCustos.obterCC('MONTAGEM'),
                  subTipoPrePreenchido: 'Colaborador',
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart_checkout),
            tooltip: 'Material para esta OS',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => TelaCriarRequisicao(
                  osPrePreenchida: widget.osId,
                  ccPrePreenchido: MapeadorCustos.obterCC('MONTAGEM'),
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
            padding: const EdgeInsets.all(16.0),
            color: Colors.deepPurple.shade50,
            child: CampoComScanner(
              controller: _scannerController,
              label: 'Bipar Crachá para Selagem',
              onSubmitted: _processarBipe,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: context
                  .read<ItemOsProvider>()
                  .streamItensPorOsEStatus(widget.osId, 'aguardando_montagem'),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final itens = snapshot.data!;
                if (itens.isEmpty) return _buildConcluido();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: itens.length,
                  itemBuilder: (context, index) {
                    final item = itens[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: corSetor.withOpacity(0.1),
                          child: Icon(Icons.verified, color: corSetor),
                        ),
                        title: Text('Crachá: ${item['idCrachaTemporario']}',
                            style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '${item['tipoAgente']} ${item['capacidade']} - Aguardando Lacração'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () => _irParaExecucao(item),
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

  Widget _buildConcluido() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded,
              size: 100, color: Colors.green.shade600),
          const SizedBox(height: 20),
          const Text('OS Montada e Selada!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('O lote já pode seguir para a Expedição.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('VOLTAR PARA A FILA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: corSetor,
              foregroundColor: Colors.white,
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}