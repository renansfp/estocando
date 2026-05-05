// lib/telas/admin/tela_aprovacao_usuarios.dart
// Migrada para Repository Pattern — sem acesso direto ao Firestore ou FirebaseFunctions.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';

class TelaAprovacaoUsuarios extends StatefulWidget {
  const TelaAprovacaoUsuarios({super.key});

  @override
  State<TelaAprovacaoUsuarios> createState() => _TelaAprovacaoUsuariosState();
}

class _TelaAprovacaoUsuariosState extends State<TelaAprovacaoUsuarios> {
  // Associa o estado de loading a um UID específico para evitar
  // que o admin clique em Aprovar e Recusar ao mesmo tempo no mesmo card.
  final Map<String, bool> _loadingStates = {};

  Future<void> _aprovarUsuario(String uid) async {
    setState(() => _loadingStates[uid] = true);
    try {
      await context.read<UsuarioProvider>().aprovar(uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário aprovado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao aprovar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingStates.remove(uid));
    }
  }

  Future<void> _recusarUsuario(String uid) async {
    setState(() => _loadingStates[uid] = true);
    try {
      await context.read<UsuarioProvider>().recusar(uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário recusado e excluído com sucesso.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao recusar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingStates.remove(uid));
    }
  }

  void _mostrarDialogoDeConfirmacao(String email, String uid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Recusa'),
        content: Text(
          'Tem certeza que deseja recusar e excluir permanentemente '
              'o usuário "$email"?\n\nEsta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              _recusarUsuario(uid);
            },
            child: const Text('Excluir Permanentemente'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aprovar Novos Usuários')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: context
            .read<UsuarioProvider>()
            .streamUsuariosPendentes(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Ocorreu um erro.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final usuarios = snapshot.data ?? [];

          if (usuarios.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum usuário aguardando aprovação.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: usuarios.length,
            itemBuilder: (context, index) {
              final data = usuarios[index];
              final uid = data['id'] as String;
              final email = data['email'] as String? ?? 'E-mail não informado';
              final isLoading = _loadingStates[uid] ?? false;

              return Card(
                margin: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(email),
                  subtitle: const Text('Status: Pendente'),
                  trailing: isLoading
                      ? const CircularProgressIndicator()
                      : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.red),
                        onPressed: () =>
                            _mostrarDialogoDeConfirmacao(email, uid),
                        child: const Text('Recusar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _aprovarUsuario(uid),
                        child: const Text('Aprovar'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}