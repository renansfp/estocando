// lib/widgets/dialog_pecas_trocadas.dart
//
// Dialog reutilizável que aparece antes de confirmar uma etapa.
// O operador marca as peças que trocou. O-ring (15) e Pera (13) vêm
// pré-marcados e não podem ser desmarcados.
//
// Retorna Map<int, String> legendaNumero → codigoProduto
// ou null se o operador cancelar.

import 'package:flutter/material.dart';
import 'package:protecin_producao/utils/mapeador_pecas_producao.dart';

class DialogPecasTrocadas extends StatefulWidget {
  /// Peças relevantes para esta estação (números de legenda).
  final List<int> legendasDisponiveis;

  /// Peças obrigatórias — virão pré-marcadas e bloqueadas.
  final List<int> legendasObrigatorias;

  /// Dados do equipamento para resolver o código de produto.
  final String tipoEquipamento;
  final String capacidadeEquipamento;
  final String fabricanteEquipamento;

  const DialogPecasTrocadas({
    super.key,
    required this.legendasDisponiveis,
    required this.legendasObrigatorias,
    required this.tipoEquipamento,
    required this.capacidadeEquipamento,
    required this.fabricanteEquipamento,
  });

  @override
  State<DialogPecasTrocadas> createState() => _DialogPecasTrocadasState();
}

class _DialogPecasTrocadasState extends State<DialogPecasTrocadas> {
  // legenda → código produto selecionado (pode ser escolha do operador)
  late Map<int, String?> _selecoes;

  @override
  void initState() {
    super.initState();
    _selecoes = {};
    for (final leg in widget.legendasDisponiveis) {
      final codigos = MapeadorPecasProducao.resolverCodigos(
        tipo: widget.tipoEquipamento,
        capacidade: widget.capacidadeEquipamento,
        fabricante: widget.fabricanteEquipamento,
        legendaNumero: leg,
      );
      if (codigos == null) continue; // não aplicável para este equipamento

      // Pré-marcar obrigatórias com o primeiro (único) código
      if (widget.legendasObrigatorias.contains(leg)) {
        _selecoes[leg] = codigos.length == 1 ? codigos.first : null;
      }
      // Opcionais começam desmarcadas
    }
  }

  bool _isMarcada(int leg) => _selecoes.containsKey(leg);

  bool _isObrigatoria(int leg) =>
      widget.legendasObrigatorias.contains(leg);

  /// Resolve os códigos disponíveis para esta peça neste equipamento.
  List<String>? _codigos(int leg) => MapeadorPecasProducao.resolverCodigos(
    tipo: widget.tipoEquipamento,
    capacidade: widget.capacidadeEquipamento,
    fabricante: widget.fabricanteEquipamento,
    legendaNumero: leg,
  );

  void _togglePeca(int leg) {
    if (_isObrigatoria(leg)) return;
    setState(() {
      if (_isMarcada(leg)) {
        _selecoes.remove(leg);
      } else {
        final codigos = _codigos(leg);
        if (codigos == null) return;
        // Se só tem 1 código, já marca direto. Se tem 2+, deixa null (operador escolhe)
        _selecoes[leg] = codigos.length == 1 ? codigos.first : null;
      }
    });
  }

  bool get _podeConcluir {
    // Verifica se todas as peças marcadas têm código resolvido
    for (final entry in _selecoes.entries) {
      if (entry.value == null) return false;
    }
    return true;
  }

  void _confirmar() {
    final resultado = <int, String>{};
    for (final entry in _selecoes.entries) {
      if (entry.value != null) {
        resultado[entry.key] = entry.value!;
      }
    }
    Navigator.of(context).pop(resultado);
  }

  @override
  Widget build(BuildContext context) {
    // Filtra apenas as peças aplicáveis para este equipamento
    final aplicaveis = widget.legendasDisponiveis
        .where((leg) => _codigos(leg) != null)
        .toList();

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.build, color: Colors.blueGrey.shade800),
          const SizedBox(width: 8),
          const Text('Peças Trocadas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Text(
                'Marque as peças substituídas nesta etapa:',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            ...aplicaveis.map((leg) => _buildItem(leg)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('CANCELAR'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('CONFIRMAR'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _podeConcluir
                ? Colors.blueGrey.shade800
                : Colors.grey,
            foregroundColor: Colors.white,
          ),
          onPressed: _podeConcluir ? _confirmar : null,
        ),
      ],
    );
  }

  Widget _buildItem(int leg) {
    final obrigatorio = _isObrigatoria(leg);
    final marcada     = _isMarcada(leg);
    final codigos     = _codigos(leg)!;
    final nome        = MapeadorPecasProducao.nomeDaPeca(leg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          dense: true,
          value: marcada,
          onChanged: obrigatorio ? null : (_) => _togglePeca(leg),
          title: Row(
            children: [
              Text(
                '$leg. $nome',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: obrigatorio ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (obrigatorio)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Text('SEMPRE',
                      style: TextStyle(fontSize: 9, color: Colors.deepOrange)),
                ),
            ],
          ),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: obrigatorio ? Colors.orange : Colors.blueGrey.shade700,
        ),
        // Se marcada E tem mais de 1 código → operador escolhe
        if (marcada && codigos.length > 1)
          Padding(
            padding: const EdgeInsets.only(left: 52, bottom: 8, right: 16),
            child: _buildEscolhaCodigo(leg, codigos),
          ),
      ],
    );
  }

  Widget _buildEscolhaCodigo(int leg, List<String> codigos) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.amber.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Qual modelo foi usado?',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade900),
          ),
          const SizedBox(height: 4),
          ...codigos.map((cod) => RadioListTile<String>(
            dense: true,
            value: cod,
            groupValue: _selecoes[leg],
            onChanged: (v) => setState(() => _selecoes[leg] = v),
            title: Text('Cód. $cod',
                style: const TextStyle(fontSize: 12)),
            activeColor: Colors.amber.shade800,
          )),
        ],
      ),
    );
  }
}

/// Helper para abrir o dialog e aguardar o resultado.
/// Retorna Map<int, String> legendaNumero → codigoProduto, ou null se cancelado.
Future<Map<int, String>?> mostrarDialogPecasTrocadas({
  required BuildContext context,
  required List<int> legendasDisponiveis,
  required List<int> legendasObrigatorias,
  required String tipoEquipamento,
  required String capacidadeEquipamento,
  required String fabricanteEquipamento,
}) {
  return showDialog<Map<int, String>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DialogPecasTrocadas(
      legendasDisponiveis: legendasDisponiveis,
      legendasObrigatorias: legendasObrigatorias,
      tipoEquipamento: tipoEquipamento,
      capacidadeEquipamento: capacidadeEquipamento,
      fabricanteEquipamento: fabricanteEquipamento,
    ),
  );
}