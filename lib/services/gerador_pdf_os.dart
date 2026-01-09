import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class GeradorPdfOS {

  // Função Principal: Gera o PDF e abre a pré-visualização
  Future<void> gerarRelatorioTecnico(Map<String, dynamic> dadosOS, List<Map<String, dynamic>> itens) async {
    final pdf = pw.Document();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontRegular = await PdfGoogleFonts.robotoRegular();

    // Cria a página A4
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            _buildHeader(dadosOS, fontBold),
            pw.SizedBox(height: 20),
            _buildTabelaItens(itens, fontBold, fontRegular),
            pw.SizedBox(height: 20),
            _buildAssinaturas(fontRegular),
          ];
        },
      ),
    );

    // Manda para a impressora/tela
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Relatorio_OS_${dadosOS['numeroOS']}.pdf',
    );
  }

  // --- BLOCOS DE CONSTRUÇÃO DO PDF ---

  pw.Widget _buildHeader(Map<String, dynamic> os, pw.Font font) {
    String dataFormatada = '---';
    if (os['dataAbertura'] != null) {
      // Ajuste conforme seu objeto Timestamp
      try { dataFormatada = DateFormat('dd/MM/yyyy').format(os['dataAbertura'].toDate()); } catch (e) {}
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('PROTECIN - RELATÓRIO TÉCNICO', style: pw.TextStyle(font: font, fontSize: 18)),
            pw.Text('OS Nº: ${os['numeroOS']}', style: pw.TextStyle(font: font, fontSize: 18, color: PdfColors.red800)),
          ],
        ),
        pw.Divider(),
        pw.Text('CLIENTE: ${os['clienteNome']}', style: pw.TextStyle(font: font, fontSize: 12)),
        pw.Text('DATA ENTRADA: $dataFormatada', style: pw.TextStyle(fontSize: 10)),
        pw.Text('TOTAL ITENS: ${os['quantidadeItens'] ?? 0}', style: pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  pw.Widget _buildTabelaItens(List<Map<String, dynamic>> itens, pw.Font fontHeader, pw.Font fontCell) {
    return pw.Table.fromTextArray(
      headers: ['Item', 'Cilindro', 'Equipamento', 'Serviço', 'Status'],
      data: itens.map((item) {
        return [
          item['numeroSequencial']?.toString() ?? '-',
          item['numeroCilindro'] ?? '',
          '${item['fabricante']} ${item['tipo']} ${item['capacidade']}',
          _definirServico(item), // Uma função simples para resumir o serviço
          item['status'] ?? ''
        ];
      }).toList(),
      headerStyle: pw.TextStyle(font: fontHeader, fontSize: 10, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
      cellStyle: pw.TextStyle(font: fontCell, fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  pw.Widget _buildAssinaturas(pw.Font font) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(children: [
          pw.Container(width: 150, height: 1, color: PdfColors.black),
          pw.SizedBox(height: 5),
          pw.Text('Técnico Responsável', style: pw.TextStyle(font: font, fontSize: 8)),
        ]),
        pw.Column(children: [
          pw.Container(width: 150, height: 1, color: PdfColors.black),
          pw.SizedBox(height: 5),
          pw.Text('Cliente (Confirmação)', style: pw.TextStyle(font: font, fontSize: 8)),
        ]),
      ],
    );
  }

  String _definirServico(Map<String, dynamic> item) {
    // Lógica simples para exibir no papel o que foi feito
    // Você pode melhorar isso baseado nos seus campos reais
    return 'Manutenção Nível 2';
  }

  // --- FUTURO: ETIQUETAS ---
  Future<void> gerarEtiquetas(List<Map<String, dynamic>> itens) async {
    // Aqui faremos o layout da Zebra/Argox depois
  }
}