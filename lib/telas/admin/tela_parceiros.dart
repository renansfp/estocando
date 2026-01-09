// CÓDIGO CORRIGIDO COM FILTRO DE EMPRESA

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ---> MUDANÇA 1: Importamos para pegar o usuário.
import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'tela_cadastro_parceiro.dart';

enum TipoParceiro { cliente, fornecedor }

class TelaParceiros extends StatefulWidget {
  const TelaParceiros({super.key});
  @override
  State<TelaParceiros> createState() => _TelaParceirosState();
}

class _TelaParceirosState extends State<TelaParceiros> {
  bool _isSearching = false;
  final _searchController = TextEditingController();

  // ---> MUDANÇA 2: Novas variáveis para guardar o empresaId e controlar o loading.
  String? _empresaId;
  bool _carregandoDadosIniciais = true;

  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario(); // ---> MUDANÇA 3: Chamamos a função para buscar o empresaId.
    _searchController.addListener(() {
      setState(() {});
    });
  }

  // ---> MUDANÇA 4: Nova função para buscar o empresaId do usuário logado.
  Future<void> _carregarDadosUsuario() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (mounted && userDoc.exists) {
        setState(() {
          _empresaId = (userDoc.data() as Map<String, dynamic>)['empresaId'];
          _carregandoDadosIniciais = false;
        });
      }
    } else {
      // Se não houver usuário, impede o prosseguimento.
      setState(() {
        _carregandoDadosIniciais = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatarDocumento(String doc) {
    if (doc.isEmpty) return 'Não informado';
    // CNPJ tem 14 dígitos, CPF tem 11
    if (doc.length > 11) {
      return MaskTextInputFormatter(mask: '##.###.###/####-##', initialText: doc).getMaskedText();
    }
    return MaskTextInputFormatter(mask: '###.###.###-##', initialText: doc).getMaskedText();
  }

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
            if(mounted) Navigator.of(context).pop();
          }, child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _carregandoDadosIniciais
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
        // ---> MUDANÇA 5: A consulta agora é segura e filtrada pelo empresaId!
        stream: FirebaseFirestore.instance
            .collection('parceiros')
            .where('empresaId', isEqualTo: _empresaId)
            .orderBy('nome')
            .snapshots(),
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
                  subtitle: Text('Doc: ${_formatarDocumento(cnpj)}'),
                  isThreeLine: false,
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