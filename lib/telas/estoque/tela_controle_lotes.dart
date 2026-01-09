// Salve como: lib/telas/producao/estoque/tela_controle_lotes_po.dart
// (VERSÃO v2.0 - Visual de Botões e Rastreabilidade Detalhada)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:provider/provider.dart';

class TelaControleLotesPo extends StatefulWidget {
  const TelaControleLotesPo({super.key});

  @override
  State<TelaControleLotesPo> createState() => _TelaControleLotesPoState();
}

class _TelaControleLotesPoState extends State<TelaControleLotesPo> {
  @override
  Widget build(BuildContext context) {
    final usuario = Provider
        .of<UsuarioProvider>(context)
        .usuario;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Controle de Pó Químico'),
        backgroundColor: Colors.brown.shade700,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade100,
      body: StreamBuilder<QuerySnapshot>(
        // Busca produtos marcados como 'controlarLote' (Seus Pós)
        stream: FirebaseFirestore.instance
            .collection('produtos')
            .where('empresaId', isEqualTo: usuario?.empresaId)
            .where('controlarLote', isEqualTo: true)
            .where('ativo', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final produtos = snapshot.data!.docs;
          if (produtos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                      Icons.science_outlined, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  const Text("Nenhum tipo de Pó cadastrado para controle.",
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 10),
                  TextButton(
                      onPressed: () {
                        /* Navegar para cadastro de produto */
                      },
                      child: const Text(
                          "Cadastrar Produto (Marcar 'Controlar Lote')")
                  )
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: produtos.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final prodDoc = produtos[index];
              final prodData = prodDoc.data() as Map<String, dynamic>;

              // Define cor baseada no nome para facilitar visualização
              final nome = prodData['nome'].toString().toUpperCase();
              Color corCard = Colors.brown;
              if (nome.contains('BC')) corCard = Colors.purple.shade700;
              if (nome.contains('ABC')) corCard = Colors.blue.shade800;
              if (nome.contains('55')) corCard = Colors.orange.shade800;

              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.only(bottom: 16),
                child: Theme(
                  data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    backgroundColor: Colors.white,
                    collapsedBackgroundColor: Colors.white,
                    leading: CircleAvatar(
                      backgroundColor: corCard.withOpacity(0.1),
                      child: Icon(Icons.science, color: corCard),
                    ),
                    title: Text(
                        prodData['nome'],
                        style: TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: corCard)
                    ),
                    subtitle: Text(
                      "Estoque Total: ${prodData['quantidadeAtual']} ${prodData['unidade'] ??
                          'kg'}",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    children: [
                      const Divider(),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8,
                            horizontal: 16),
                        color: Colors.grey.shade50,
                        child: const Text("LOTES DE COMPRA:", style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.grey)),
                      ),
                      // Sub-lista de Lotes
                      _buildListaLotes(prodDoc.id),
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

  Widget _buildListaLotes(String produtoId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('produtos')
          .doc(produtoId)
          .collection('lotes')
          .orderBy('validade') // Vencimentos primeiro
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()));

        final lotes = snapshot.data!.docs;
        if (lotes.isEmpty) return const Padding(padding: EdgeInsets.all(16),
            child: Center(child: Text("Nenhum lote registrado.")));

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: lotes.length,
          separatorBuilder: (c, i) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final lote = lotes[index].data() as Map<String, dynamic>;
            final loteId = lotes[index].id;

            final numero = lote['numero'] ?? '---';
            final saldo = (lote['quantidadeAtual'] ?? 0).toDouble();
            final qtdInicial = (lote['quantidadeInicial'] ?? 0).toDouble();

            String validadeStr = '???';
            bool vencido = false;

            if (lote['validade'] != null) {
              final valDate = (lote['validade'] as Timestamp).toDate();
              validadeStr = DateFormat('dd/MM/yyyy').format(valDate);
              if (valDate.isBefore(DateTime.now())) vencido = true;
            }

