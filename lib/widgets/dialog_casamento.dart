// Salve como: lib/widgets/dialog_casamento.dart

import 'package:flutter/material.dart';
import 'package:protecin_producao/models/equipamento.dart';
import 'package:protecin_producao/models/item_os.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/telas/producao/tela_cadastro_equipamento.dart';
import 'package:protecin_producao/models/parceiro.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';

class DialogCasamento extends StatefulWidget {
  final Parceiro cliente;
  final String empresaId;

  const DialogCasamento({
    super.key,
    required this.cliente,
    required this.empresaId,
  });

  @override
  State<DialogCasamento> createState() => _DialogCasamentoState();
}

class _DialogCasamentoState extends State<DialogCasamento> {
  final _dossieController = TextEditingController();
  final _crachaController = TextEditingController();

  Equipamento? _equipamentoEncontrado;
  bool _isLoadingDossie = false;
  String? _errorDossie;

  Future<void> _buscarDossie() async {
    setState(() {
      _isLoadingDossie = true;
      _errorDossie = null;
      _equipamentoEncontrado = null;
    });

    final idBusca = _dossieController.text.trim().toUpperCase();
    if (idBusca.isEmpty) {
      setState(() {
        _isLoadingDossie = false;
        _errorDossie = 'Digite o Ativo Fixo.';
      });
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('equipamentos')
          .where('empresaId', isEqualTo: widget.empresaId)
          .where('clienteId', isEqualTo: widget.cliente.id)
          .where('ativoFixo', isEqualTo: idBusca)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final equipamento = Equipamento.fromJson(
          snapshot.docs.first.data(),
          snapshot.docs.first.id,
        );

        setState(() => _equipamentoEncontrado = equipamento);
      } else {
        if (!mounted) return;

        final bool cadastrarAgora = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Não encontrado'),
            content: Text('O Ativo "$idBusca" não existe. Cadastrar agora?'),
            actions: [
              TextButton(child: const Text('Não'), onPressed: () => Navigator.of(ctx).pop(false)),
              ElevatedButton(child: const Text('Sim'), onPressed: () => Navigator.of(ctx).pop(true)),
            ],
          ),
        ) ?? false;

        if (cadastrarAgora) {
          final novoEquipamento = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => TelaCadastroEquipamento(
                clientePreSelecionado: widget.cliente,
                numeroCascoPreenchido: idBusca,
              ),
            ),
          );

          if (novoEquipamento != null && novoEquipamento is Equipamento) {
            setState(() {
              _equipamentoEncontrado = novoEquipamento;
              _errorDossie = null;
            });
          }
        } else {
          setState(() => _errorDossie = 'Equipamento não encontrado.');
        }
      }
    } catch (e) {
      setState(() => _errorDossie = 'Erro: $e');
    } finally {
      setState(() => _isLoadingDossie = false);
    }
  }

  void _realizarCasamento() {
    final idRastreio = _crachaController.text.trim();
    if (_equipamentoEncontrado == null || idRastreio.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final usuario = Provider.of<UsuarioProvider>(context, listen: false).usuario;
    if (usuario == null) return;

    final novoItemOS = ItemOS(
      id: '',
      osId: '',
      equipamentoId: _equipamentoEncontrado!.id,
      idCrachaTemporario: idRastreio,
      tipoAgente: _equipamentoEncontrado!.tipo,
      empresaId: widget.empresaId,

      // --- AQUI ESTAVA O ERRO ---
      statusAtual: StatusOS.emCadastro,
      statusOriginal: 'emCadastro', // <<< ADICIONEI ESTA LINHA (O ESPIÃO)
      // --------------------------

      historicoEtapas: [
        HistoricoEtapa(
          etapa: StatusOS.emCadastro,
          dataHora: DateTime.now(),
          usuarioNome: usuario.nome,
        )
      ],
    );

    Navigator.of(context).pop(novoItemOS);
  }

  @override
  Widget build(BuildContext context) {
    bool podeCasar = _equipamentoEncontrado != null && _crachaController.text.trim().isNotEmpty;

    _crachaController.addListener(() {
      if(mounted) setState((){});
    });

    return AlertDialog(
      title: const Text('Adicionar Item (Bipar)'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('1. Ativo Fixo (Equipamento)', style: TextStyle(fontWeight: FontWeight.bold)),
            TextFormField(
              controller: _dossieController,
              decoration: InputDecoration(
                labelText: 'Digite ou Bipe o Ativo',
                suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _buscarDossie),
                errorText: _errorDossie,
              ),
            ),
            if (_isLoadingDossie) const LinearProgressIndicator(),
            if (_equipamentoEncontrado != null)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green)
                ),
                child: Text(
                  '✅ OK!\nAtivo: ${_equipamentoEncontrado!.ativoFixo}\nTipo: ${_equipamentoEncontrado!.tipo}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 24),
            const Text('2. Etiqueta Temporária (Rastreio)', style: TextStyle(fontWeight: FontWeight.bold)),
            TextFormField(
              controller: _crachaController,
              decoration: const InputDecoration(labelText: 'Digite o ID de Rastreio'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop()),
        ElevatedButton(onPressed: podeCasar ? _realizarCasamento : null, child: const Text('Adicionar')),
      ],
    );
  }
}