// lib/telas/producao/estacao/tela_estacao_lixa.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/models/usuario.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/widgets/botao_condenar.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';
import 'package:protecin_producao/widgets/seletor_operador.dart';

class TelaEstacaoLixa extends StatefulWidget {
  final String osId;
  const TelaEstacaoLixa({Key? key, required this.osId}) : super(key: key);

  @override
  _TelaEstacaoLixaState createState() => _TelaEstacaoLixaState();
}

class _TelaEstacaoLixaState extends State<TelaEstacaoLixa> {
  final Color _corSetor = Colors.blueGrey.shade700;
  final TextEditingController _scannerController = TextEditingController();
  bool _processando = false;

  Stream<List<Map<String, dynamic>>>? _streamItens;
  String? _empresaIdEscutando;

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
          .streamItensPorOsEStatus(widget.osId, 'aguardando_lixa', empresaId);
    }
  }

  String _limparCodigo(String valor) {
    String limpo = valor.trim().toUpperCase();
    if (limpo.contains('HTTP')) limpo = limpo.split('/').last;
    return limpo.replaceAll('R-', '');
  }

  Future<void> _confirmarLixamento(Map<String, dynamic> item) async {
    if (_processando) return;
    setState(() => _processando = true);

    try {
      final codigo = item['idCrachaTemporario'] ?? '???';
      final List<String> roteiro = List<String>.from(item['roteiro'] ?? []);

      int indexLixa = roteiro.indexOf('lixa');
      if (indexLixa == -1 || indexLixa >= roteiro.length - 1) {
        throw 'Erro: Próxima etapa não encontrada no roteiro.';
      }
      String proximaEstacao = roteiro[indexLixa + 1];
      final operador = context.read<UsuarioProvider>().operadorAtivo?.nome ?? 'Operador';

      await context.read<ItemOsProvider>().confirmarEtapa(
        itemId: item['id'],
        dadosItem: {
          'lixa': {
            'data': DateTime.now(),
            'operador': operador,
          }
        },
        osId: widget.osId,
        statusPendente: 'aguardando_lixa',
        proximaEstacao: proximaEstacao,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Cilindro $codigo finalizado -> Seguindo para $proximaEstacao'),
          backgroundColor: Colors.green,
          duration: const Duration(milliseconds: 1000),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  void _processarBipe(String codigo) async {
    if (codigo.isEmpty) return;
    String idCracha = _limparCodigo(codigo);

    final empresaId = context.read<UsuarioProvider>().usuario?.empresaId ?? '';
    final item = await context.read<ItemOsProvider>().buscarItemPorCracha(
      widget.osId,
      idCracha,
      'aguardando_lixa', empresaId,
    );

    if (item != null) {
      _confirmarLixamento(item);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Crachá inválido para lixa.')),
        );
      }
    }
    _scannerController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Execução: Lixa/Jato'),
        backgroundColor: _corSetor,
        foregroundColor: Colors.white,
        actions: const [
          SeletorOperador(estacao: EstacaoProducao.lixa),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            color: Colors.blueGrey.shade50,
            child: CampoComScanner(
              controller: _scannerController,
              label: 'Bipar Crachá para Lixar',
              onSubmitted: _processarBipe,
            ),
          ),
          if (_processando) const LinearProgressIndicator(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _streamItens,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final itens = snapshot.data!;
                if (itens.isEmpty) return _buildConcluido();

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: itens.length,
                  itemBuilder: (context, index) {
                    final item = itens[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(Icons.build, color: _corSetor),
                        title: Text('Crachá: ${item['idCrachaTemporario']}'),
                        subtitle: Text('Agente: ${item['tipoAgente']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BotaoCondenar(item: item, etapa: 'lixa'),
                            IconButton(
                              icon: const Icon(Icons.check_circle,
                                  color: Colors.green),
                              onPressed: () => _confirmarLixamento(item),
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

  Widget _buildConcluido() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified, size: 80, color: Colors.green),
          const SizedBox(height: 20),
          const Text('Etapa Lixa Concluída!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