            // Visual do Status
            Color corStatus = Colors.green;
            if (saldo <= 0) corStatus = Colors.grey; // Acabou
            else if (vencido) corStatus = Colors.red; // Venceu

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 5),
              title: Row(
                children: [
                  Text("Lote: $numero",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  if (vencido && saldo > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text(
                          "VENCIDO", style: TextStyle(color: Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                    )
                ],
              ),
              subtitle: Text("Validade: $validadeStr"),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("${saldo.toStringAsFixed(1)} kg", style: TextStyle(
                      color: corStatus,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
                  Text("de ${qtdInicial.toStringAsFixed(1)} kg",
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              onTap: () => _mostrarRastreabilidade(produtoId, loteId, numero),
            );
          },
        );
      },
    );
  }

  // --- ONDE O PÓ FOI USADO ---
  // --- VERSÃO ATUALIZADA: COM AGRUPAMENTO POR OS ---
  void _mostrarRastreabilidade(String produtoId, String loteId,
      String numeroLote) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Column(
              children: [
                // Header do Modal
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.brown.shade50,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20))
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.history, color: Colors.brown),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                          "Rastreio: Lote $numeroLote", style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.brown))),
                      IconButton(onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close))
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('movimentacoes')
                        .where('loteId', isEqualTo: loteId)
                        .orderBy('data', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        // ... (código de erro de índice que já fizemos) ...
                        return const Center(child: Text(
                            "Erro ao carregar (Verifique o índice)."));
                      }
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());

                      final rawDocs = snapshot.data!.docs;

                      if (rawDocs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open, size: 50,
                                  color: Colors.grey.shade300),
                              const Text("Nenhuma movimentação ainda.",
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      }

                      // --- LÓGICA DE AGRUPAMENTO (SOMA POR OS) ---
                      final Map<String, Map<String, dynamic>> agrupadosPorOS = {
                      };
                      final List<Map<String, dynamic>> listaFinal = [];

                      for (var doc in rawDocs) {
                        final dados = doc.data() as Map<String, dynamic>;
                        final os = dados['numeroOS'];
                        final tipo = dados['tipo']; // 'saida' ou 'entrada'

                        // Se for SAÍDA e tiver OS, nós agrupamos
                        if (tipo == 'saida' && os != null && os
                            .toString()
                            .isNotEmpty) {
                          if (agrupadosPorOS.containsKey(os)) {
                            // Já existe essa OS na lista temporária? Soma a quantidade!
                            double qtdAtual = (agrupadosPorOS[os]!['quantidade'] ??
                                0).toDouble();
                            double qtdNova = (dados['quantidade'] ?? 0)
                                .toDouble();
                            agrupadosPorOS[os]!['quantidade'] =
                                qtdAtual + qtdNova;

                            // Incrementa contador de itens para exibir no subtítulo
                            int itens = agrupadosPorOS[os]!['contagemItens'] ??
                                1;
                            agrupadosPorOS[os]!['contagemItens'] = itens + 1;
                          } else {
                            // Primeira vez que vemos essa OS. Cria a entrada.
                            // Como a lista vem ordenada por data decrescente,
                            // a primeira que pegamos é a mais recente (data correta para exibir).
                            final clone = Map<String, dynamic>.from(dados);
                            clone['contagemItens'] = 1;
                            agrupadosPorOS[os] = clone;
                          }
                        } else {
                          // Se for Entrada de Estoque ou ajuste sem OS, não agrupa.
                          listaFinal.add(dados);
                        }
                      }

                      // Adiciona os agrupados na lista final
                      listaFinal.addAll(agrupadosPorOS.values);

                      // Reordena tudo por data (pois misturamos agrupados com não agrupados)
                      listaFinal.sort((a, b) {
                        Timestamp tA = a['data'];
                        Timestamp tB = b['data'];
                        return tB.compareTo(tA);
                      });
                      // -----------------------------------------------------------

                      return ListView.separated(
                        controller: controller,
                        padding: const EdgeInsets.all(16),
                        itemCount: listaFinal.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final m = listaFinal[index];
                          final data = DateFormat('dd/MM/yyyy HH:mm').format(
                              (m['data'] as Timestamp).toDate());

                          final isSaida = m['tipo'] == 'saida';
                          final colorMov = isSaida ? Colors.red : Colors.green;
                          final iconMov = isSaida
                              ? Icons.fire_extinguisher
                              : Icons.shopping_cart;

                          // Lógica do Subtítulo para mostrar "X Cilindros" quando agrupado
                          final int qtdItens = m['contagemItens'] ?? 1;
                          String detalheItem;

                          if (qtdItens > 1) {
                            detalheItem = "$qtdItens cilindros nesta OS";
                          } else {
                            // Se for item único ou entrada
                            detalheItem = m['equipamento'] != null
                                ? "Cilindro: ${m['equipamento']}"
                                : "";
                          }

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: colorMov.withOpacity(0.1),
                              child: Icon(iconMov, color: colorMov, size: 20),
                            ),
                            title: Text(isSaida
                                ? "OS: ${m['numeroOS'] ?? '---'}"
                                : "Entrada de Estoque"
                                , style: const TextStyle(
                                    fontWeight: FontWeight.bold)),

                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    data, style: const TextStyle(fontSize: 12)),
                                if (m['clienteNome'] != null)
                                  Text("Cliente: ${m['clienteNome']}",
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.black87)),
                                if (detalheItem.isNotEmpty)
                                  Text(detalheItem, style: const TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic)),
                              ],
                            ),
                            trailing: Text(
                              "${isSaida ? '-' : '+'}${m['quantidade']
                                  .toStringAsFixed(1)} kg",
                              // Mostra 1 casa decimal
                              style: TextStyle(color: colorMov,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}