// lib/widgets/seletor_operador.dart
//
// Widget reutilizável para selecionar o operador ativo em qualquer estação.
//
// USO — adicionar no AppBar de cada tela de estação:
//
//   AppBar(
//     title: Text('Descarga'),
//     actions: [
//       SeletorOperador(estacao: EstacaoProducao.descarga),
//     ],
//   )
//
// O widget lê o operadorAtivo do UsuarioProvider e abre um dialog
// com todos os operadores habilitados para a estação ao ser tocado.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/models/usuario.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';

class SeletorOperador extends StatelessWidget {
  /// Chave da estação — ex: EstacaoProducao.descarga, EstacaoProducao.recarga
  final String estacao;

  const SeletorOperador({super.key, required this.estacao});

  @override
  Widget build(BuildContext context) {
    return Consumer<UsuarioProvider>(
      builder: (context, provider, _) {
        final operador = provider.operadorAtivo;
        final nome = operador?.nome ?? 'Operador';
        // Mostra só o primeiro nome para não ocupar espaço demais no AppBar
        final primeiroNome = nome.split(' ').first;

        return TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          icon: const Icon(Icons.swap_horiz, size: 18),
          label: Text(
            primeiroNome,
            style: const TextStyle(fontSize: 13),
          ),
          onPressed: () => _abrirDialog(context, provider),
        );
      },
    );
  }

  Future<void> _abrirDialog(
      BuildContext context, UsuarioProvider provider) async {
    final empresaId = provider.usuario?.empresaId ?? '';
    if (empresaId.isEmpty) return;

    // Carrega operadores habilitados para esta estação
    List<Map<String, dynamic>> operadores = [];
    bool carregando = true;
    String? erro;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            // Carrega na primeira vez que o dialog aparece
            if (carregando) {
              provider
                  .buscarOperadoresPorEstacao(empresaId, estacao)
                  .then((lista) {
                if (ctx.mounted) {
                  setStateDialog(() {
                    operadores = lista;
                    carregando = false;
                  });
                }
              }).catchError((e) {
                if (ctx.mounted) {
                  setStateDialog(() {
                    erro = e.toString();
                    carregando = false;
                  });
                }
              });
            }

            return AlertDialog(
              title: const Text('Quem está operando?'),
              content: SizedBox(
                width: double.maxFinite,
                child: carregando
                    ? const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                )
                    : erro != null
                    ? Text('Erro ao carregar: $erro',
                    style: const TextStyle(color: Colors.red))
                    : operadores.isEmpty
                    ? const Text(
                    'Nenhum operador habilitado para esta estação.')
                    : ListView.builder(
                  shrinkWrap: true,
                  itemCount: operadores.length,
                  itemBuilder: (_, i) {
                    final op = operadores[i];
                    final nome =
                        op['nome'] as String? ?? 'Sem nome';
                    final permissao =
                        op['permissao'] as String? ?? '';
                    final isAtivo =
                        provider.operadorAtivo?.uid == op['id'];

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isAtivo
                            ? Colors.blue
                            : Colors.grey[300],
                        child: Text(
                          nome.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: isAtivo
                                ? Colors.white
                                : Colors.black54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(nome),
                      subtitle: Text(
                        _labelPermissao(permissao),
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: isAtivo
                          ? const Icon(Icons.check_circle,
                          color: Colors.blue)
                          : null,
                      onTap: () {
                        final novoOperador = Usuario.fromMap(
                          op,
                          op['id'] as String,
                        );
                        provider.trocarOperador(novoOperador);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _labelPermissao(String permissao) {
    switch (permissao.toLowerCase()) {
      case 'admin':
        return 'Administrador';
      case 'lider':
        return 'Líder';
      case 'operador':
        return 'Operador';
      default:
        return permissao;
    }
  }
}