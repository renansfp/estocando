import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/telas/estoque/tela_criar_requisicao.dart';
import 'package:protecin_producao/utils/mapeador_custos.dart';
import 'package:protecin_producao/utils/impressao_argox.dart';
import 'dart:typed_data';

class TelaEstacaoPremontagem extends StatefulWidget {
  final String osId;
  const TelaEstacaoPremontagem({super.key, required this.osId});

  @override
  State<TelaEstacaoPremontagem> createState() => _TelaEstacaoPremontagemState();
}

class _TelaEstacaoPremontagemState extends State<TelaEstacaoPremontagem> {
  bool _processando = false;
  String _statusEnvio = "";

  // --- LÓGICA DE LIBERAÇÃO COM DNA DO ROTEIRO ---
  Future<void> _liberarLoteCompleto(List<DocumentSnapshot> itens, bool imprimirGarantia, bool imprimirNR23, String impressora) async {
    final usuario = Provider.of<UsuarioProvider>(context, listen: false).usuario;
    final batch = FirebaseFirestore.instance.batch();

    for (var doc in itens) {
      final List<String> roteiro = List<String>.from(doc['roteiro'] ?? []);
      int indexAtual = roteiro.indexOf('pre_montagem');

      // DNA: Descobre quem é o próximo (Geralmente montagem)
      String proxima = (indexAtual != -1 && indexAtual < roteiro.length - 1)
          ? roteiro[indexAtual + 1]
          : 'montagem';

      batch.update(doc.reference, {
        'status': 'aguardando_$proxima',
        'premontagem': {
          'data': FieldValue.serverTimestamp(),
          'operador': usuario?.nome ?? 'Sistema'
        }
      });

      // Se for o último do loop, atualiza a etapa da OS
      if (itens.indexOf(doc) == itens.length - 1) {
        batch.update(FirebaseFirestore.instance.collection('ordens_servico').doc(widget.osId), {
          'etapaAtual': proxima,
        });
      }
    }

    await batch.commit();
    _gerarEEnviarPPLA(itens, imprimirGarantia, imprimirNR23, impressora);
  }

  // --- O "TURBO" DA IMPRESSÃO: GERADOR PPLA ---
  // --- O "TURBO" DA IMPRESSÃO: GERADOR PPLA ---
// Atualizamos a assinatura para aceitar os 4 parâmetros
  //Future<void> _gerarEEnviarPPLA(
  //    List<DocumentSnapshot> itens,
  //    bool imprimirGarantia,
  //    bool imprimirNR23,
  //    String impressora
  //    ) async {

  //  setState(() {
  //    _processando = true;
//    _statusEnvio = "Iniciando processamento em lotes...";
  //  });

  //  const int tamanhoDoLote = 50; // Limite para não estourar a RAM do celular
  //  int totalItens = itens.length;
  //  int lotesContador = 0;

  //  try {
      // 1. Loop principal que pula de 50 em 50
  //    for (int i = 0; i < totalItens; i += tamanhoDoLote) {
  //      lotesContador++;

        // Pega a fatia atual (ex: 0-50, 50-100...)
  //      int fim = (i + tamanhoDoLote < totalItens) ? i + tamanhoDoLote : totalItens;
  //      List<DocumentSnapshot> subLista = itens.sublist(i, fim);

  //      setState(() => _statusEnvio = "Gerando Lote $lotesContador (${subLista.length} itens)...");

  //      List<Map<String, dynamic>> listaParaEstePDF = [];

        // 2. Monta os dados das etiquetas desta fatia
  //      for (var doc in subLista) {
  //        final data = doc.data() as Map<String, dynamic>;

  //        String ativo = data['ativoFixo'] ?? data['numeroCilindro'] ?? "S/N";
  //        String cliente = (data['clienteNome'] ?? "CLIENTE").toString();
  //        String tipo = "${data['tipoAgente'] ?? ''} ${data['peso'] ?? ''} KG".trim();

  //        DateTime hoje = DateTime.now();
  //        String vN2 = "${hoje.month.toString().padLeft(2, '0')}/${hoje.year + 1}";
  //        String vN3 = data['vencimentoTH']?.toString() ?? "${hoje.year + 5}";

          // Adiciona Garantia se marcado
  //       if (imprimirGarantia) {
  //          listaParaEstePDF.add({
  //            'tipo': 'Garantia',
  //            'clienteNome': cliente,
  //            'tipoExtintor': tipo,
  //            'lote': widget.osId,
  //            'numeroFabricacao': ativo,
  //            'servicoRealizado': "Manutencao Nivel III",
  //            'proximaManutencaoN2': vN2,
//            'proximaManutencaoN3': vN3,
//          });
  //        }

          // Adiciona NR23 se marcado
  //        if (imprimirNR23) {
  //          listaParaEstePDF.add({
  //            'tipo': 'NR23',
  //            'numeroFabricacao': ativo,
  //            'tipoExtintor': tipo,
  //            'proximaManutencaoN2': vN2,
//            'proximaManutencaoN3': vN3,
//           });
//        }
  //      }

        // 3. Gera o PDF Único deste lote
  //    final Uint8List pdfLoteBytes = await ImpressaoArgox.gerarLoteEtiquetas(
  //        dadosEtiquetas: listaParaEstePDF
  //    );

