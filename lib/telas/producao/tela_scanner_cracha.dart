// lib/telas/producao/tela_scanner_cracha.dart
//
// Scanner de Crachá — busca um extintor pelo QR code do crachá físico.
//
// Fluxo de leitura (2 buscas):
//   1. `crachas` → `idCracha` + `empresaId` → obtém `itemOsIdAtual` e `osIdAtual`
//   2. `ordens_servico/{osId}/itens/{itemId}` → dados completos do extintor

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/widgets/campo_com_scanner.dart';

class TelaScannerCracha extends StatefulWidget {
  const TelaScannerCracha({super.key});

  @override
  State<TelaScannerCracha> createState() => _TelaScannerCrachaState();
}

class _TelaScannerCrachaState extends State<TelaScannerCracha> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool _buscando = false;
  String? _erro;

  Map<String, dynamic>? _cracha;
  Map<String, dynamic>? _item;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _buscar(String idCracha) async {
    final id = idCracha.trim().toUpperCase();
    if (id.isEmpty) return;

    setState(() {
      _buscando = true;
      _erro = null;
      _cracha = null;
      _item = null;
    });

    try {
      final empresaId =
          context.read<UsuarioProvider>().usuario?.empresaId ?? '';

      // 1. Busca o crachá na coleção crachas
      final cracha = await context
          .read<ItemOsProvider>()
          .buscarInfoCracha(id, empresaId);

      if (!mounted) return;

      if (cracha == null) {
        setState(() {
          _erro = 'Crachá "$id" não encontrado nesta empresa.';
          _buscando = false;
        });
        return;
      }

      // 2. Se estiver em uso, busca o item na subcoleção da OS correspondente.
      // O crachá guarda tanto o itemOsIdAtual quanto o osIdAtual para que
      // possamos montar o caminho correto: ordens_servico/{osId}/itens/{itemId}
      Map<String, dynamic>? item;
      final statusCracha = cracha['status']?.toString() ?? '';
      final itemOsId = cracha['itemOsIdAtual']?.toString() ?? '';
      final osIdCracha = cracha['osIdAtual']?.toString() ?? '';

      if (statusCracha == 'emUso' &&
          itemOsId.isNotEmpty &&
          osIdCracha.isNotEmpty) {
        item = await context
            .read<ItemOsProvider>()
            .buscarItemPorId(itemOsId, osIdCracha);
      }

      if (!mounted) return;

      setState(() {
        _cracha = cracha;
        _item = item;
        _buscando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Erro ao buscar: $e';
        _buscando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner de Crachá'),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CampoComScanner(
              controller: _controller,
              focusNode: _focusNode,
              label: 'ID do Crachá (ex: R-042)',
              icon: Icons.qr_code_scanner,
              onSubmitted: _buscar,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.search),
              label: const Text('Buscar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade900,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _buscando
                  ? null
                  : () => _buscar(_controller.text),
            ),
            const SizedBox(height: 24),

            if (_buscando)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: CircularProgressIndicator(),
                ),
              ),

            if (_erro != null)
              _buildCardErro(_erro!),

            if (_cracha != null && !_buscando)
              _buildResultado(_cracha!, _item),
          ],
        ),
      ),
    );
  }

  Widget _buildCardErro(String mensagem) {
    return Card(
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensagem,
                style: TextStyle(color: Colors.red.shade800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultado(
      Map<String, dynamic> cracha, Map<String, dynamic>? item) {
    final statusCracha = cracha['status']?.toString() ?? '';
    final idCracha = cracha['idCracha']?.toString() ?? '—';

    if (statusCracha != 'emUso') {
      return _buildCardDisponivel(idCracha);
    }

    if (item == null) {
      return _buildCardErro(
          'Crachá marcado como em uso, mas o extintor não foi encontrado.\n'
              'Verifique a consistência dos dados.');
    }

    return _buildCardItem(idCracha, item);
  }

  Widget _buildCardDisponivel(String idCracha) {
    return Card(
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.green.shade100,
              radius: 28,
              child: Icon(Icons.check_circle,
                  color: Colors.green.shade700, size: 30),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  idCracha,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Crachá disponível',
                  style: TextStyle(
                      color: Colors.green.shade700, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardItem(String idCracha, Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? '';
    final numeroOS = item['numeroOS']?.toString() ?? '—';
    final clienteNome = item['clienteNome']?.toString() ?? '—';
    final tipoAgente = item['tipoAgente']?.toString() ?? '—';
    final ativoFixo = item['ativoFixo']?.toString() ?? '';
    final estacaoLabel = _traduzirStatus(status);
    final corEstacao = _corStatus(status);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade800,
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.badge, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Text(
                  idCracha,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          Container(
            width: double.infinity,
            color: corEstacao.withAlpha(30),
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.location_on, color: corEstacao, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Estação atual: $estacaoLabel',
                  style: TextStyle(
                    color: corEstacao,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                _buildLinha(Icons.assignment, 'OS', numeroOS),
                const Divider(height: 16),
                _buildLinha(Icons.person, 'Cliente', clienteNome),
                const Divider(height: 16),
                _buildLinha(Icons.local_fire_department, 'Agente', tipoAgente),
                if (ativoFixo.isNotEmpty) ...[
                  const Divider(height: 16),
                  _buildLinha(Icons.tag, 'Ativo fixo', ativoFixo),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinha(IconData icone, String label, String valor) {
    return Row(
      children: [
        Icon(icone, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
                color: Colors.blueGrey, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            valor,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  static const _labelsEstacao = {
    'aguardando_descarga': 'Descarga',
    'descarga_concluida': 'Descarga (concluída)',
    'aguardando_limpeza': 'Limpeza',
    'aguardando_lixa': 'Lixa',
    'aguardando_saque': 'Saque de Válvula',
    'aguardando_manutencao': 'Manutenção de Válvula',
    'aguardando_valvula_po': 'Válvula Pó',
    'aguardando_premontagem': 'Pré-Montagem',
    'aguardando_th': 'Teste Hidrostático',
    'aguardando_recarga': 'Recarga',
    'aguardando_recarga_abc': 'Recarga (ABC)',
    'aguardando_recarga_co2': 'Recarga (CO₂)',
    'aguardando_recarga_agua_espuma': 'Recarga (Água/Espuma)',
    'aguardando_estanqueidade': 'Estanqueidade',
    'aguardando_montagem': 'Montagem',
    'aguardando_pintura': 'Pintura',
    'aguardando_expedicao': 'Expedição',
    'entregue': 'Expedido',
    'condenado': 'Condenado',
  };

  String _traduzirStatus(String status) {
    if (_labelsEstacao.containsKey(status)) {
      return _labelsEstacao[status]!;
    }
    return status
        .replaceFirst('aguardando_', '')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty
        ? ''
        : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  Color _corStatus(String status) {
    if (status.contains('expedicao') || status == 'entregue') {
      return Colors.black87;
    }
    if (status == 'condenado') return Colors.red.shade700;
    if (status.contains('descarga')) return Colors.orange.shade700;
    if (status.contains('limpeza')) return Colors.blue.shade700;
    if (status.contains('lixa')) return Colors.blueGrey.shade600;
    if (status.contains('saque')) return Colors.red.shade700;
    if (status.contains('manutencao')) return Colors.teal.shade700;
    if (status.contains('valvula')) return Colors.deepOrange.shade700;
    if (status.contains('premontagem')) return Colors.indigo.shade700;
    if (status.contains('th')) return Colors.purple.shade700;
    if (status.contains('recarga')) return Colors.green.shade700;
    if (status.contains('estanqueidade')) return Colors.lightBlue.shade700;
    if (status.contains('montagem')) return Colors.deepPurple.shade700;
    if (status.contains('pintura')) return Colors.brown.shade700;
    return Colors.blueGrey;
  }
}