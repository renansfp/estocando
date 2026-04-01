import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:math' as math;

class ImpressaoArgox {
  static String _limparTexto(String texto) {
    var comAcento = 'ÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÑñÇç';
    var semAcento = 'AAAAAAEEEEIIIIOOOOOUUUUNnCc';
    for (int i = 0; i < comAcento.length; i++) {
      texto = texto.replaceAll(comAcento[i], semAcento[i]);
    }
    return texto.replaceAll(RegExp(r'[^\x00-\x7F]'), '').toUpperCase();
  }

  // --- ETIQUETA DE MANUTENÇÃO ---
  static Future<Uint8List> gerarEtiquetaManutencao({
    required String clienteNome,
    required String clienteId,
    required String tipoExtintor,
    required String lote,
    required String numeroFabricacao,
    required String servicoRealizado,
    required String proximaManutencaoN2,
    required String proximaManutencaoN3,
  }) async {
    final pdf = pw.Document();
    final format = PdfPageFormat(100 * PdfPageFormat.mm, 50 * PdfPageFormat.mm, marginAll: 0);

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          return pw.SizedBox(
            width: 100 * PdfPageFormat.mm,
            height: 50 * PdfPageFormat.mm,
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(left: 30, right: -8, top: 4, bottom: 4),
              child: _layoutManutencao(
                _limparTexto(clienteNome),
                tipoExtintor,
                lote,
                numeroFabricacao,
                _limparTexto(servicoRealizado),
                proximaManutencaoN2,
                proximaManutencaoN3,
              ),
            ),
          );
        },
      ),
    );
    return pdf.save();
  }

