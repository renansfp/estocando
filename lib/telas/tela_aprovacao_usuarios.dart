import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class TelaAprovacaoUsuarios extends StatefulWidget {
  const TelaAprovacaoUsuarios({super.key});

  @override
  State<TelaAprovacaoUsuarios> createState() => _TelaAprovacaoUsuariosState();
}

class _TelaAprovacaoUsuariosState extends State<TelaAprovacaoUsuarios> {
  // O "PORQUÊ": Usamos um único booleano de loading para o card inteiro.
  // Isso evita que o admin clique em "Aprovar" e "Recusar" ao mesmo tempo.
  // O Map<String, bool> associa o estado de loading a um UID específico.
  final Map<String, bool> _loadingStates = {};

  // O "PORQUÊ": Esta função chama a Cloud Function 'approveUser' que criamos.
  Future<void> _aprovarUsuario(String uid) async {
    setState(() => _loadingStates[uid] = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'southamerica-east1')
          .httpsCallable('approveUser');
      await callable.call({'uid': uid});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário aprovado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao aprovar: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Mesmo com erro, removemos o estado de loading para liberar o botão.
      if (mounted) {
        setState(() => _loadingStates.remove(uid));
      }
    }
  }

  // ================== NOVA FUNÇÃO ==================
  // O "PORQUÊ": Esta função chama a nova Cloud Function 'rejectUser'.
  // Ela exclui o usuário do Authentication e do Firestore.
  Future<void> _recusarUsuario(String uid) async {
    setState(() => _loadingStates[uid] = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'southamerica-east1')
          .httpsCallable('rejectUser');
      await callable.call({'uid': uid});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário recusado e excluído com sucesso.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao recusar: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingStates.remove(uid));
      }
    }
  }

  // O "PORQUÊ": Excluir um usuário é uma ação destrutiva e irreversível.
  // Sempre mostramos um diálogo de confirmação para evitar cliques acidentais,
  // melhorando a segurança e a usabilidade da interface de administração.
  void _mostrarDialogoDeConfirmacao(String email, String uid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Recusa'),
        content: Text('Tem certeza que deseja recusar e excluir permanentemente o usuário "$email"?\n\nEsta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir Permanentemente'),
            onPressed: () {
              Navigator.of(ctx).pop(); // Fecha o diálogo
              _recusarUsuario(uid); // Executa a função de recusa
            },
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aprovar Novos Usuários'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('usuarios')
            .where('status', isEqualTo: 'pendente')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Ocorreu um erro.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum usuário aguardando aprovação.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final usuariosPendentes = snapshot.data!.docs;

          return ListView.builder(
            itemCount: usuariosPendentes.length,
            itemBuilder: (context, index) {
              final usuario = usuariosPendentes[index];
              final data = usuario.data() as Map<String, dynamic>;
              final email = data['email'] ?? 'E-mail não informado';
              final uid = usuario.id;
              final isLoading = _loadingStates[uid] ?? false;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(email),
                  subtitle: const Text('Status: Pendente'),
                  trailing: isLoading
                      ? const CircularProgressIndicator()
                      : Row( // O "PORQUÊ": Usamos uma Row para colocar os dois botões lado a lado.
                    mainAxisSize: MainAxisSize.min, // Faz a Row ocupar o mínimo de espaço.
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () => _mostrarDialogoDeConfirmacao(email, uid),
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

