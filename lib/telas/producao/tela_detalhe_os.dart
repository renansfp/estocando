// Salve como: lib/telas/producao/tela_detalhe_os.dart
// (VERSÃO CORRIGIDA - Busca itens na coleção raiz 'itens_os')

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:protecin_producao/services/gerador_pdf_os.dart';

class TelaDetalhesOS extends StatefulWidget {
  final String osId;

  const TelaDetalhesOS({
    super.key,
    required this.osId,
  });

  @override
  State<TelaDetalhesOS> createState() => _TelaDetalhesOSState();
}

class _TelaDetalhesOSState extends State<TelaDetalhesOS> {
  final _firestore = FirebaseFirestore.instance;

  // --- LÓGICA DE GERAÇÃO DE DOCUMENTOS (IMPRESSÃO) ---
  Future<void> _gerarDocumento(String tipo) async {
    // 1. Mostrar Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 2. Buscar dados frescos da OS
      final docOS = await _firestore.collection('ordens_servico').doc(widget.osId).get();

      // --- CORREÇÃO AQUI (IMPRESSÃO): Busca na coleção 'itens_os' ---
      final colItens = await _firestore
          .collection('itens_os')
          .where('osId', isEqualTo: widget.osId) // Filtra pelo ID da OS
      // .orderBy('numeroSequencial') // Se tiver esse campo, pode descomentar
          .get();

      if (!docOS.exists) throw 'OS não encontrada no banco de dados.';

      final dadosOS = docOS.data() as Map<String, dynamic>;

      // Converte os documentos dos itens em uma lista simples de Mapas
      final listaItens = colItens.docs.map((d) => d.data()).toList();

      // 3. Fechar o Loading
      if (mounted) Navigator.pop(context);

      // 4. Chamar o Gerador de PDF
      final gerador = GeradorPdfOS();

      if (tipo == 'relatorio') {
        await gerador.gerarRelatorioTecnico(dadosOS, listaItens);
      } else if (tipo == 'etiqueta') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impressão de Etiquetas: Em desenvolvimento...')),
          );
        }
      }

    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Fecha loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar documento: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da OS'),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.print),
            tooltip: 'Imprimir Documentos',
            onSelected: (value) => _gerarDocumento(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'relatorio',
                child: Row(
                  children: [
                    Icon(Icons.description, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Relatório Técnico A4'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('ordens_servico').doc(widget.osId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Erro ao carregar OS'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final os = snapshot.data!.data() as Map<String, dynamic>?;

          if (os == null) {
            return const Center(child: Text('OS não encontrada ou excluída.'));
          }

          // Formatação de Datas e Campos
          String dataEntrada = '---';
          // Tenta ler dataEntrada (padrão novo) ou dataAbertura (antigo)
          var campoData = os['dataEntrada'] ?? os['dataAbertura'];
          if (campoData != null) {
            try {
              dataEntrada = DateFormat('dd/MM/yyyy HH:mm').format((campoData as Timestamp).toDate());
            } catch (e) {}
          }

          final statusGeral = os['statusLote'] ?? os['statusGeral'] ?? 'ABERTA';

          return Column(
            children: [
              // --- CABEÇALHO DA OS ---
              Container(
                color: Colors.red.shade50,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'OS #${os['numeroOS']}',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                        ),
                        Chip(
                          label: Text(
                              statusGeral.toString().toUpperCase().replaceAll('_', ' '),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                          ),
                          backgroundColor: _getCorStatus(statusGeral.toString()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.business, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            os['clienteNome'] ?? 'Cliente Desconhecido',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Data Entrada: $dataEntrada', style: TextStyle(color: Colors.grey.shade700)),
                    Text('Total de Itens: ${os['quantidadeTotal'] ?? os['quantidadeItens'] ?? 0}', style: TextStyle(color: Colors.grey.shade700)),
                  ],
                ),
              ),

              const Divider(height: 1),

              // --- LISTA DE ITENS DA OS ---
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  // --- CORREÇÃO AQUI (LISTA): Busca na coleção 'itens_os' ---
                  stream: _firestore
                      .collection('itens_os')
                      .where('osId', isEqualTo: widget.osId) // O Filtro Mágico
                  // .orderBy('numeroSequencial') // (Opcional, ative se tiver o índice)
                      .snapshots(),
                  builder: (ctx, snapItens) {
                    if (!snapItens.hasData) return const Center(child: CircularProgressIndicator());

                    final itens = snapItens.data!.docs;

                    if (itens.isEmpty) {
                      return const Center(child: Text('Nenhum item encontrado nesta OS.'));
                    }

                    return ListView.builder(
                      itemCount: itens.length,
                      itemBuilder: (ctx, index) {
                        final item = itens[index].data() as Map<String, dynamic>;

                        // Tratamento visual para o status
                        String statusItem = item['status'] ?? 'AGUARDANDO';
                        statusItem = statusItem.replaceAll('aguardando_', '').replaceAll('_', ' ').toUpperCase();

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey.shade200,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text('${item['tipoAgente'] ?? 'Item'} - ${item['idCrachaTemporario'] ?? ''}'),
                          // subtitle: Text('Cilindro: ${item['numeroCilindro'] ?? '-'}'), // Se tiver esse dado
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.blueGrey[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blueGrey[200]!)
                            ),
                            child: Text(
                              statusItem,
                              style: TextStyle(fontSize: 10, color: Colors.blueGrey[800], fontWeight: FontWeight.bold),
                            ),
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
      ),
    );
  }

  Color _getCorStatus(String status) {
    status = status.toLowerCase();
    if (status.contains('finaliz') || status.contains('pronto')) return Colors.green;
    if (status.contains('cancel')) return Colors.grey;
    if (status.contains('produ') || status.contains('andamento')) return Colors.orange;
    return Colors.blue;
  }
}