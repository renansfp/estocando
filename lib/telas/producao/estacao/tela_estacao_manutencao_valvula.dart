import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/models/equipamento.dart';
import 'package:protecin_producao/models/usuario.dart';
import 'package:protecin_producao/provider/equipamento_provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';
import 'package:protecin_producao/telas/estoque/tela_criar_requisicao.dart';
import 'package:protecin_producao/utils/mapeador_custos.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/widgets/dialog_pecas_trocadas.dart';
import 'package:protecin_producao/widgets/seletor_operador.dart';

class TelaEstacaoManutencaoValvula extends StatefulWidget {
  final String usuarioNome;
  final String estacaoNome;
  final String osId;
  final String? codigoPreDefinido;

  const TelaEstacaoManutencaoValvula({
    super.key,
    required this.usuarioNome,
    required this.estacaoNome,
    required this.osId,
    this.codigoPreDefinido,
  });

  @override
  State<TelaEstacaoManutencaoValvula> createState() =>
      _TelaEstacaoManutencaoValvulaState();
}

class _TelaEstacaoManutencaoValvulaState
    extends State<TelaEstacaoManutencaoValvula> {
  final _controllerEtiqueta = TextEditingController();
  final _pesoVazioController = TextEditingController();
  final _pesoCheioController = TextEditingController();
  bool _buscando = false;
  bool _processando = false;
  Equipamento? _equipamentoAtual;
  // Trocamos DocumentSnapshot por Map
  Map<String, dynamic>? _itemOsAtual;

  @override
  void initState() {
    super.initState();
    _pesoVazioController.addListener(_calcularPesoFinal);
    if (widget.codigoPreDefinido != null) {
      WidgetsBinding.instance.addPostFrameCallback(
              (_) => _buscarItemPorBipe(widget.codigoPreDefinido!));
    }
  }

  @override
  void dispose() {
    _controllerEtiqueta.dispose();
    _pesoVazioController.dispose();
    _pesoCheioController.dispose();
    super.dispose();
  }

  String _limparCodigo(String valor) {
    String limpo = valor.trim().toUpperCase();
    if (limpo.contains('HTTP')) limpo = limpo.split('/').last;
    return limpo.replaceAll('R-', '');
  }

  void _calcularPesoFinal() {
    if (_equipamentoAtual == null) return;
    try {
      String texto = _pesoVazioController.text.replaceAll(',', '.');
      if (texto.isEmpty) {
        _pesoCheioController.clear();
        return;
      }
      double vazio = double.parse(texto);
      final numeros =
      RegExp(r'[0-9]+').firstMatch(_equipamentoAtual!.capacidade);
      if (numeros != null) {
        double carga = double.parse(numeros.group(0)!);
        _pesoCheioController.text =
            (vazio + carga).toStringAsFixed(2).replaceAll('.', ',');
      }
    } catch (e) {}
  }

  Future<void> _buscarItemPorBipe(String codigo) async {
    setState(() => _buscando = true);
    String idLimpo = _limparCodigo(codigo);
    _controllerEtiqueta.text = idLimpo;

    // Captura os providers antes de qualquer await — regra do BuildContext async
    final itemOsProvider = context.read<ItemOsProvider>();
    final equipamentoProvider = context.read<EquipamentoProvider>();

    try {
      // Busca o item via provider
      final empresaId = context.read<UsuarioProvider>().usuario?.empresaId ?? '';
      final item = await itemOsProvider.buscarItemPorCracha(
        widget.osId,
        idLimpo,
        'aguardando_manutencao_valvula', empresaId,
      );

      if (item != null) {
        // Busca o equipamento via EquipamentoProvider
        final equip = await equipamentoProvider
            .buscarPorId(item['equipamentoId']);

        if (equip != null) {
          setState(() {
            _itemOsAtual = item;
            _equipamentoAtual = equip;
            _pesoVazioController.clear();
            _pesoCheioController.clear();
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Cilindro não encontrado nesta OS ou status incorreto.')));
        }
      }
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _salvarManutencao() async {
    if (_equipamentoAtual == null || _itemOsAtual == null) return;
    if (_pesoVazioController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, informe o Peso Vazio.')));
      return;
    }

    // ── Captura providers ANTES de qualquer await ──────────────────────────
    final itemOsProvider  = context.read<ItemOsProvider>();
    final empresaId       = context.read<UsuarioProvider>().usuario?.empresaId ?? '';

    // ── Abre o dialog de peças ─────────────────────────────────────────────
    final pecasSelecionadas = await mostrarDialogPecasTrocadas(
      context               : context,
      // Peças disponíveis na manutenção de válvula CO₂
      legendasDisponiveis   : [1, 9, 13, 15, 26],
      // O-ring e Pera sempre trocados
      legendasObrigatorias  : [13, 15],
      tipoEquipamento       : _equipamentoAtual!.tipo,
      capacidadeEquipamento : _equipamentoAtual!.capacidade,
      fabricanteEquipamento : _equipamentoAtual!.fabricante,
    );

    // Operador cancelou
    if (pecasSelecionadas == null) return;

    setState(() => _processando = true);
    try {
      final List<String> roteiro =
      List<String>.from(_itemOsAtual!['roteiro'] ?? []);
      int indexAtual = roteiro.indexOf('manutencao_valvula');

      if (indexAtual == -1 || indexAtual >= roteiro.length - 1) {
        throw 'Roteiro incompleto ou etapa final alcançada.';
      }
      String proximaEstacao = roteiro[indexAtual + 1];

      // ── Salva pesagem e avança etapa ──────────────────────────────────────
      await itemOsProvider.salvarManutencaoValvula(
        itemId        : _itemOsAtual!['id'],
        osId          : widget.osId,
        equipamentoId : _equipamentoAtual!.id,
        operador      : context.read<UsuarioProvider>().operadorAtivo?.nome ?? widget.usuarioNome,
        pesoVazio     : _pesoVazioController.text,
        pesoCheioMeta : _pesoCheioController.text,
        proximaEstacao: proximaEstacao,
      );

      // ── Registra peças e baixa estoque ────────────────────────────────────
      if (pecasSelecionadas.isNotEmpty) {
        await itemOsProvider.registrarPecasTrocadas(
          itemId    : _itemOsAtual!['id'],
          osId      : widget.osId,
          empresaId : empresaId,
          pecas     : pecasSelecionadas,
        );
      }

      if (mounted) {
        setState(() {
          _equipamentoAtual = null;
          _itemOsAtual      = null;
          _controllerEtiqueta.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Manutenção finalizada!'),
            backgroundColor: Colors.teal));
        if (widget.codigoPreDefinido != null) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final empresaId = context.read<UsuarioProvider>().usuario?.empresaId ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bancada Válvula'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () =>
              Navigator.of(context).popUntil((r) => r.isFirst),
        ),
        actions: [
          const SeletorOperador(estacao: EstacaoProducao.manutencao),
          IconButton(
            icon: const Icon(Icons.inventory_2),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => TelaCriarRequisicao(
                  ccPrePreenchido:
                  MapeadorCustos.obterCC('MANUTENÇÃO DE COMPONENTES'),
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
            color: Colors.teal.shade50,
            child: CampoComScanner(
              controller: _controllerEtiqueta,
              label: 'Bipar Crachá',
              onSubmitted: _buscarItemPorBipe,
            ),
          ),
          if (_buscando || _processando) const LinearProgressIndicator(),
          if (_equipamentoAtual != null)
          // Visão de Trabalho — item bipado
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: Colors.teal.shade100,
                    child: ListTile(
                      title: Text(
                          '${_equipamentoAtual!.tipo} - ${_equipamentoAtual!.capacidade}'),
                      subtitle:
                      Text('Cilindro: ${_equipamentoAtual!.numeroCilindro}'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('PESAGEM CO2',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.teal)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pesoVazioController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Peso Vazio (Kg)',
                              border: OutlineInputBorder()),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _pesoCheioController,
                          readOnly: true,
                          decoration: const InputDecoration(
                              labelText: 'Meta Peso Cheio',
                              border: OutlineInputBorder(),
                              filled: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _salvarManutencao,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700),
                      child: const Text('FINALIZAR MANUTENÇÃO',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            )
          else
          // Visão de Espera — fila da OS
            Expanded(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Componentes Pendentes nesta OS:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.teal)),
                  ),
                  Expanded(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: context
                          .read<ItemOsProvider>()
                          .streamItensPorOsEStatus(
                          widget.osId, 'aguardando_manutencao_valvula', empresaId),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final itens = snapshot.data!;

                        if (itens.isEmpty) {
                          return const Center(
                              child: Text(
                                  'Nenhum item pendente para esta bancada.'));
                        }

                        return ListView.builder(
                          itemCount: itens.length,
                          itemBuilder: (context, index) {
                            final item = itens[index];
                            return ListTile(
                              leading: const Icon(Icons.qr_code_scanner,
                                  color: Colors.teal),
                              title: Text(
                                  'Crachá: ${item['idCrachaTemporario']}'),
                              subtitle: Text(
                                  'Cilindro: ${item['numeroCilindro'] ?? 'Não informado'}'),
                              onTap: () => _buscarItemPorBipe(
                                  item['idCrachaTemporario']),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}