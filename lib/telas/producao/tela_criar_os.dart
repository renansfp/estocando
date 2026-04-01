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
      bool jaEstaNaLista = _itensDaOS.any((item) => item.equipamentoId == novoItem.equipamentoId);

      if (jaEstaNaLista) {
        _mostrarAlertaErro('Duplicidade Local', 'Este equipamento JÁ ESTÁ nesta lista de OS.');
        return;
      }

      // --- BLINDAGEM 2: DUPLICIDADE GLOBAL (Em outra OS) ---
      // Consulta o banco para ver se ele está 'ativo' ou 'em_manutencao'
      bool estaLivre = await _verificarDisponibilidadeNoBanco(novoItem.equipamentoId);

      if (!estaLivre) {
        // Se não estiver livre, o alerta já foi exibido dentro da função de verificação
        return;
      }

      // Se passou pelas duas barreiras, adiciona!
      setState(() {
        _itensDaOS.add(novoItem);
      });
    }
  }

  // --- FUNÇÃO AUXILIAR PARA CHECAR O BANCO ---
  Future<bool> _verificarDisponibilidadeNoBanco(String equipamentoId) async {
    // Mostra um loading rápido para não travar a UI
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final doc = await FirebaseFirestore.instance.collection('equipamentos').doc(equipamentoId).get();

      // Fecha o loading
      Navigator.of(context).pop();

      if (!doc.exists) return true; // Se não existe, teoricamente está livre (ou é erro de cadastro)

      final data = doc.data() as Map<String, dynamic>;

      // Verifica o status ou se tem uma OS vinculada
      String status = data['status'] ?? 'ativo';
      String? osAtual = data['osIdAtual'];

      // REGRA: Se status for diferente de 'ativo' OU tiver um ID de OS vinculado, está ocupado!
      if (status == 'em_manutencao' || (osAtual != null && osAtual.isNotEmpty)) {
        _mostrarAlertaErro(
            'Equipamento Ocupado!',
            'Este cilindro já está na produção.\nStatus: $status\nOS Atual: ${osAtual ?? "Erro"}'
        );
        return false;
      }

      return true; // Está livre
    } catch (e) {
      Navigator.of(context).pop(); // Fecha loading no erro
      return false; // Na dúvida, bloqueia
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
    // Validação Inicial
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
      final firestore = FirebaseFirestore.instance;

      // 1. Criar o "Pacote" (Batch)
      final batch = firestore.batch();

      // 2. Ler o contador (Fora da transação para evitar o crash)
      // Nota: Em sistemas gigantes isso poderia ter risco, mas para seu uso é seguro.
      final configRef = firestore.collection('config').doc('contadores');
      final configDoc = await configRef.get();

      int proximoNumero = 1;
      if (configDoc.exists && configDoc.data() != null && configDoc.data()!.containsKey('ultima_os')) {
        // Forçamos ser um int para garantir
        final val = configDoc.get('ultima_os');
        proximoNumero = (val is int ? val : int.tryParse(val.toString()) ?? 0) + 1;
      }
      final String idFormatado = proximoNumero.toString().padLeft(5, '0');

      // 3. Preparar a OS
      final osRef = firestore.collection('ordens_servico').doc(idFormatado);

      final novaOS = OrdemServico(
        id: idFormatado,
        numeroOS: idFormatado,
        empresaId: usuario.empresaId,
        clienteId: _clienteSelecionado!.id,
        clienteNome: _clienteSelecionado!.nome,
        statusLote: StatusLoteOS.emProducao,
        dataEntrada: DateTime.now(),
        usuarioNomeEntrada: usuario.nome,
      );

      final osMap = novaOS.toJson();
      osMap['statusLote'] = 'na_descarga';
      osMap['etapaAtual'] = 'descarga';
      osMap['quantidadeTotal'] = _itensDaOS.length;
      osMap['numeroSequencial'] = proximoNumero;
      osMap['observacoes'] = _obsController.text.trim();

      // Adiciona a OS no pacote
      batch.set(osRef, osMap);

      // 4. Preparar os Itens
      for (final item in _itensDaOS) {
        final itemRef = firestore.collection('itens_os').doc();

        final itemJson = item.toJson();
        itemJson['osId'] = idFormatado;
        itemJson['numeroOS'] = idFormatado;
        itemJson['clienteNome'] = _clienteSelecionado!.nome;
        itemJson['status'] = 'aguardando_descarga';
        itemJson['statusAtual'] = 'emProducao';
        itemJson['dataEntrada'] = FieldValue.serverTimestamp();

        // Adiciona o item no pacote
        batch.set(itemRef, itemJson);

        // Atualizar equipamento (Usando merge para evitar crash se não existir)
        final equipRef = firestore.collection('equipamentos').doc(item.equipamentoId);
        batch.set(equipRef, {
          'status': 'em_manutencao',
          'osIdAtual': idFormatado,
          'itemIdAtual': itemRef.id,
        }, SetOptions(merge: true));
      }

      // 5. Atualizar o contador no pacote
      batch.set(configRef, {'ultima_os': proximoNumero}, SetOptions(merge: true));

      // --- O MOMENTO MÁGICO ---
      // Envia tudo de uma vez para o Firebase
      await batch.commit();

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
      print("ERRO BATCH: $e");
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