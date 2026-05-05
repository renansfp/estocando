// lib/widgets/dialog_casamento.dart
// Migrado para Repository Pattern — sem acesso direto ao Firestore.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/models/equipamento.dart';
import 'package:protecin_producao/models/item_os.dart';
import 'package:protecin_producao/models/parceiro.dart';
import 'package:protecin_producao/provider/equipamento_provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/telas/producao/tela_cadastro_equipamento.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';

class DialogCasamento extends StatefulWidget {
  final Parceiro cliente;
  final String empresaId;
  final List<ItemOS> itensJaAdicionados;

  const DialogCasamento({
    super.key,
    required this.cliente,
    required this.empresaId,
    required this.itensJaAdicionados,
  });

  @override
  State<DialogCasamento> createState() => _DialogCasamentoState();
}

class _DialogCasamentoState extends State<DialogCasamento> {
  final _dossieController = TextEditingController();
  final _crachaController = TextEditingController();
  final FocusNode _crachaFocus = FocusNode();

  Equipamento? _equipamentoEncontrado;
  bool _isLoading = false;
  String? _errorDossie;

  @override
  void dispose() {
    _dossieController.dispose();
    _crachaController.dispose();
    _crachaFocus.dispose();
    super.dispose();
  }

  String _limparCodigo(String valor) {
    String limpo = valor.trim().toUpperCase();
    if (limpo.contains('HTTP')) limpo = limpo.split('/').last;
    return limpo.replaceAll('R-', '');
  }

  Future<void> _buscarDossie(String valor) async {
    if (valor.isEmpty) return;
    final idBusca = _limparCodigo(valor);
    _dossieController.text = idBusca;

    setState(() {
      _isLoading = true;
      _errorDossie = null;
      _equipamentoEncontrado = null;
    });

    try {
      final equipamento = await context.read<EquipamentoProvider>().buscarPorCodigo(
        empresaId: widget.empresaId,
        clienteId: widget.cliente.id,
        codigo: idBusca,
      );

      if (!mounted) return;

      if (equipamento == null) {
        _mostrarOpcaoCadastro(idBusca);
        return;
      }

      // Verifica se está ocupado em outra OS
      final status = equipamento.status.name;
      final osAtual = equipamento.osIdAtual ?? '';

      if (status == 'em_manutencao' || osAtual.isNotEmpty) {
        _mostrarAlerta(
          'Equipamento Ocupado!',
          'Este cilindro está vinculado à OS: ${osAtual.isEmpty ? "Desconhecida" : osAtual}\nStatus: $status',
        );
        _dossieController.clear();
        return;
      }

      // Verifica se pertence ao cliente correto
      if (equipamento.clienteId != widget.cliente.id) {
        setState(() => _errorDossie =
        'Atenção: Este item pertence a "${equipamento.clienteNome}"!');
        return;
      }

      setState(() => _equipamentoEncontrado = equipamento);
      FocusScope.of(context).requestFocus(_crachaFocus);
    } catch (e) {
      if (mounted) _mostrarAlerta('Erro na Busca', 'Falha ao conectar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _processarCracha(String valorBruto) async {
    final valorLimpo = _limparCodigo(valorBruto);
    _crachaController.text = valorLimpo;

    setState(() => _isLoading = true);

    try {
      // 1. Verifica duplicata local (na mesma OS sendo criada)
      final duplicadoLocal = widget.itensJaAdicionados
          .any((item) => item.idCrachaTemporario == valorLimpo);

      if (duplicadoLocal) {
        _mostrarAlerta(
          'Crachá Duplicado!',
          'Este crachá já foi bipado para outro item nesta mesma OS.',
        );
        _crachaController.clear();
        return;
      }

      // 2. Verifica se o crachá está em uso em outra OS no banco
      final emUso = await context
          .read<ItemOsProvider>()
          .verificarCrachaEmUso(valorLimpo);

      if (!mounted) return;

      if (emUso) {
        _mostrarAlerta(
          'Crachá Ocupado!',
          'Este crachá já está em uso na fábrica em outra OS.',
        );
        _crachaController.clear();
        return;
      }

      _realizarCasamento(valorLimpo);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarAlerta(String titulo, String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo,
            style: const TextStyle(
                color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
        ],
      ),
    );
  }

  Future<void> _mostrarOpcaoCadastro(String idBusca) async {
    if (!mounted) return;
    final bool cadastrarAgora = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Não encontrado'),
        content:
        Text('Cilindro "$idBusca" não cadastrado. Cadastrar agora?'),
        actions: [
          TextButton(
              child: const Text('Não'),
              onPressed: () => Navigator.of(ctx).pop(false)),
          ElevatedButton(
              child: const Text('Sim'),
              onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    ) ??
        false;

    if (cadastrarAgora && mounted) {
      final novo = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => TelaCadastroEquipamento(
            clientePreSelecionado: widget.cliente,
            numeroCascoPreenchido: idBusca,
          ),
        ),
      );
      if (novo != null && novo is Equipamento) {
        setState(() => _equipamentoEncontrado = novo);
        FocusScope.of(context).requestFocus(_crachaFocus);
      }
    }
  }

  void _realizarCasamento([String? valorOpcional]) {
    final idRastreio = valorOpcional ?? _crachaController.text.trim();
    if (_equipamentoEncontrado == null || idRastreio.isEmpty) return;

    final usuario =
        Provider.of<UsuarioProvider>(context, listen: false).usuario;
    if (usuario == null) return;

    final novoItemOS = ItemOS(
      id: '',
      osId: '',
      equipamentoId: _equipamentoEncontrado!.id,
      ativoFixo: _equipamentoEncontrado!.ativoFixo,
      idCrachaTemporario: idRastreio,
      tipoAgente: _equipamentoEncontrado!.tipo,
      empresaId: widget.empresaId,
      statusAtual: StatusOS.emCadastro,
      statusOriginal: 'emCadastro',
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
    final podeCasar = _equipamentoEncontrado != null &&
        _crachaController.text.trim().isNotEmpty;

    return AlertDialog(
      title: const Text('Bipar Equipamento & Crachá'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('1. Qual o Extintor?',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            CampoComScanner(
              controller: _dossieController,
              label: 'Bipe C-001, C-002...',
              icon: Icons.qr_code,
              onSubmitted: _buscarDossie,
            ),
            if (_errorDossie != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_errorDossie!,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            if (_equipamentoEncontrado != null)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 15),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Column(children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  Text(
                    '${_equipamentoEncontrado!.tipo} - ${_equipamentoEncontrado!.capacidade}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ]),
              ),
            const Text('2. Qual o Crachá?',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            CampoComScanner(
              controller: _crachaController,
              label: 'Bipe R-101...',
              icon: Icons.badge,
              focusNode: _crachaFocus,
              onSubmitted: _processarCracha,
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.link),
          label: const Text('VINCULAR'),
          style: ElevatedButton.styleFrom(
            backgroundColor: podeCasar ? Colors.green : Colors.grey,
            foregroundColor: Colors.white,
          ),
          onPressed: podeCasar ? () => _realizarCasamento() : null,
        ),
      ],
    );
  }
}