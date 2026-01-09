// Salve como: lib/telas/producao/tela_criar_os.dart
// (VERSÃO CORRIGIDA - Salva itens na raiz 'itens_os')

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:protecin_producao/models/item_os.dart';
import 'package:protecin_producao/models/ordem_servico.dart';
import 'package:protecin_producao/models/parceiro.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/widgets/autocomplete_parceiro.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/widgets/dialog_casamento.dart';

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

  Future<void> _adicionarItem() async {
    final usuario = Provider.of<UsuarioProvider>(context, listen: false).usuario;
    if (usuario == null || _clienteSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o Cliente antes de adicionar itens.')),
      );
      return;
    }

    final ItemOS? novoItem = await showDialog<ItemOS>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return DialogCasamento(
          cliente: _clienteSelecionado!,
          empresaId: usuario.empresaId,
        );
      },
    );

    if (novoItem != null) {
      setState(() {
        _itensDaOS.add(novoItem);
      });
    }
  }

  Future<void> _finalizarOS() async {
    if (_clienteSelecionado == null || _itensDaOS.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Preencha o cliente e adicione pelo menos 1 item.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final usuario = Provider.of<UsuarioProvider>(context, listen: false).usuario;
    if (usuario == null) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 1. Ler contador
        final configRef = FirebaseFirestore.instance.collection('config').doc('contadores');
        final configDoc = await transaction.get(configRef);

        int proximoNumero = 1;
        if (configDoc.exists && configDoc.data()!.containsKey('ultima_os')) {
          proximoNumero = configDoc.get('ultima_os') + 1;
        }
        final String idFormatado = proximoNumero.toString().padLeft(5, '0');

        // 2. Referência da Nova OS
        final osRef = FirebaseFirestore.instance.collection('ordens_servico').doc(idFormatado);

        final novaOS = OrdemServico(
          id: idFormatado,
          numeroOS: idFormatado, // Garante que o número visual seja salvo
          empresaId: usuario.empresaId,
          clienteId: _clienteSelecionado!.id,
          clienteNome: _clienteSelecionado!.nome,
          statusLote: StatusLoteOS.emProducao,
          dataEntrada: DateTime.now(),
          usuarioNomeEntrada: usuario.nome,
        );

        final osMap = novaOS.toJson();
        // Força os campos que o app usa para exibir
        osMap['statusLote'] = 'na_descarga';
        osMap['etapaAtual'] = 'descarga';
        osMap['quantidadeTotal'] = _itensDaOS.length;
        osMap['numeroSequencial'] = proximoNumero;
        osMap['observacoes'] = _obsController.text.trim();

        // 3. Gravar OS
        transaction.set(osRef, osMap);

        // 4. Gravar Itens (AGORA NA COLEÇÃO RAIZ 'itens_os')
        for (final item in _itensDaOS) {
          // --- CORREÇÃO PRINCIPAL: Salva na raiz ---
          final itemRef = FirebaseFirestore.instance.collection('itens_os').doc();

          final itemJson = item.toJson();
          itemJson['osId'] = idFormatado; // VÍNCULO FUNDAMENTAL
          itemJson['numeroOS'] = idFormatado; // Facilitador visual
          itemJson['clienteNome'] = _clienteSelecionado!.nome;
          itemJson['status'] = 'aguardando_descarga'; // Status inicial correto
          itemJson['statusAtual'] = 'emProducao';
          itemJson['dataEntrada'] = FieldValue.serverTimestamp();

          transaction.set(itemRef, itemJson);

          // Atualizar equipamento original (Status de ocupado)
          final equipRef = FirebaseFirestore.instance.collection('equipamentos').doc(item.equipamentoId);
          transaction.update(equipRef, {
            'status': 'em_manutencao',
            'idRastreioInterno': item.idCrachaTemporario,
            'osIdAtual': idFormatado,
            'itemIdAtual': itemRef.id,
          });
        }

        // 5. Atualizar contador
        transaction.set(configRef, {'ultima_os': proximoNumero}, SetOptions(merge: true));
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OS Gerada com Sucesso!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
                            title: Text('${item.tipoAgente} - ${item.idCrachaTemporario}'),
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