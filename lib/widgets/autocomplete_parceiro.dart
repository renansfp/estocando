// lib/widgets/autocomplete_parceiro.dart
// Migrado para Repository Pattern — sem acesso direto ao Firestore.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/models/parceiro.dart';
import 'package:protecin_producao/provider/parceiro_provider.dart';

class AutocompleteParceiroWidget extends StatefulWidget {
  final String empresaId;
  final TipoParceiro tipoParceiro;
  final Function(Parceiro?) onParceiroSelected;
  final String label;

  const AutocompleteParceiroWidget({
    super.key,
    required this.empresaId,
    required this.tipoParceiro,
    required this.onParceiroSelected,
    this.label = 'Nome do Parceiro',
  });

  @override
  State<AutocompleteParceiroWidget> createState() =>
      _AutocompleteParceiroWidgetState();
}

class _AutocompleteParceiroWidgetState
    extends State<AutocompleteParceiroWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<Iterable<Parceiro>> _buscarParceiros(String termo) async {
    if (termo.isEmpty) return const Iterable.empty();
    try {
      final maps = await context.read<ParceiroProvider>().buscarPorNome(
        empresaId: widget.empresaId,
        tipoParceiro: widget.tipoParceiro.name,
        termo: termo,
      );
      return maps.map((m) => Parceiro.fromJson(m, m['id'] as String));
    } catch (e) {
      debugPrint('AutocompleteParceiroWidget erro: $e');
      return const Iterable.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<Parceiro>(
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: (TextEditingValue textEditingValue) =>
          _buscarParceiros(textEditingValue.text),
      displayStringForOption: (Parceiro option) => option.nome,
      onSelected: (Parceiro selection) =>
          widget.onParceiroSelected(selection),
      fieldViewBuilder: (context, textEditingController, focusNode,
          onFieldSubmitted) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                textEditingController.clear();
                widget.onParceiroSelected(null);
              },
            ),
          ),
          validator: (_) => null,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final Parceiro option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: ListTile(
                      title: Text(option.nome),
                      subtitle: Text('Código: ${option.codigo}'),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}