  //    // 4. Envia o Job para o Firebase
  //    await FirebaseFirestore.instance.collection('print_jobs').add({
  //      'command_list': pdfLoteBytes.toList(),
  //      'printerName': impressora,
  //      'status': 'pending',
  //      'createdAt': FieldValue.serverTimestamp(),
  //      'tipoEtiqueta': 'LOTE_${lotesContador}_OS_${widget.osId}',
//      'docId': 'LOTE_$lotesContador'
//      });
  //    }
//
  //    if (mounted) {
  //    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  //      content: Text('Sucesso! $lotesContador lotes enviados para a produção.'),
  //      backgroundColor: Colors.green,
  //    ));
//    Navigator.pop(context);
//    }
  //  } catch (e) {
  //  if (mounted) {
  //    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  //      content: Text('Erro ao gerar lotes: $e'),
  //      backgroundColor: Colors.red,
//    ));
//    }
  //  } finally {
//  if (mounted) setState(() => _processando = false);
//  }
  //}
  Future<void> _gerarEEnviarPPLA(List<DocumentSnapshot> itens, bool imprimirGarantia, bool imprimirNR23, String impressora) async {
    setState(() {
      _processando = true;
      _statusEnvio = "Enviando ordem de produção para o PC...";
    });

    try {
      // Pegamos apenas os IDs dos itens. O PC vai buscar os dados frescos no banco.
      List<String> idsDosItens = itens.map((doc) => doc.id).toList();

      await FirebaseFirestore.instance.collection('print_jobs').add({
        'itensIds': idsDosItens,
        'osId': widget.osId,
        'imprimirGarantia': imprimirGarantia,
        'imprimirNR23': imprimirNR23,
        'printerName': impressora,
        'status': 'pending', // O PC vai pescar esse status
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ordem enviada! Acompanhe a impressão no computador.'),
          backgroundColor: Colors.blue,
        ));
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _exibirConfirmacaoImpressao(List<DocumentSnapshot> itens) async {
    bool imprimirGarantia = true;
    bool imprimirNR23 = true;
    String impressoraSelecionada = 'Argox01';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( // Necessário para atualizar os checkboxes dentro do alerta
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Configurações de Impressão"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text("Imprimir Garantia"),
                    value: imprimirGarantia,
                    onChanged: (v) => setStateDialog(() => imprimirGarantia = v!),
                  ),
                  CheckboxListTile(
                    title: const Text("Imprimir NR 23"),
                    value: imprimirNR23,
                    onChanged: (v) => setStateDialog(() => imprimirNR23 = v!),
                  ),
                  const Divider(),
                  const Text("Selecione a Impressora:", style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: impressoraSelecionada,
                    items: ['Argox01', 'Argox02', 'Argox03'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (v) => setStateDialog(() => impressoraSelecionada = v!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text("CANCELAR"),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  child: const Text("LIBERAR E IMPRIMIR", style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    Navigator.pop(context);
                    // Aqui passamos as opções escolhidas para a função de liberação
                    _liberarLoteCompleto(itens, imprimirGarantia, imprimirNR23, impressoraSelecionada);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pré-Montagem: Etiquetas'),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.home), onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
        actions: [
          // Botão de requisição para o SETOR (CC 4224)
          IconButton(
            icon: const Icon(Icons.inventory_2),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => TelaCriarRequisicao(
              ccPrePreenchido: MapeadorCustos.obterCC('MONTAGEM'),
              subTipoPrePreenchido: 'Colaborador',
            ))),
          ),
          // Botão de requisição para a OS
          IconButton(
            icon: const Icon(Icons.shopping_cart_checkout),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => TelaCriarRequisicao(
              osPrePreenchida: widget.osId,
              ccPrePreenchido: MapeadorCustos.obterCC('MONTAGEM'),
              subTipoPrePreenchido: 'OS',
            ))),
          ),
        ],
      ),
      body: _processando
          ? Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(_statusEnvio),
        ],
      ))
          : StreamBuilder<QuerySnapshot>(
        // Buscamos todos os itens da OS, sem travar no nome exato do status aqui
        stream: FirebaseFirestore.instance.collection('itens_os')
            .where('osId', isEqualTo: widget.osId)
            .snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          // FILTRO INTELIGENTE: Removemos underscores e comparamos
          final itens = snap.data!.docs.where((doc) {
            String st = doc['status']?.toString().toLowerCase().replaceAll('_', '') ?? '';
            return st.contains('premontagem');
          }).toList();

          if (itens.isEmpty) return const Center(child: Text("Todos os itens liberados!"));

          return ListView.builder(
            itemCount: itens.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (c, i) => Card(
              child: ListTile(
                leading: const Icon(Icons.qr_code, color: Colors.indigo),
                title: Text('Crachá: ${itens[i]['idCrachaTemporario']}'),
                subtitle: Text('Agente: ${itens[i]['tipoAgente']}'),
              ),
            ),
          );
        },
      ),

      floatingActionButton: _processando ? null : FloatingActionButton.extended(
        backgroundColor: Colors.indigo.shade800,
        icon: const Icon(Icons.print, color: Colors.white),
        label: const Text("LIBERAR LOTE E IMPRIMIR", style: TextStyle(color: Colors.white)),
        onPressed: () async {
          // Buscamos todos os itens da OS
          final q = await FirebaseFirestore.instance.collection('itens_os')
              .where('osId', isEqualTo: widget.osId)
              .get();

          // Filtramos manualmente os que pertencem à Pré-Montagem (mesma lógica do body)
          final itensFiltrados = q.docs.where((doc) {
            String st = doc['status']?.toString().toLowerCase().replaceAll('_', '') ?? '';
            return st.contains('premontagem');
          }).toList();

          if (itensFiltrados.isNotEmpty) {
            // Abre o diálogo com os itens que realmente estão no setor
            _exibirConfirmacaoImpressao(itensFiltrados);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Nenhum item pendente para liberação neste lote."))
            );
          }
        },
      ),
    );
  }
}