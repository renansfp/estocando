// lib/telas/admin/tela_gestao_acesso.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/models/usuario.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';

class TelaGestaoAcesso extends StatelessWidget {
  const TelaGestaoAcesso({super.key});

  @override
  Widget build(BuildContext context) {
    final adminLogado = context.read<UsuarioProvider>().usuario!;

    return Scaffold(
      appBar: AppBar(title: const Text('Gestão de Acesso')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: context
            .read<UsuarioProvider>()
            .streamUsuariosPorEmpresa(adminLogado.empresaId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Erro ao carregar usuários.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Exclui o próprio usuário logado da lista
          final usuarios = snapshot.data!
              .where((u) => u['id'] != adminLogado.uid)
              .map((u) => Usuario.fromMap(u, u['id'] as String))
              .where((u) => u.status == 'aprovado')
              .toList()
            ..sort((a, b) => a.nome.compareTo(b.nome));

          if (usuarios.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum outro usuário aprovado na empresa.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: usuarios.length,
            itemBuilder: (context, index) {
              final usuario = usuarios[index];
              return _CardUsuario(
                usuario: usuario,
                adminLogado: adminLogado,
              );
            },
          );
        },
      ),
    );
  }
}

// ── CARD DE USUÁRIO ───────────────────────────────────────────────────────

class _CardUsuario extends StatelessWidget {
  final Usuario usuario;
  final Usuario adminLogado;

  const _CardUsuario({required this.usuario, required this.adminLogado});

  // Líder só pode gerenciar estações de operadores
  // Admin pode gerenciar estações de qualquer um que não seja admin
  bool get _podeGerenciarEstacoes {
    if (adminLogado.isAdmin) return !usuario.isAdmin;
    if (adminLogado.isLider) return usuario.isOperador;
    return false;
  }

