// Salve como: lib/telas/producao/estacao/tela_estacao_descarga.dart
// (VERSÃO v2.3 - Com Atalho para Controle de Lotes)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/models/item_os.dart';
import 'package:protecin_producao/models/usuario.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_balanco_lote.dart';
// IMPORTANTE: Importe a tela de controle que criamos
import 'package:protecin_producao/telas/producao/estacao/tela_controle_descarga.dart';

class TelaEstacaoDescarga extends StatefulWidget {
  final List<String> filtrosAgente;
  final String tituloEstacao;

  const TelaEstacaoDescarga({
    super.key,
    required this.filtrosAgente,
    required this.tituloEstacao,
  });

  @override
  State<TelaEstacaoDescarga> createState() => _TelaEstacaoDescargaState();
}

class _TelaEstacaoDescargaState extends State<TelaEstacaoDescarga> {
  @override
  Widget build(BuildContext context) {
    final usuario = Provider.of<UsuarioProvider>(context, listen: false).usuario;
    if (usuario == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: const Center(child: Text('Usuário não carregado.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tituloEstacao),
        backgroundColor: Colors.blueGrey,
        actions: [
          // --- O NOVO BOTÃO AQUI ---
          IconButton(
            icon: const Icon(Icons.fact_check, color: Colors.white), // Ícone de Checklist
            tooltip: 'Painel de Controle (Liberar Lotes)',
            onPressed: () {
              // Navega direto para a tela de controle/gerenciamento
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TelaControleDescarga(),
                ),
              );
            },
          ),
        ],
      ),
      body: _buildListaDeLotes(usuario),
    );
  }

  Widget _buildListaDeLotes(Usuario usuario) {
    final query = FirebaseFirestore.instance
        .collection('itens_os')
        .where('empresaId', isEqualTo: usuario.empresaId)
        .where('status', isEqualTo: 'aguardando_descarga')
        .where('tipoAgente', whereIn: widget.filtrosAgente);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erro: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                SizedBox(height: 20),
                Text(
                  'Tudo limpo por aqui!',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                Text(
                  'Nenhum item aguardando descarga neste setor.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final itensCrus = snapshot.data!.docs;
        final Map<String, List<ItemOS>> lotesAgrupados = {};

        for (final doc in itensCrus) {
          final item = ItemOS.fromJson(
            doc.data() as Map<String, dynamic>,
            doc.id,
          );
          final osId = item.osId;

          if (!lotesAgrupados.containsKey(osId)) {
            lotesAgrupados[osId] = [];
          }
          lotesAgrupados[osId]!.add(item);
        }

        final osIds = lotesAgrupados.keys.toList();

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: osIds.length,
          itemBuilder: (context, index) {
            final osId = osIds[index];
            final itensDoLote = lotesAgrupados[osId]!;
            final contagem = itensDoLote.length;

            final String idVisual = osId.length > 6
                ? '...${osId.substring(osId.length - 6)}'
                : osId;

            return Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    '$contagem',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  'Lote (OS): $idVisual',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                    '$contagem Itens (${widget.tituloEstacao}) aguardando'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TelaBalancoLote(
                        osId: osId,
                        filtrosAgente: widget.filtrosAgente,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}