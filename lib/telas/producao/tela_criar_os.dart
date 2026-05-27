// Salve como: lib/telas/producao/tela_criar_os.dart
// (VERSÃO CORRIGIDA - Salva itens na raiz 'itens_os')

import 'package:flutter/material.dart';
import 'package:protecin_producao/models/item_os.dart';
import 'package:protecin_producao/models/ordem_servico.dart';
import 'package:protecin_producao/models/parceiro.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/widgets/autocomplete_parceiro.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/widgets/dialog_casamento.dart';
import 'package:protecin_producao/provider/ordem_servico_provider.dart';
import 'package:protecin_producao/provider/equipamento_provider.dart';

class TelaCriarOS extends StatefulWidget {
  const TelaCriarOS({super.key});

  @override
  State<TelaCriarOS> createState() => _TelaCriarOSState();
}

class _TelaCriarOSState extends State<TelaCriarOS> {
  Parceiro? _clienteSelecionado;
  final List<ItemOS> _itensDaOS = [];
  final TextEditingController _obsController = TextEditingController();
  bool _isSaving = false;

  // Substitua a função _adicionarItem inteira por esta:
  Future<void> _adicionarItem() async {
    final usuario = Provider.of<UsuarioProvider>(context, listen: false).usuario;
    if (usuario == null || _clienteSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o Cliente antes de adicionar itens.')),
      );
      return;
    }

    // Abre o diálogo para escolher o equipamento (DialogCasamento)
    final ItemOS? novoItem = await showDialog<ItemOS>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return DialogCasamento(
          cliente: _clienteSelecionado!,
          empresaId: usuario.empresaId,
          itensJaAdicionados: _itensDaOS,
        );
      },
    );

    if (novoItem != null) {
      // --- BLINDAGEM 1: DUPLICIDADE LOCAL (Na mesma lista) ---
      // Verifica se o item já foi adicionado nesta tela agora
      final jaEstaNaLista = _itensDaOS
          .any((item) => item.equipamentoId == novoItem.equipamentoId);

      if (jaEstaNaLista) {
        _mostrarAlertaErro(
            'Duplicidade Local', 'Este equipamento JÁ ESTÁ nesta lista de OS.');
        return;
      }

      // A disponibilidade global já foi verificada dentro do DialogCasamento
      // (_buscarDossie checa status e osIdAtual). Não é necessária uma segunda
      // consulta ao Firebase aqui — ela apenas adiciona latência sem benefício.
      setState(() {
        _itensDaOS.add(novoItem);
      });
    }
  }

  // --- FUNÇÃO AUXILIAR PARA CHECAR O BANCO ---
  Future<bool> _verificarDisponibilidadeNoBanco(String equipamentoId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final livre = await context
          .read<EquipamentoProvider>()
          .verificarDisponibilidade(equipamentoId);

      if (!mounted) return false;
      Navigator.of(context).pop();

      if (!livre) {
        _mostrarAlertaErro(
          'Equipamento Ocupado!',
          'Este cilindro já está na produção.',
        );
      }
      return livre;
    } catch (e) {
      if (!mounted) return false;
      Navigator.of(context).pop();
      return false;
    }
  }

  void _mostrarAlertaErro(String titulo, String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo, style: const TextStyle(color: Colors.red)),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
        ],
      ),
    );
  }
  Future<void> _finalizarOS() async {
    if (_clienteSelecionado == null || _itensDaOS.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha o cliente e adicione pelo menos 1 item.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final usuario = Provider.of<UsuarioProvider>(context, listen: false).usuario;
    if (usuario == null) return;

    setState(() => _isSaving = true);

    final novaOS = OrdemServico(
      id: '',
      numeroOS: '',
      empresaId: usuario.empresaId,
      clienteId: _clienteSelecionado!.id,
      clienteNome: _clienteSelecionado!.nome,
      statusLote: StatusLoteOS.emProducao,
      dataEntrada: DateTime.now(),
      usuarioNomeEntrada: usuario.nome,
    );

    final numeroOS = await context.read<OrdemServicoProvider>().criarOS(
      os: novaOS,
      itens: _itensDaOS,
      cliente: _clienteSelecionado!,
      observacoes: _obsController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (numeroOS != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OS Gerada com Sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } else {
      final erro = context.read<OrdemServicoProvider>().erro;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(erro ?? 'Erro ao salvar OS.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = Provider.of<UsuarioProvider>(context, listen: false).usuario;
    if (usuario == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Ordem de Serviço'),
        backgroundColor: Colors.blueGrey.shade900,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('SALVAR E GERAR', style: TextStyle(color: Colors.white)),
            onPressed: _isSaving ? null : _finalizarOS,
          ),
        ],
      ),
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- DADOS DO CLIENTE ---
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('DADOS DO CLIENTE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const SizedBox(height: 8),
                    AutocompleteParceiroWidget(
                      empresaId: usuario.empresaId,
                      tipoParceiro: TipoParceiro.cliente,
                      label: 'Buscar Cliente...',
                      onParceiroSelected: (parceiro) => setState(() => _clienteSelecionado = parceiro),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- ITENS DA OS ---
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('EQUIPAMENTOS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                        Text('${_itensDaOS.length} itens', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(),
                    Container(
                      height: 300,
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
                      child: _itensDaOS.isEmpty
                          ? const Center(child: Text('Adicione equipamentos.', style: TextStyle(color: Colors.grey)))
                          : ListView.separated(
                        itemCount: _itensDaOS.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _itensDaOS[index];
                          return ListTile(
                            visualDensity: VisualDensity.compact,
                            leading: CircleAvatar(child: Text('${index + 1}')),
                            title: Text('${item.tipoAgente} ${item.toJson()['carga'] ?? ''}'), // Ex: PQS 4kg
                            subtitle: Text('Crachá: ${item.idCrachaTemporario}'),
                            trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _itensDaOS.removeAt(index))),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('ADICIONAR EQUIPAMENTO'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: _clienteSelecionado == null ? null : _adicionarItem,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}