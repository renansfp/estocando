// Arquivo: lib/widgets/autocomplete_equipamento.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/models/equipamento.dart';

class AutocompleteEquipamentoWidget extends StatefulWidget {
  final String empresaId;
  final String clienteId;
  final Function(Equipamento?) onEquipamentoSelected;
  final String label;

  const AutocompleteEquipamentoWidget({
    super.key,
    required this.empresaId,
    required this.clienteId,
    required this.onEquipamentoSelected,
    this.label = 'Ativo Fixo ou Cilindro',
  });

  @override
  State<AutocompleteEquipamentoWidget> createState() => _AutocompleteEquipamentoWidgetState();
}

class _AutocompleteEquipamentoWidgetState extends State<AutocompleteEquipamentoWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<Iterable<Equipamento>> _buscarEquipamentos(String text) async {
    if (text.isEmpty) return const Iterable.empty();
    try {
      // Tenta buscar pelo Ativo Fixo (Prioridade para OS)
      final querySnapshot = await FirebaseFirestore.instance
          .collection('equipamentos')
          .where('empresaId', isEqualTo: widget.empresaId)
          .where('clienteId', isEqualTo: widget.clienteId)
          .where('ativoFixo', isGreaterThanOrEqualTo: text.toUpperCase())
          .where('ativoFixo', isLessThanOrEqualTo: '${text.toUpperCase()}\uf8ff')
          .limit(10)
          .get();

      // Se quiser buscar por cilindro também, precisaria de outra query ou lógica composta,
      // mas o Firebase limita o 'OR'. Vamos focar no Ativo Fixo que você pediu para a OS.

      return querySnapshot.docs.map((doc) =>
          Equipamento.fromJson(doc.data() as Map<String, dynamic>, doc.id));
    } catch (e) {
      return const Iterable.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<Equipamento>(
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: (TextEditingValue textEditingValue) {
        return _buscarEquipamentos(textEditingValue.text);
      },
      // Mostra o Ativo Fixo na caixa de texto
      displayStringForOption: (Equipamento option) => option.ativoFixo,
      onSelected: (Equipamento selection) {
        widget.onEquipamentoSelected(selection);
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                textEditingController.clear();
                widget.onEquipamentoSelected(null);
              },
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            child: SizedBox(
              width: 300,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final Equipamento option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: ListTile(
                      title: Text('Ativo: ${option.ativoFixo}'),
                      subtitle: Text('Cilindro: ${option.numeroCilindro} (${option.tipo})'),
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