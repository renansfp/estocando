// CÓDIGO FINAL REFATORADO PARA TELA DE PARCEIROS COM FIREBASE E BUSCA
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'tela_cadastro_parceiro.dart';

// O enum pode ficar aqui, pois é usado pela tela de cadastro também
enum TipoParceiro { cliente, fornecedor }

class TelaParceiros extends StatefulWidget {
  const TelaParceiros({super.key});
  @override
  State<TelaParceiros> createState() => _TelaParceirosState();
}

class _TelaParceirosState extends State<TelaParceiros> {
  // MODIFICAÇÃO: Variáveis de estado para a busca
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {}); // Reconstrói a tela a cada letra digitada na busca
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatarDocumento(String doc) {
    if (doc.isEmpty) return 'Não informado';
    if (doc.length > 11) {
      return MaskTextInputFormatter(mask: '##.###.###/####-##', initialText: doc).getMaskedText();
    }
    return MaskTextInputFormatter(mask: '###.###.###-##', initialText: doc).getMaskedText();
  }

  // CORREÇÃO: Lógica de telefone removida, pois removemos da tela de cadastro
  // String _formatarTelefone(String tel) { ... }

  void _navegarParaCadastro({QueryDocumentSnapshot? parceiroParaEditar}) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => TelaCadastroParceiro(parceiroParaEditar: parceiroParaEditar)));
  }

  void _mostrarDialogDeConfirmacao(QueryDocumentSnapshot parceiroDoc) {
    final data = parceiroDoc.data() as Map<String, dynamic>;
    final nome = data['nome'] ?? 'Parceiro sem nome';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja excluir "$nome"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          TextButton(onPressed: () async {
            await FirebaseFirestore.instance.collection('parceiros').doc(parceiroDoc.id).delete();
            Navigator.of(context).pop();
          }, child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // MODIFICAÇÃO: AppBar agora é construída por uma função auxiliar
      appBar: _buildAppBar(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('parceiros').orderBy('nome').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Erro ao carregar os parceiros.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nenhum cliente ou fornecedor cadastrado.', style: TextStyle(fontSize: 18, color: Colors.grey)));
          }

          // MODIFICAÇÃO: Lógica de filtragem da busca
          List<QueryDocumentSnapshot> parceiros = snapshot.data!.docs;
          final String query = _searchController.text.toLowerCase().trim();

          if (query.isNotEmpty) {
            parceiros = parceiros.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final nome = (data['nome'] ?? '').toLowerCase();
              final codigo = (data['codigo'] ?? '').toLowerCase();
              return nome.contains(query) || codigo.contains(query);
            }).toList();
          }

          if (parceiros.isEmpty) {
            return Center(child: Text('Nenhum parceiro encontrado para "$query"', style: const TextStyle(fontSize: 18, color: Colors.grey)));
          }

          return ListView.builder(
            itemCount: parceiros.length,
            itemBuilder: (context, index) {
              final parceiroDoc = parceiros[index];
              final data = parceiroDoc.data() as Map<String, dynamic>;

              final codigo = data['codigo'] ?? 'N/A';
              final nome = data['nome'] ?? 'Sem nome';
              final cnpj = data['cnpj'] ?? '';
              final tipo = TipoParceiro.values.byName(data['tipo'] ?? 'cliente');
              final bool isCliente = tipo == TipoParceiro.cliente;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: isCliente ? Colors.blueAccent : Colors.orangeAccent, child: Icon(isCliente ? Icons.person : Icons.store, color: Colors.white)),
                  title: Text('$codigo - $nome', style: const TextStyle(fontWeight: FontWeight.bold)),
                  // CORREÇÃO: Removido o telefone do subtítulo
                  subtitle: Text('Doc: ${_formatarDocumento(cnpj)}'),
                  isThreeLine: false, // Não precisa mais de 3 linhas
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.grey), onPressed: () => _navegarParaCadastro(parceiroParaEditar: parceiroDoc)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _mostrarDialogDeConfirmacao(parceiroDoc)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _navegarParaCadastro(), child: const Icon(Icons.add), tooltip: 'Adicionar Novo Parceiro'),
    );
  }

  // MODIFICAÇÃO: Função para construir a AppBar dinâmica
  AppBar _buildAppBar() {
    if (!_isSearching) {
      return AppBar(
        title: const Text('Clientes e Fornecedores'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _isSearching = true),
          ),
        ],
      );
    } else {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() {
            _isSearching = false;
            _searchController.clear();
          }),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Buscar por código ou nome...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => _searchController.clear(),
          ),
        ],
      );
    }
  }
}