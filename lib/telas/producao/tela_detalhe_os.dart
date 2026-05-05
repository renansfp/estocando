// lib/telas/producao/tela_detalhe_os.dart
// Migrada para Repository Pattern — sem acesso direto ao Firestore.

import 'package:cloud_firestore/cloud_firestore.dart'; // apenas Timestamp nos Maps
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/provider/ordem_servico_provider.dart';
import 'package:protecin_producao/services/gerador_pdf_os.dart';
import 'package:protecin_producao/provider/equipamento_provider.dart';
import 'package:protecin_producao/provider/parceiro_provider.dart';
import 'package:protecin_producao/services/relatorio_os_service.dart';
import 'package:protecin_producao/widgets/etiqueta_argox_visual.dart';

class TelaDetalhesOS extends StatelessWidget {
  final String osId;

  const TelaDetalhesOS({super.key, required this.osId});

  void _verFotoSelo(BuildContext context, String url, String titulo) {
    showDialog(
      context: context,
      builder: (context) {
        final size = MediaQuery.of(context).size;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: size.width * 0.9,
                  maxHeight: size.height * 0.85,
                ),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                          bottom: 10, right: 30, left: 10),
                      child: Text(
                        titulo,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (c, child, progress) {
                            if (progress == null) return child;
                            return const SizedBox(
                                height: 100,
                                width: 100,
                                child:
                                Center(child: CircularProgressIndicator()));
                          },
                          errorBuilder: (c, e, s) => const Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image,
                                    size: 50, color: Colors.grey),
                                Text('Erro ao carregar imagem'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 5,
                right: 5,
                child: IconButton(
                  icon: const CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.red,
                      child: Icon(Icons.close, color: Colors.white, size: 16)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _abrirVisualizacaoEtiqueta(
      BuildContext context,
      Map<String, dynamic> item,
      Map<String, dynamic> dadosOS,
      String docId) {
    DateTime dataBase = DateTime.now();
    if (item['data_finalizacao'] != null) {
      dataBase = (item['data_finalizacao'] as Timestamp).toDate();
    }

    DateTime dataN2 =
    DateTime(dataBase.year + 1, dataBase.month, dataBase.day);
    String n2 = DateFormat('MM/yyyy').format(dataN2);

    String n3;
    if (item['servico_realizado']?.toString().contains('Nivel III') ?? false) {
      n3 = (dataBase.year + 5).toString();
    } else {
      try {
        String ultimoTH = item['anoUltimoTH']?.toString() ?? '';
        if (ultimoTH.length >= 7) {
          int anoRef = int.parse(ultimoTH.split('/').last);
          n3 = (anoRef + 5).toString();
        } else {
          n3 = 'VERIF.';
        }
      } catch (e) {
        n3 = 'VERIF.';
      }
    }

    String numFab = item['ativoFixo'] ??
        item['numero_fabricacao'] ??
        item['numeroCilindro'] ??
        '---';
    String servico = item['servico_realizado'] ?? 'Manutenção Nível II';

    showDialog(
      context: context,
      builder: (context) => EtiquetaArgoxVisual(
        docId: docId,
        clienteNome: dadosOS['clienteNome'] ?? 'Consumidor',
        clienteId: dadosOS['clienteId'] ?? '000',
        tipoExtintor: item['tipoAgente'] ?? 'PQS',
        lote: dadosOS['numeroOS'].toString(),
        numeroFabricacao: numFab,
        servicoRealizado: servico,
        proximaManutencaoN2: n2,
        proximaManutencaoN3: n3,
        nomeImpressora: 'Argox OS-214 plus series PPLA',
      ),
    );
  }

  Future<void> _gerarDocumento(BuildContext context, String tipo) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );
    try {
      if (tipo == 'relatorio') {
        final dados = await RelatorioOsService(
          buscarOS: context.read<OrdemServicoProvider>().buscarPorId,
          buscarParceiro: context.read<ParceiroProvider>().buscarPorId,
          buscarItens: context.read<ItemOsProvider>().buscarItensComDadosCompletos,
          buscarEquipamento: context.read<EquipamentoProvider>().buscarPorId,
        ).buscarDados(osId);
        if (context.mounted) {
          Navigator.pop(context);
          await GeradorPdfOS().abrirPreview(context, dados);
        }
      } else {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Em desenvolvimento...')));
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Color _getCorStatus(String status) {
    status = status.toLowerCase();
    if (status.contains('finaliz') || status.contains('pronto')) {
      return Colors.green;
    }
    if (status.contains('cancel')) return Colors.grey;
    if (status.contains('produ') || status.contains('andamento')) {
      return Colors.orange;
    }
    return Colors.blue;
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
            onSelected: (value) => _gerarDocumento(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'relatorio',
                  child: Text('Relatório Técnico A4')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: context
            .read<OrdemServicoProvider>()
            .streamPorId(osId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final os = snapshot.data;
          if (os == null) {
            return const Center(child: Text('OS não encontrada.'));
          }

          String dataEntrada = '---';
          final campoData = os['dataEntrada'] ?? os['dataAbertura'];
          if (campoData != null) {
            try {
              dataEntrada = DateFormat('dd/MM/yyyy HH:mm')
                  .format((campoData as Timestamp).toDate());
            } catch (_) {}
          }
          final statusGeral =
              os['statusLote'] ?? os['statusGeral'] ?? 'ABERTA';

          return Column(
            children: [
              // Cabeçalho
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
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade900),
                        ),
                        Chip(
                          label: Text(
                            statusGeral
                                .toString()
                                .toUpperCase()
                                .replaceAll('_', ' '),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          backgroundColor:
                          _getCorStatus(statusGeral.toString()),
                        ),
                      ],
                    ),
                    Text(
                      os['clienteNome'] ?? 'Cliente Desconhecido',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Data Entrada: $dataEntrada - Itens: ${os['quantidadeTotal'] ?? 0}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Lista de itens
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: context
                      .read<ItemOsProvider>()
                      .streamItensPorOs(osId),
                  builder: (ctx, snapItens) {
                    if (!snapItens.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final itens = snapItens.data!;
                    if (itens.isEmpty) {
                      return const Center(
                          child: Text('Nenhum item encontrado.'));
                    }

                    return ListView.builder(
                      itemCount: itens.length,
                      itemBuilder: (ctx, index) {
                        final item = itens[index];
                        final docId = item['id'] as String;

                        String? urlFotoSelo;
                        if (item['montagem'] != null &&
                            item['montagem']['selo_foto_url'] != null) {
                          urlFotoSelo = item['montagem']['selo_foto_url'];
                        }

                        String statusItem =
                            item['status'] ?? 'AGUARDANDO';
                        statusItem = statusItem
                            .replaceAll('aguardando_', '')
                            .replaceAll('_', ' ')
                            .toUpperCase();

                        bool temPeso = item['montagem'] != null &&
                            item['montagem']['peso_final'] != null;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            leading: CircleAvatar(
                              backgroundColor: urlFotoSelo != null
                                  ? Colors.green[100]
                                  : Colors.grey.shade200,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                    color: Colors.red.shade900,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              '${item['tipoAgente'] ?? 'Item'} ${item['carga'] ?? ''}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Cilindro: ${item['numeroCilindro'] ?? item['ativoFixo'] ?? 'S/N'}'),
                                Text(
                                  'Crachá: ${item['idCrachaTemporario'] ?? ''}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.qr_code_2,
                                      color: temPeso
                                          ? Colors.orange[800]
                                          : Colors.grey[400]),
                                  tooltip: 'Visualizar Etiqueta Argox',
                                  onPressed: () =>
                                      _abrirVisualizacaoEtiqueta(
                                          context, item, os, docId),
                                ),
                                if (urlFotoSelo != null)
                                  IconButton(
                                    icon: const Icon(Icons.photo_camera,
                                        color: Colors.blue, size: 30),
                                    tooltip: 'Ver Foto do Selo',
                                    onPressed: () => _verFotoSelo(
                                      context,
                                      urlFotoSelo!,
                                      'Selo: ${item['idCrachaTemporario']}',
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blueGrey[50],
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: Colors.blueGrey[200]!),
                                  ),
                                  child: Text(
                                    statusItem,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blueGrey[800],
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
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
}