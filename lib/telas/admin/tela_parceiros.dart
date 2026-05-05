// lib/telas/admin/tela_parceiros.dart
// Migrada para Repository Pattern — sem acesso direto ao Firestore.

import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/models/parceiro.dart';
import 'package:protecin_producao/provider/parceiro_provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'tela_cadastro_parceiro.dart';

class TelaParceiros extends StatefulWidget {
  const TelaParceiros({super.key});

  @override
  State<TelaParceiros> createState() => _TelaParceirosState();
}

class _TelaParceirosState extends State<TelaParceiros> {
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatarDocumento(String doc) {
    if (doc.isEmpty) return 'Não informado';
    if (doc.length > 11) {
      return MaskTextInputFormatter(
          mask: '##.###.###/####-##', initialText: doc)
          .getMaskedText();
    }
    return MaskTextInputFormatter(mask: '###.###.###-##', initialText: doc)
        .getMaskedText();
  }

  void _navegarParaCadastro({Map<String, dynamic>? parceiro}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaCadastroParceiro(parceiroParaEditar: parceiro),
      ),
    );
  }

  void _mostrarDialogExclusao(Map<String, dynamic> parceiro) {
    final nome = parceiro['nome'] ?? 'Parceiro sem nome';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja excluir "$nome"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await context
                    .read<ParceiroProvider>()
                    .excluir(parceiro['id'] as String);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Erro ao excluir: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Excluir',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<UsuarioProvider>().usuario;

    if (usuario == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final empresaId = usuario.empresaId;

    return Scaffold(
      appBar: _buildAppBar(),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: context
            .read<ParceiroProvider>()
            .streamParceiros(empresaId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: Text('Erro ao carregar os parceiros.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var parceiros = snapshot.data ?? [];

          if (parceiros.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum cliente ou fornecedor cadastrado.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          // Filtro em memória por nome ou código
          final query = _searchController.text.toLowerCase().trim();
          if (query.isNotEmpty) {
            parceiros = parceiros.where((p) {
              final nome = (p['nome'] ?? '').toLowerCase();
              final codigo = (p['codigo'] ?? '').toLowerCase();
              return nome.contains(query) || codigo.contains(query);
            }).toList();
          }

          if (parceiros.isEmpty) {
            return Center(
              child: Text(
                'Nenhum parceiro encontrado para "$query"',
                style:
                const TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: parceiros.length,
            itemBuilder: (context, index) {
              final p = parceiros[index];
              final codigo = p['codigo'] ?? 'N/A';
              final nome = p['nome'] ?? 'Sem nome';
              final cnpj = p['cnpj'] ?? '';
              final tipo = TipoParceiro.values
                  .byName(p['tipo'] ?? 'cliente');
              final isCliente = tipo == TipoParceiro.cliente;

              return Card(
                margin: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCliente
                        ? Colors.blueAccent
                        : Colors.orangeAccent,
                    child: Icon(
                      isCliente ? Icons.person : Icons.store,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    '$codigo - $nome',
                    style:
                    const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle:
                  Text('Doc: ${_formatarDocumento(cnpj)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit,
                            color: Colors.grey),
                        onPressed: () =>
                            _navegarParaCadastro(parceiro: p),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.red),
                        onPressed: () =>
                            _mostrarDialogExclusao(p),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Adicionar Novo Parceiro',
        onPressed: () => _navegarParaCadastro(),
        child: const Icon(Icons.add),
      ),
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
    }
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