// Salve como: lib/telas/producao/tela_detalhe_os.dart
// (VERSÃO COM VISUALIZAÇÃO DE FOTO DO SELO)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:protecin_producao/services/gerador_pdf_os.dart';
import 'package:protecin_producao/services/relatorio_os_service.dart';
import 'package:protecin_producao/widgets/etiqueta_argox_visual.dart';

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

  // --- FUNÇÃO PARA VER A FOTO (CORRIGIDA PARA WEB E CELULAR) ---
  void _verFotoSelo(String url, String titulo) {
    showDialog(
      context: context,
      builder: (context) {
        // Pega o tamanho real da tela onde o app está rodando
        final size = MediaQuery.of(context).size;

        return Dialog(
          backgroundColor: Colors.transparent, // Fundo transparente
          insetPadding: const EdgeInsets.all(10), // Margem da borda
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                // A MÁGICA ESTÁ AQUI:
                // Define que o popup nunca será maior que 90% da largura
                // e 85% da altura da tela atual.
                constraints: BoxConstraints(
                  maxWidth: size.width * 0.9,
                  maxHeight: size.height * 0.85,
                ),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10)
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Encolhe o container para caber o conteúdo
                  children: [
                    // Título (com espaço para o botão X não ficar em cima)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, right: 30, left: 10),
                      child: Text(
                        titulo,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // A Imagem Controlada
                    Flexible( // Flexible permite que a imagem encolha se a tela for pequena
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Image.network(
                          url,
                          // CONTAIN é essencial: Mostra a imagem inteira sem cortar nada,
                          // mesmo que sobre espaço branco nas laterais
                          fit: BoxFit.contain,
                          loadingBuilder: (c, child, progress) {
                            if (progress == null) return child;
                            return const SizedBox(
                                height: 100,
                                width: 100,
                                child: Center(child: CircularProgressIndicator())
                            );
                          },
                          errorBuilder: (c, e, s) => const Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                Text("Erro ao carregar imagem")
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Botão Fechar (X)
              Positioned(
                top: 5,
                right: 5,
                child: IconButton(
                  icon: const CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.red,
                      child: Icon(Icons.close, color: Colors.white, size: 16)
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  // Dentro de _TelaDetalhesOSState ...

  // Dentro de _TelaDetalhesOSState na TelaDetalhesOS...

  void _abrirVisualizacaoEtiqueta(Map<String, dynamic> item, Map<String, dynamic> dadosOS, String docId) {
    // Tratamento de datas
    DateTime dataBase = DateTime.now();
    if (item['data_finalizacao'] != null) {
      dataBase = (item['data_finalizacao'] as Timestamp).toDate();
    }

    DateTime dataN2 = DateTime(dataBase.year + 1, dataBase.month, dataBase.day);
    String n2 = DateFormat('MM/yyyy').format(dataN2);

    // 2. Teste Hidrostático (Lógica Inteligente)
    String n3;

    // Se o serviço que você está fazendo agora for Nível 3, aí sim soma 5 anos
    if (item['servico_realizado']?.toString().contains('Nivel III') ?? false) {
      n3 = (dataBase.year + 5).toString();
    } else {
      try {
        String ultimoTH = item['anoUltimoTH']?.toString() ?? "";
        if (ultimoTH.length >= 7) { // Se for formato MM/AAAA
          int anoRef = int.parse(ultimoTH.split('/').last);
          n3 = (anoRef + 5).toString();
        } else {
          n3 = "VERIF.";
        }
      } catch (e) {
        n3 = "VERIF.";
      }
    }
    // Agora priorizamos o campo 'ativoFixo' que vem do cadastro do equipamento
    String numFab = item['ativoFixo'] ?? item['numero_fabricacao'] ?? item['numeroCilindro'] ?? '---';

    // Tratamento do Serviço
    String servico = item['servico_realizado'] ?? 'Manutenção Nível II';

    showDialog(
      context: context,
      builder: (context) => EtiquetaArgoxVisual(
        docId: docId,
        clienteNome: dadosOS['clienteNome'] ?? 'Consumidor',
        clienteId: dadosOS['clienteId'] ?? '000',
        tipoExtintor: item['tipoAgente'] ?? 'PQS',
        lote: dadosOS['numeroOS'].toString(),

        // Passamos o ativoFixo aqui para gerar o QR Code correto
        numeroFabricacao: numFab,

        servicoRealizado: servico,
        proximaManutencaoN2: n2,
        proximaManutencaoN3: n3,
        nomeImpressora: "Argox OS-214 plus series PPLA",
      ),
    );
  }

  // --- LÓGICA DE GERAÇÃO DE DOCUMENTOS ---
  Future<void> _gerarDocumento(String tipo) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );
    try {
      if (tipo == 'relatorio') {
        final dados = await RelatorioOsService().buscarDados(widget.osId);
        if (mounted) {
          Navigator.pop(context); // fecha o loading
          await GeradorPdfOS().abrirPreview(context, dados);
        }
      } else {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Em desenvolvimento...')));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
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
            onSelected: (value) => _gerarDocumento(value),
            itemBuilder: (context) => [const PopupMenuItem(value: 'relatorio', child: Text('Relatório Técnico A4'))],
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('ordens_servico').doc(widget.osId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final os = snapshot.data!.data() as Map<String, dynamic>?;
          if (os == null) return const Center(child: Text('OS não encontrada.'));

          String dataEntrada = '---';
          var campoData = os['dataEntrada'] ?? os['dataAbertura'];
          if (campoData != null) {
            try {
              dataEntrada = DateFormat('dd/MM/yyyy HH:mm').format((campoData as Timestamp).toDate());
            } catch (e) {}
          }
          final statusGeral = os['statusLote'] ?? os['statusGeral'] ?? 'ABERTA';

          return Column(
            children: [
              // CABEÇALHO
              Container(
                color: Colors.red.shade50,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('OS #${os['numeroOS']}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                        Chip(label: Text(statusGeral.toString().toUpperCase().replaceAll('_', ' '), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: _getCorStatus(statusGeral.toString())),
                      ],
                    ),
                    Text(os['clienteNome'] ?? 'Cliente Desconhecido', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                    Text('Data Entrada: $dataEntrada - Itens: ${os['quantidadeTotal'] ?? 0}', style: TextStyle(color: Colors.grey.shade700)),
                  ],
                ),
              ),
              const Divider(height: 1),

              // LISTA DE ITENS
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('itens_os').where('osId', isEqualTo: widget.osId).snapshots(),
                  builder: (ctx, snapItens) {
                    if (!snapItens.hasData) return const Center(child: CircularProgressIndicator());
                    final itens = snapItens.data!.docs;
                    if (itens.isEmpty) return const Center(child: Text('Nenhum item encontrado.'));

                    return ListView.builder(
                      itemCount: itens.length,
                      itemBuilder: (ctx, index) {
                        final item = itens[index].data() as Map<String, dynamic>;

                        // Busca a URL da foto (se existir)
                        String? urlFotoSelo;
                        if (item['montagem'] != null && item['montagem']['selo_foto_url'] != null) {
                          urlFotoSelo = item['montagem']['selo_foto_url'];
                        }

                        // Status do Texto
                        String statusItem = item['status'] ?? 'AGUARDANDO';
                        statusItem = statusItem.replaceAll('aguardando_', '').replaceAll('_', ' ').toUpperCase();

                        // Verifica se tem peso final (para pintar o ícone da etiqueta de laranja ou cinza)
                        bool temPeso = (item['montagem'] != null && item['montagem']['peso_final'] != null);

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            leading: CircleAvatar(
                              backgroundColor: urlFotoSelo != null ? Colors.green[100] : Colors.grey.shade200,
                              child: Text('${index + 1}', style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold)),
                            ),
                            title: Text(
                                '${item['tipoAgente'] ?? 'Item'} ${item['carga'] ?? ''}',
                                style: const TextStyle(fontWeight: FontWeight.bold)
                            ),

                            // --- MUDANÇA AQUI: Subtítulo com Identificação Real + Crachá ---
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Cilindro: ${item['numeroCilindro'] ?? item['ativoFixo'] ?? 'S/N'}'),
                                Text('Crachá: ${item['idCrachaTemporario'] ?? ''}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              ],
                            ),
                            // --- AQUI ESTÁ A CORREÇÃO ---
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 1. Botão da Etiqueta (ADICIONADO AGORA)
                                IconButton(
                                  icon: Icon(Icons.qr_code_2, color: temPeso ? Colors.orange[800] : Colors.grey[400]),
                                  tooltip: 'Visualizar Etiqueta Argox',
                                  // Chama a função passando o Item e a OS
                                  onPressed: () => _abrirVisualizacaoEtiqueta(item,
                                      os,
                                      itens[index].id
                                  ),
                                ),

                                // 2. Botão da Foto (Se existir)
                                if (urlFotoSelo != null)
                                  IconButton(
                                    icon: const Icon(Icons.photo_camera, color: Colors.blue, size: 30),
                                    tooltip: 'Ver Foto do Selo',
                                    onPressed: () => _verFotoSelo(urlFotoSelo!, "Selo: ${item['idCrachaTemporario']}"),
                                  ),

                                const SizedBox(width: 4),

                                // 3. Status
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blueGrey[200]!)),
                                  child: Text(statusItem, style: TextStyle(fontSize: 10, color: Colors.blueGrey[800], fontWeight: FontWeight.bold)),
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

  Color _getCorStatus(String status) {
    status = status.toLowerCase();
    if (status.contains('finaliz') || status.contains('pronto')) return Colors.green;
    if (status.contains('cancel')) return Colors.grey;
    if (status.contains('produ') || status.contains('andamento')) return Colors.orange;
    return Colors.blue;
  }
}