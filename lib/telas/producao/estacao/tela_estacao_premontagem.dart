import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/models/usuario.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/telas/estoque/tela_criar_requisicao.dart';
import 'package:protecin_producao/utils/mapeador_custos.dart';
import 'package:protecin_producao/widgets/seletor_operador.dart';

class TelaEstacaoPremontagem extends StatefulWidget {
  final String osId;
  const TelaEstacaoPremontagem({super.key, required this.osId});

  @override
  State<TelaEstacaoPremontagem> createState() => _TelaEstacaoPremontagemState();
}

class _TelaEstacaoPremontagemState extends State<TelaEstacaoPremontagem> {
  bool _processando = false;
  String _statusEnvio = '';

  // Stream estável — criada em didChangeDependencies quando empresaId estiver pronto.
  // CORREÇÃO SESSÃO 22: initState usava streamItensPorOs (sem empresaId no .where())
  // → Firestore rejeitava com permission-denied → StreamBuilder ficava girando para sempre.
  // Agora usa streamItensPorOsEStatus com empresaId, padrão correto de todas as estações.
  Stream<List<Map<String, dynamic>>>? _streamItens;
  String? _empresaIdEscutando;

  // Snapshot local — permite que o FAB use os dados sem nova query ao Firestore
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
          .streamItensPorOsEStatus(widget.osId, 'aguardando_pre_montagem', empresaId);
    }
  }

  Future<void> _liberarLoteCompleto(
      List<Map<String, dynamic>> itens,
      bool imprimirGarantia,
      bool imprimirNR23,
      String impressora) async {
    final usuario =
        Provider.of<UsuarioProvider>(context, listen: false).usuario;
    final operador = usuario?.nome ?? 'Sistema';

    setState(() {
      _processando = true;
      _statusEnvio = 'Liberando lote...';
    });

    final provider = context.read<ItemOsProvider>();

    try {
      await provider.liberarLotePremontagem(
        osId: widget.osId,
        itens: itens,
        operador: operador,
      );

      setState(() => _statusEnvio = 'Enviando ordem de impressão...');

      await provider.criarPrintJob(
        itensIds: itens.map((item) => item['id'] as String).toList(),
        osId: widget.osId,
        imprimirGarantia: imprimirGarantia,
        imprimirNR23: imprimirNR23,
        impressora: impressora,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ordem enviada! Acompanhe a impressão no computador.'),
          backgroundColor: Colors.blue,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  void _exibirConfirmacaoImpressao(List<Map<String, dynamic>> itens) {
    bool imprimirGarantia = true;
    bool imprimirNR23 = true;
    String impressoraSelecionada = 'Argox01';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Configurações de Impressão'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text('Imprimir Garantia'),
                    value: imprimirGarantia,
                    onChanged: (v) =>
                        setStateDialog(() => imprimirGarantia = v!),
                  ),
                  CheckboxListTile(
                    title: const Text('Imprimir NR 23'),
                    value: imprimirNR23,
                    onChanged: (v) => setStateDialog(() => imprimirNR23 = v!),
                  ),
                  const Divider(),
                  const Text('Selecione a Impressora:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: impressoraSelecionada,
                    items: ['Argox01', 'Argox02', 'Argox03']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) =>
                        setStateDialog(() => impressoraSelecionada = v!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCELAR'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo),
                  onPressed: () {
                    Navigator.pop(context);
                    _liberarLoteCompleto(itens, imprimirGarantia,
                        imprimirNR23, impressoraSelecionada);
                  },
                  child: const Text('LIBERAR E IMPRIMIR',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pré-Montagem: Etiquetas'),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
        actions: [
          const SeletorOperador(estacao: EstacaoProducao.premontagem),
          IconButton(
            icon: const Icon(Icons.inventory_2),
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
      body: _processando
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(_statusEnvio),
          ],
        ),
      )
          : StreamBuilder<List<Map<String, dynamic>>>(
        stream: _streamItens,
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(
              child: Text('Erro: ${snap.error}',
                  style: const TextStyle(color: Colors.red)),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          _itensSnapshot = snap.data!;
          final itens = _itensSnapshot;

          if (itens.isEmpty) {
            return const Center(
                child: Text('Todos os itens liberados!'));
          }

          return ListView.builder(
            itemCount: itens.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (c, i) => Card(
              child: ListTile(
                leading:
                const Icon(Icons.qr_code, color: Colors.indigo),
                title:
                Text('Crachá: ${itens[i]['idCrachaTemporario']}'),
                subtitle: Text('Agente: ${itens[i]['tipoAgente']}'),
              ),
            ),
          );
        },
      ),
      floatingActionButton: _processando
          ? null
          : FloatingActionButton.extended(
        backgroundColor: Colors.indigo.shade800,
        icon: const Icon(Icons.print, color: Colors.white),
        label: const Text('LIBERAR LOTE E IMPRIMIR',
            style: TextStyle(color: Colors.white)),
        onPressed: () {
          // Usa o snapshot local — sem nova query ao Firestore
          if (_itensSnapshot.isNotEmpty) {
            _exibirConfirmacaoImpressao(_itensSnapshot);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'Nenhum item pendente para liberação neste lote.')));
          }
        },
      ),
    );
  }
}