// --- VERSÃO PARA CELULAR/NUVEM (GIRADA PARA NÃO SAIR VERTICAL) ---
  static Future<Uint8List> gerarEtiquetaManutencaoNuvem({
    required String clienteNome,
    required String clienteId,
    required String tipoExtintor,
    required String lote,
    required String numeroFabricacao,
    required String servicoRealizado,
    required String proximaManutencaoN2,
    required String proximaManutencaoN3,
  }) async {
    final pdf = pw.Document();
    // Invertemos o formato para 50x100 para o driver da Argox entender o rolo
    final format = PdfPageFormat(50 * PdfPageFormat.mm, 100 * PdfPageFormat.mm, marginAll: 0);

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          return pw.Transform.rotate(
            angle: 90 * (math.pi / 180), // Gira 90 graus para deitar o conteúdo
            child: pw.SizedBox(
              width: 100 * PdfPageFormat.mm,
              height: 50 * PdfPageFormat.mm,
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(left: 30, right: -8, top: 4, bottom: 4),
                child: _layoutManutencao(
                  _limparTexto(clienteNome),
                  tipoExtintor,
                  lote,
                  numeroFabricacao,
                  _limparTexto(servicoRealizado),
                  proximaManutencaoN2,
                  proximaManutencaoN3,
                ),
              ),
            ),
          );
        },
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> gerarEtiquetaNR23({
    required String numeroFabricacao,
    required String tipo,
    required String vencRecarga,
    required String vencTH,
    required String patrimonio,
  }) async {
    final pdf = pw.Document();
    final format = PdfPageFormat(100 * PdfPageFormat.mm, 50 * PdfPageFormat.mm, marginAll: 0);

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          return pw.SizedBox(
            width: 100 * PdfPageFormat.mm,
            height: 50 * PdfPageFormat.mm,
            child: pw.Padding(
              // Aplicando o recuo de 30mm que você validou na outra etiqueta
              padding: const pw.EdgeInsets.only(left: 30, right: -8, top: 4, bottom: 4),
              child: _buildLayoutNR23(
                fab: numeroFabricacao,
                tipo: _limparTexto(tipo),
                recarga: vencRecarga,
                th: vencTH,
              ),
            ),
          );
        },
      ),
    );
    return pdf.save();
  }

  // Layout da Manutenção
  static pw.Widget _layoutManutencao(String cliente, String tipo, String lote, String fab, String servico, String n2, String n3) {
    return pw.Column(
      children: [
        pw.Text("PROTECIN - Protecao Tecnica contra Incendio Ltda.", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
        pw.Text("R. Laconis, 600 - Pq. Capuava - Santo Andre - SP", style: const pw.TextStyle(fontSize: 6.5)),
        pw.Divider(thickness: 0.5, height: 6),
        pw.Expanded(
          child: pw.Row(
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _blocoVertical("CLIENTE:", cliente, valorSize: 8),
                    pw.Row(children: [
                      pw.Expanded(child: _blocoVertical("TIPO:", tipo, valorSize: 8)),
                      pw.Expanded(child: _blocoVertical("LOTE:", lote, valorSize: 8)),
                    ]),
                    pw.Row(children: [
                      pw.Expanded(child: _blocoVertical("NO FAB.:", fab, valorSize: 8)),
                      pw.Expanded(child: _blocoVertical("SERVICO:", servico, valorSize: 8)),
                    ]),
                    pw.Row(children: [
                      pw.Expanded(child: _blocoVertical("VENC N2:", n2, valorSize: 9)),
                      pw.Expanded(child: _blocoVertical("VENC N3:", n3, valorSize: 9)),
                    ]),
                  ],
                ),
              ),
              pw.VerticalDivider(thickness: 0.5),
              pw.Container(
                width: 65,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: fab, width: 40, height: 40),
                    pw.SizedBox(height: 2),
                    pw.Text(fab, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Layout da NR23
  static pw.Widget _buildLayoutNR23({
    required String fab,
    required String tipo,
    required String recarga,
    required String th
  }) {
    return pw.Column(
      children: [
        pw.Text("CONTROLE DE INSPECAO (N.R. 23)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        pw.Divider(thickness: 1, height: 10),
        pw.Expanded(
            child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _blocoVertical("FABRICACAO:", fab, valorSize: 10),
                  _blocoVertical("TIPO:", tipo, valorSize: 10),
                  _blocoVertical("VENC. RECARGA:", recarga, valorSize: 10),
                  _blocoVertical("VENC. T.H.:", th, valorSize: 10),
                ]
            )
        ),
        pw.Spacer(),
        pw.Text("RUBRICA DO INSPETOR", style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  // --- GERADOR DE LOTE ÚNICO (VÁRIAS PÁGINAS) ---
  static Future<Uint8List> gerarLoteEtiquetas({
    required List<Map<String, dynamic>> dadosEtiquetas,
  }) async {
    final pdf = pw.Document();

    // FORMATO CRUCIAL: 50mm de largura x 100mm de altura (Rolo Vertical)
    // Usamos isso para o driver da Argox entender o avanço do papel.
    final format = PdfPageFormat(100 * PdfPageFormat.mm, 50 * PdfPageFormat.mm, marginAll: 0);

    for (var dados in dadosEtiquetas) {
      pdf.addPage(
        pw.Page(
          pageFormat: format,
          // CORREÇÃO 2: Forçar orientação Paisagem para ocupar a largura da etiqueta
          orientation: pw.PageOrientation.landscape,
          build: (pw.Context context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: dados['tipo'] == 'Garantia'
                      ? _layoutManutencao(
                    _limparTexto(dados['clienteNome'] ?? ""),
                    dados['tipoExtintor'] ?? "",
                    dados['lote'] ?? "",
                    dados['numeroFabricacao'] ?? "",
                    _limparTexto(dados['servicoRealizado'] ?? ""),
                    dados['proximaManutencaoN2'] ?? "",
                    dados['proximaManutencaoN3'] ?? "",
                  )
                      : _buildLayoutNR23(
                    fab: dados['numeroFabricacao'] ?? "",
                    tipo: _limparTexto(dados['tipoExtintor'] ?? ""),
                    recarga: dados['proximaManutencaoN2'] ?? "",
                    th: dados['proximaManutencaoN3'] ?? "",
                  ),
                ),
            );
          },
        ),
      );
    }
    return pdf.save();
  }
  // Método auxiliar que faltou no seu print
  static pw.Widget _blocoVertical(String label, String valor, {double valorSize = 10}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 6)),
          pw.Text(valor, style: pw.TextStyle(fontSize: valorSize, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}

