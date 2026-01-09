// Arquivo: lib/widgets/autocomplete_parceiro.dart (VERSÃO CORRIGIDA)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/models/parceiro.dart';

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
  // <<< MUDANÇA 1: Criamos os dois (controller e focus node)
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // <<< MUDANÇA 3: Adicionamos o dispose para os dois
  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<Iterable<Parceiro>> _buscarParceiros(String text) async {
    // ... (Esta função continua a mesma) ...
    if (text.isEmpty) {
      return const Iterable.empty();
    }
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('parceiros')
          .where('empresaId', isEqualTo: widget.empresaId)
          .where('tipo', isEqualTo: widget.tipoParceiro.name)
          .where('nome', isGreaterThanOrEqualTo: text.toUpperCase())
          .where('nome', isLessThanOrEqualTo: '${text.toUpperCase()}\uf8ff')
          .limit(10)
          .get();
      return querySnapshot.docs.map((doc) =>
          Parceiro.fromJson(doc.data() as Map<String, dynamic>, doc.id));
    } catch (e) {
      print('Erro ao buscar parceiros: $e');
      return const Iterable.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<Parceiro>(
      // <<< MUDANÇA 2: Passamos os dois, como manda a regra
      textEditingController: _controller,
      focusNode: _focusNode,

      optionsBuilder: (TextEditingValue textEditingValue) {
        return _buscarParceiros(textEditingValue.text);
      },
      displayStringForOption: (Parceiro option) => option.nome,
      onSelected: (Parceiro selection) {
        widget.onParceiroSelected(selection);
      },

      fieldViewBuilder: (BuildContext context,
          TextEditingController textEditingController, // Este é o controller interno
          FocusNode focusNode, // Este é o focus node interno
          VoidCallback onFieldSubmitted) {
        return TextFormField(
          // Usamos os que o RawAutocomplete nos passa
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                textEditingController.clear();
                // Limpamos também a seleção na tela-pai (precisamos ajustar isso)
                widget.onParceiroSelected(null);
              },
            ),
          ),
          validator: (value) {
            return null;
          },
        );
      },
      // ... (optionsViewBuilder continua o mesmo) ...
      optionsViewBuilder: (BuildContext context,
          AutocompleteOnSelected<Parceiro> onSelected,
          Iterable<Parceiro> options) {
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
                itemBuilder: (BuildContext context, int index) {
                  final Parceiro option = options.elementAt(index);
                  return InkWell(
                    onTap: () {
                      onSelected(option);
                    },
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