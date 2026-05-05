import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/widgets.dart'; // <--- ADICIONE ESTA LINHA
import 'package:printing/printing.dart'; // Essencial para Windows
import 'package:pdf/pdf.dart';
import 'package:protecin_producao/utils/impressao_argox.dart';

class MonitorImpressaoWindows {
  final String nomeImpressora;
  StreamSubscription? _subscription;
  final Function(String) onLog;

  final List<DocumentSnapshot> _filaLocal = [];
  bool _ocupadoImprimindo = false;

  MonitorImpressaoWindows({required this.nomeImpressora, required this.onLog});

  void iniciar() {
    onLog("🟢 MONITOR INICIADO");
    onLog("👂 Ouvindo fila...");

    _subscription = FirebaseFirestore.instance
        .collection('print_jobs')
        .where('printerName', isEqualTo: nomeImpressora)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      // Resolve o erro de thread no Windows
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            _filaLocal.add(change.doc);
            onLog("📥 Pedido na fila local (Total: ${_filaLocal.length})");
            _processarFila();
          }
        }
      });
    });
  }

  void parar() {
    _subscription?.cancel();
    onLog("🔴 Monitor Parado.");
  }

  Future<void> _processarFila() async {
    if (_ocupadoImprimindo) return;
    _ocupadoImprimindo = true;

    while (_filaLocal.isNotEmpty) {
      try {
        final docJob = _filaLocal.first;
        final dadosJob = docJob.data() as Map<String, dynamic>;

        // O SEGREDO: Usar WidgetsBinding para garantir que o log e a busca
        // rodem na thread correta do Windows
        await Future.delayed(Duration.zero);

        onLog("🛠️ Fabricando lote da OS ${dadosJob['osId']}...");
        await docJob.reference.update({'status': 'processing'});

        List<Map<String, dynamic>> listaParaLote = [];
        List<dynamic> ids = dadosJob['itensIds'] ?? [];

        for (String id in ids) {
          // Busca o item garantindo que não trave a thread
          var docItem = await FirebaseFirestore.instance.collection('itens_os').doc(id).get();

          if (docItem.exists) {
            final data = docItem.data()!;
            Map<String, dynamic> infoBase = {
              'clienteNome': data['clienteNome'] ?? "CLIENTE",
              'tipoExtintor': "${data['tipoAgente'] ?? ''} ${data['peso'] ?? ''} KG",
              'lote': dadosJob['osId'].toString(),
              'numeroFabricacao': data['ativoFixo'] ?? data['numeroCilindro'] ?? "S/N",
              'proximaManutencaoN2': "12/2026",
              'proximaManutencaoN3': "2031",
              'servicoRealizado': data['servico_realizado'] ?? "Manutencao",
            };

            if (dadosJob['imprimirGarantia'] == true) listaParaLote.add({'tipo': 'Garantia', ...infoBase});
            if (dadosJob['imprimirNR23'] == true) listaParaLote.add({'tipo': 'NR23', ...infoBase});
          }
        }

        if (listaParaLote.isNotEmpty) {
          final pdfBytes = await ImpressaoArgox.gerarLoteEtiquetas(dadosEtiquetas: listaParaLote);

          // No Windows, o Printing.layoutPdf precisa rodar na thread principal
          await Printing.layoutPdf(
            onLayout: (format) async => pdfBytes,
            name: 'Lote_OS_${dadosJob['osId']}',
            format: const PdfPageFormat(100 * PdfPageFormat.mm, 50 * PdfPageFormat.mm),
            usePrinterSettings: true, // <--- ADICIONE ISSO: Força a usar o que está no Driver
          );

          await docJob.reference.update({'status': 'printed'});
          onLog("✅ Sucesso: ${listaParaLote.length} etiquetas enviadas.");
        }

        _filaLocal.removeAt(0);
      } catch (e) {
        onLog("❌ Erro: $e");
        if (_filaLocal.isNotEmpty) _filaLocal.removeAt(0);
      }
    }
    _ocupadoImprimindo = false;
  }


  // Mantida como referência. Remover se confirmar que não será usada.
  // FUNÇÃO DESATIVADA — não está sendo chamada em nenhum lugar.
  // ─────────────────────────────────────────────────────────────────────
  // ignore: unused_element
  Future<void> _imprimirEtiquetaUnica(DocumentSnapshot doc) async {
    final Map<String, dynamic> dadosDoc = doc.data() as Map<String, dynamic>;

    try {
      await doc.reference.update({'status': 'printing'});
      final List<dynamic> listaComando = dadosDoc['command_list'];
      final Uint8List bytesPdf = Uint8List.fromList(listaComando.cast<int>());

      // Salva o PDF temporário
      final String tempPath = '${Directory.systemTemp.path}/job_${doc.id}.pdf';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(bytesPdf);

      // Executa o SumatraPDF
      String pathSumatra = "${Directory.current.path}\\lib\\services\\SumatraPDF.exe";

      onLog("🚀 Chamando Sumatra em: $pathSumatra");

      final result = await Process.run(pathSumatra, [
        '-print-dialog', // Abre a janela oficial do Windows
        '-exit-when-done', // Fecha o Sumatra depois que mandar pro spooler
        '-print-settings',
        'paper="Etiqueta Protecin (100.0 mm x 50.0 mm)",noscale',
        tempPath
      ]);

      if (tempFile.existsSync()) await tempFile.delete();

      if (result.exitCode == 0) {
        await doc.reference.update({'status': 'printed'});
        onLog("✅ SUCESSO ABSOLUTO!");
      } else {
        String erroWindows = result.stderr.toString().isNotEmpty
            ? result.stderr.toString()
            : "Erro no Spooler - Verifique a impressora";
        throw Exception(erroWindows);
      }
    } catch (e) {
      onLog("❌ FALHA: $e");
      await doc.reference.update({'status': 'error', 'msg': e.toString()});
    }
  }
}