// lib/telas/admin/tela_aprovacao_usuarios.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/models/usuario.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';

class TelaAprovacaoUsuarios extends StatefulWidget {
  const TelaAprovacaoUsuarios({super.key});

  @override
  State<TelaAprovacaoUsuarios> createState() => _TelaAprovacaoUsuariosState();
}

class _TelaAprovacaoUsuariosState extends State<TelaAprovacaoUsuarios> {
  final Map<String, bool> _loadingStates = {};
  bool _recalculando = false;

  // ── PERFIS DISPONÍVEIS ────────────────────────────────────────────────────

  static const _perfis = [
    _PerfilOpcao(
      valor: 'admin',
      label: 'Admin',
      descricao: 'Acesso total ao sistema',
      icone: Icons.admin_panel_settings,
      cor: Colors.red,
    ),
    _PerfilOpcao(
      valor: 'lider',
      label: 'Líder',
      descricao: 'Acesso total à produção. Pode liberar estações',
      icone: Icons.star,
      cor: Colors.orange,
    ),
    _PerfilOpcao(
      valor: 'operador',
      label: 'Operador',
      descricao: 'Acessa só as estações liberadas pelo líder',
      icone: Icons.engineering,
      cor: Colors.blue,
    ),
    _PerfilOpcao(
      valor: 'almoxarife',
      label: 'Almoxarife',
      descricao: 'Gestão de estoque. Sem acesso à produção',
      icone: Icons.inventory_2,
      cor: Colors.green,
    ),
    _PerfilOpcao(
      valor: 'vendedor',
      label: 'Vendedor(a)',
      descricao: 'Consulta de OS e estoque. Somente leitura',
      icone: Icons.point_of_sale,
      cor: Colors.purple,
    ),
  ];

  // ── APROVAÇÃO ─────────────────────────────────────────────────────────────

  // Abre o diálogo de seleção de perfil antes de confirmar a aprovação.
  void _mostrarDialogoAprovacao(String uid, String email) {
    String perfilSelecionado = 'operador';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Aprovar Usuário'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('Selecione o perfil de acesso:'),
                const SizedBox(height: 8),
                ..._perfis.map((perfil) => RadioListTile<String>(
                  value: perfil.valor,
                  groupValue: perfilSelecionado,
                  onChanged: (v) =>
                      setDialogState(() => perfilSelecionado = v!),
                  title: Row(
                    children: [
                      Icon(perfil.icone, color: perfil.cor, size: 20),
                      const SizedBox(width: 8),
                      Text(perfil.label,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  subtitle: Text(
                    perfil.descricao,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Aprovar'),
              onPressed: () {
                Navigator.of(ctx).pop();
                _executarAprovacao(uid, perfilSelecionado);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executarAprovacao(String uid, String perfil) async {
    setState(() => _loadingStates[uid] = true);
    try {
      final provider = context.read<UsuarioProvider>();
      final empresaId = provider.usuario?.empresaId ?? '';

      // 1. Cloud Function: habilita no Auth e seta status 'aprovado'
      await provider.aprovar(uid);

      // 2. Atualiza o documento com o perfil e o empresaId do admin aprovador
      await provider.atualizar(uid, {
        'permissao': perfil,
        'empresaId': empresaId,
        'estacoesLiberadas': [],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Usuário aprovado como ${_labelDoPerfil(perfil)}!'),
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

  // ── RECUSA ────────────────────────────────────────────────────────────────

  void _mostrarDialogoRecusa(String email, String uid) {
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
              _executarRecusa(uid);
            },
            child: const Text('Excluir Permanentemente'),
          ),
        ],
      ),
    );
  }

  Future<void> _executarRecusa(String uid) async {
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

  // ── RECALCULAR CONTADORES ─────────────────────────────────────────────────

  void _mostrarDialogoRecalcular() {
    final empresaId =
        context.read<UsuarioProvider>().usuario?.empresaId ?? '';
    if (empresaId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível identificar a empresa do admin.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recalcular Contadores do Dashboard'),
        content: const Text(
          'Esta operação percorre todos os extintores em produção e '
              'reconstrói o placar de contadores do zero.\n\n'
              'Use apenas na inicialização do sistema ou se os números '
              'do dashboard estiverem incorretos.\n\n'
              'Pode levar alguns segundos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Recalcular'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _executarRecalculo(empresaId);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _executarRecalculo(String empresaId) async {
    setState(() => _recalculando = true);
    try {
      await context.read<UsuarioProvider>().recalcularContadores(empresaId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contadores recalculados com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao recalcular: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _recalculando = false);
    }
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  String _labelDoPerfil(String valor) =>
      _perfis.firstWhere((p) => p.valor == valor,
          orElse: () => const _PerfilOpcao(
              valor: '', label: 'Desconhecido',
              descricao: '', icone: Icons.help, cor: Colors.grey))
          .label;

  Color _corDoPerfil(String valor) =>
      _perfis.firstWhere((p) => p.valor == valor,
          orElse: () => const _PerfilOpcao(
              valor: '', label: '',
              descricao: '', icone: Icons.help, cor: Colors.grey))
          .cor;

  IconData _iconeDoPerfil(String valor) =>
      _perfis.firstWhere((p) => p.valor == valor,
          orElse: () => const _PerfilOpcao(
              valor: '', label: '',
              descricao: '', icone: Icons.help, cor: Colors.grey))
          .icone;

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aprovar Novos Usuários')),
      body: _recalculando
          ? const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Recalculando contadores...'),
          ],
        ),
      )
          : StreamBuilder<List<Map<String, dynamic>>>(
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
            padding: const EdgeInsets.all(16),
            itemCount: usuarios.length,
            itemBuilder: (context, index) {
              final data = usuarios[index];
              final uid = data['id'] as String;
              final email =
                  data['email'] as String? ?? 'E-mail não informado';
              final nome = data['nome'] as String? ?? 'Nome não informado';
              final isLoading = _loadingStates[uid] ?? false;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(nome,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                Text(email,
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Pendente',
                              style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (isLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.close,
                                  color: Colors.red, size: 18),
                              label: const Text('Recusar',
                                  style: TextStyle(color: Colors.red)),
                              onPressed: () =>
                                  _mostrarDialogoRecusa(email, uid),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Aprovar'),
                              onPressed: () =>
                                  _mostrarDialogoAprovacao(uid, email),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: _recalculando
          ? null
          : FloatingActionButton.extended(
        onPressed: _mostrarDialogoRecalcular,
        icon: const Icon(Icons.sync),
        label: const Text('Recalcular Contadores'),
        tooltip: 'Reconstruir placar do dashboard do zero',
      ),
    );
  }
}

// ── MODELO INTERNO DA TELA ────────────────────────────────────────────────

class _PerfilOpcao {
  final String valor;
  final String label;
  final String descricao;
  final IconData icone;
  final Color cor;

  const _PerfilOpcao({
    required this.valor,
    required this.label,
    required this.descricao,
    required this.icone,
    required this.cor,
  });
}