  // Só admin pode alterar perfil — e nunca de outro admin
  bool get _podeAlterarPerfil {
    return adminLogado.isAdmin && !usuario.isAdmin;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _abrirPainelUsuario(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: _corDoPerfil(usuario.permissao).withValues(alpha: 0.15),
                child: Icon(
                  _iconeDoPerfil(usuario.permissao),
                  color: _corDoPerfil(usuario.permissao),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(usuario.nome,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(usuario.email,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _BadgePerfil(perfil: usuario.permissao),
                  if (usuario.isOperador) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${usuario.estacoesLiberadas.length}/13 estações',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _abrirPainelUsuario(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PainelUsuario(
        usuario: usuario,
        adminLogado: adminLogado,
        podeGerenciarEstacoes: _podeGerenciarEstacoes,
        podeAlterarPerfil: _podeAlterarPerfil,
      ),
    );
  }
}

// ── PAINEL INFERIOR DO USUÁRIO ────────────────────────────────────────────

class _PainelUsuario extends StatefulWidget {
  final Usuario usuario;
  final Usuario adminLogado;
  final bool podeGerenciarEstacoes;
  final bool podeAlterarPerfil;

  const _PainelUsuario({
    required this.usuario,
    required this.adminLogado,
    required this.podeGerenciarEstacoes,
    required this.podeAlterarPerfil,
  });

  @override
  State<_PainelUsuario> createState() => _PainelUsuarioState();
}

class _PainelUsuarioState extends State<_PainelUsuario> {
  late Set<String> _estacoesLiberadas;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _estacoesLiberadas = Set.from(widget.usuario.estacoesLiberadas);
  }

  Future<void> _toggleEstacao(String estacao) async {
    if (!widget.podeGerenciarEstacoes) return;

    final novasEstacoes = Set<String>.from(_estacoesLiberadas);
    if (novasEstacoes.contains(estacao)) {
      novasEstacoes.remove(estacao);
    } else {
      novasEstacoes.add(estacao);
    }

    setState(() {
      _estacoesLiberadas = novasEstacoes;
      _salvando = true;
    });

    try {
      await context.read<UsuarioProvider>().atualizar(
        widget.usuario.uid,
        {'estacoesLiberadas': novasEstacoes.toList()},
      );
    } catch (e) {
      // Reverte em caso de erro
      setState(() => _estacoesLiberadas = Set.from(widget.usuario.estacoesLiberadas));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _mostrarDialogoAlterarPerfil() {
    String perfilSelecionado = widget.usuario.permissao;

    // Perfis que admin pode atribuir (não pode dar admin para outro)
    const perfisDisponiveis = ['lider', 'operador', 'almoxarife', 'vendedor'];
    const labels = {
      'lider':      ('Líder', Icons.star, Colors.orange),
      'operador':   ('Operador', Icons.engineering, Colors.blue),
      'almoxarife': ('Almoxarife', Icons.inventory_2, Colors.green),
      'vendedor':   ('Vendedor(a)', Icons.point_of_sale, Colors.purple),
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Alterar Perfil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: perfisDisponiveis.map((perfil) {
              final (label, icone, cor) = labels[perfil]!;
              return RadioListTile<String>(
                value: perfil,
                groupValue: perfilSelecionado,
                onChanged: (v) => setDialogState(() => perfilSelecionado = v!),
                title: Row(
                  children: [
                    Icon(icone, color: cor, size: 18),
                    const SizedBox(width: 8),
                    Text(label),
                  ],
                ),
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _salvarNovoPerfil(perfilSelecionado);
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _salvarNovoPerfil(String novoPerfil) async {
    setState(() => _salvando = true);
    try {
      await context.read<UsuarioProvider>().atualizar(
        widget.usuario.uid,
        {
          'permissao': novoPerfil,
          // Se virou operador, mantém as estações. Se virou outro perfil, limpa.
          if (novoPerfil != 'operador') 'estacoesLiberadas': [],
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Fecha o painel
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOperador = widget.usuario.isOperador;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Cabeçalho
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                  _corDoPerfil(widget.usuario.permissao).withValues(alpha: 0.15),
                  child: Icon(
                    _iconeDoPerfil(widget.usuario.permissao),
                    color: _corDoPerfil(widget.usuario.permissao),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.usuario.nome,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 17)),
                      Text(widget.usuario.email,
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                if (_salvando)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

          // Perfil atual + botão de alterar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                _BadgePerfil(perfil: widget.usuario.permissao),
                const Spacer(),
                if (widget.podeAlterarPerfil)
                  TextButton.icon(
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Alterar perfil'),
                    onPressed: _mostrarDialogoAlterarPerfil,
                  ),
              ],
            ),
          ),

          const Divider(),

          // Estações (só para operadores)
          if (!isOperador)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    widget.usuario.isLider
                        ? 'Líderes têm acesso a todas as estações de produção automaticamente.'
                        : widget.usuario.isAlmoxarife
                        ? 'Almoxarifes não têm acesso às estações de produção.'
                        : widget.usuario.isVendedor
                        ? 'Vendedores têm acesso somente a OS e estoque.'
                        : 'Este perfil não utiliza controle de estações.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                  ),
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Estações liberadas (${_estacoesLiberadas.length}/13)',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const Spacer(),
                  if (widget.podeGerenciarEstacoes) ...[
                    TextButton(
                      onPressed: _salvando ? null : _liberarTodas,
                      child: const Text('Liberar todas'),
                    ),
                    TextButton(
                      onPressed: _salvando ? null : _revogarTodas,
                      child: Text('Revogar todas',
                          style: TextStyle(color: Colors.red.shade400)),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: EstacaoProducao.todas.map((estacao) {
                  final liberada = _estacoesLiberadas.contains(estacao);
                  final nome = EstacaoProducao.nomeExibicao[estacao] ?? estacao;

                  return SwitchListTile(
                    value: liberada,
                    onChanged: widget.podeGerenciarEstacoes && !_salvando
                        ? (_) => _toggleEstacao(estacao)
                        : null,
                    title: Text(nome),
                    secondary: Icon(
                      liberada ? Icons.lock_open : Icons.lock_outline,
                      color: liberada ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    dense: true,
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _liberarTodas() async {
    setState(() {
      _estacoesLiberadas = Set.from(EstacaoProducao.todas);
      _salvando = true;
    });
    try {
      await context.read<UsuarioProvider>().atualizar(
        widget.usuario.uid,
        {'estacoesLiberadas': EstacaoProducao.todas},
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _revogarTodas() async {
    setState(() {
      _estacoesLiberadas = {};
      _salvando = true;
    });
    try {
      await context.read<UsuarioProvider>().atualizar(
        widget.usuario.uid,
        {'estacoesLiberadas': []},
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }
}

// ── WIDGETS AUXILIARES ────────────────────────────────────────────────────

class _BadgePerfil extends StatelessWidget {
  final String perfil;
  const _BadgePerfil({required this.perfil});

  @override
  Widget build(BuildContext context) {
    final cor = _corDoPerfil(perfil);
    final label = _labelDoPerfil(perfil);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: cor, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── HELPERS GLOBAIS DA TELA ───────────────────────────────────────────────

Color _corDoPerfil(String perfil) => switch (perfil) {
  'admin'      => Colors.red,
  'lider'      => Colors.orange,
  'operador'   => Colors.blue,
  'almoxarife' => Colors.green,
  'vendedor'   => Colors.purple,
  _            => Colors.grey,
};

IconData _iconeDoPerfil(String perfil) => switch (perfil) {
  'admin'      => Icons.admin_panel_settings,
  'lider'      => Icons.star,
  'operador'   => Icons.engineering,
  'almoxarife' => Icons.inventory_2,
  'vendedor'   => Icons.point_of_sale,
  _            => Icons.person,
};

String _labelDoPerfil(String perfil) => switch (perfil) {
  'admin'      => 'Admin',
  'lider'      => 'Líder',
  'operador'   => 'Operador',
  'almoxarife' => 'Almoxarife',
  'vendedor'   => 'Vendedor(a)',
  _            => perfil,
};