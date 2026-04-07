// Arquivo: lib/services/gerador_pdf_os.dart
// Relatório Técnico de OS — A4 Landscape, 28 colunas (A..AB).

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:protecin_producao/services/relatorio_os_service.dart';

// =============================================================================
// TELA DE PRÉ-VISUALIZAÇÃO
// =============================================================================
class TelaPreviewRelatorioOS extends StatelessWidget {
  final DadosRelatorioOS dados;
  const TelaPreviewRelatorioOS({super.key, required this.dados});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Relatório — OS ${dados.os.numeroOS ?? dados.os.id}'),
        backgroundColor: const Color(0xFF113452),
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        build: (_) => GeradorPdfOS()._buildPdfBytes(dados),
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        loadingWidget: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

// =============================================================================
// GERADOR
// =============================================================================
class GeradorPdfOS {
  // ─── Cores ────────────────────────────────────────────────────────────────
  static const _azul     = PdfColor.fromInt(0xFF113452);
  static const _cinzaCl  = PdfColor.fromInt(0xFFEEEEEE);
  static const _cinzaMd  = PdfColor.fromInt(0xFFCCCCCC);
  static const _preto    = PdfColor.fromInt(0xFF000000);
  static const _branco   = PdfColor.fromInt(0xFFFFFFFF);
  static const _vermelho = PdfColor.fromInt(0xFFBE2028);
  static const _verde    = PdfColor.fromInt(0xFF1a7a1a);

  // ─── Fontes ───────────────────────────────────────────────────────────────
  static const double _fH = 5.8;   // header da tabela
  static const double _fC = 6.0;   // célula de dado
  static const double _fI = 7.5;   // info cliente
  static const double _fM = 5.5;   // mini (rodapé)
  static const double _fT = 9.0;   // título

  static final _fmt = DateFormat('dd/MM/yyyy');

  // ─── Formato de página: A4 landscape sem margem interna do pacote ─────────
  static final _pageFormat = PdfPageFormat(
    PdfPageFormat.a4.height, // 841.89pt → largura landscape
    PdfPageFormat.a4.width,  // 595.28pt → altura landscape
    marginAll: 0,
  );

  // ─── 28 Colunas A..AB (total = 821pt = largura disponível) ───────────────
  // A   B    C    D    E    F    G    H    I    J    K    L    M
  // N   O    P    Q    R    S    T    U    V    W    X    Y    Z   AA   AB
  static const _cols = [
    _Col('SEQ',     18),  // A
    _Col('TIPO',    30),  // B
    _Col('CAP.',    26),  // C
    _Col('NÍV.',    24),  // D
    _Col('CIL.',    34),  // E
    _Col('ANO',     28),  // F
    _Col('PINT.',   28),  // G
    _Col('CRACHÁ',  26),  // H
    _Col('C.EXT.',  32),  // I
    _Col('FABR.',   52),  // J
    _Col('NORMA',   37),  // K
    _Col('COD.PROJ',48), // L
    _Col('P.TRAB.',  26), // M
    _Col('TARA',    22),  // N
    _Col('PV',      22),  // O
    _Col('PERDA%',  28),  // P
    _Col('PC',      22),  // Q
    _Col('VOL.',    22),  // R
    _Col('C.MAX.',  30),  // S
    _Col('P.TEST.', 28),  // T
    _Col('ET',      22),  // U
    _Col('EP',      22),  // V
    _Col('COND.',   45),  // W
    _Col('ENS.',    28),  // X
    _Col('PEÇAS',   41),  // Y
    _Col('LT.PÓ',   28),  // Z
    _Col('ÚLT.TH', 30),  // AA
    _Col('STATUS', 22),  // AB
  ];

  // ─── Abre a tela de preview ───────────────────────────────────────────────
  Future<void> abrirPreview(BuildContext context, DadosRelatorioOS dados) async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TelaPreviewRelatorioOS(dados: dados)),
    );
  }

  // ─── Gera bytes do PDF ────────────────────────────────────────────────────
  Future<Uint8List> _buildPdfBytes(DadosRelatorioOS dados) async {
    // Carrega a logo correta (cores para digital, mono para impressão P&B)
    final logoData = await rootBundle.load('assets/images/logo_protecin_cores.png');
    final logoBytes = logoData.buffer.asUint8List();
    final pdf  = pw.Document();
    final bold = await PdfGoogleFonts.robotoBold();
    final reg  = await PdfGoogleFonts.robotoRegular();

    const lpp = 20;
    final paginas = <List<DadosItemRelatorio>>[];
    for (var i = 0; i < dados.itens.length; i += lpp) {
      paginas.add(dados.itens.skip(i).take(lpp).toList());
    }
    if (paginas.isEmpty) paginas.add([]);

    for (var p = 0; p < paginas.length; p++) {
      pdf.addPage(pw.Page(
        pageFormat: _pageFormat,
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _cabecalho(dados, bold, reg, p + 1, paginas.length, logoBytes),
            pw.SizedBox(height: 3),
            _infoCliente(dados, bold, reg),
            pw.SizedBox(height: 3),
            _tabela(paginas[p], bold, reg),
            pw.SizedBox(height: 4),
            _totalizadores(dados, bold, reg),
            pw.SizedBox(height: 3),
            _rodape(dados, bold, reg),
          ],
        ),
      ));
    }

    return pdf.save();
  }

  // =========================================================================
  // 1. CABEÇALHO
  // =========================================================================
  pw.Widget _cabecalho(DadosRelatorioOS d, pw.Font bold, pw.Font reg, int pag, int tot, Uint8List logoBytes) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      child: pw.Row(children: [
        // Logo
        pw.Container(
          width: 68,
          padding: const pw.EdgeInsets.all(4),
          decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))),
          child: pw.Center(
            child: pw.Image(
              pw.MemoryImage(logoBytes),
              width: 52,
              height: 56,
              fit: pw.BoxFit.contain,
            ),
          ),
        ),
        // Título
        pw.Expanded(child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))),
          child: pw.Text('Relatório de Serviços, Testes e Inspeções',
              style: pw.TextStyle(font: bold, fontSize: _fT, color: _azul)),
        )),
        // Nº OS
        pw.Container(
          width: 210,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('ORDEM DE SERVIÇO E PEÇAS Nº',
                  style: pw.TextStyle(font: bold, fontSize: 7)),
              pw.Text(d.os.numeroOS ?? '---',
                  style: pw.TextStyle(font: bold, fontSize: 11, color: _vermelho)),
            ],
          ),
        ),
        // Normas + folha
        pw.Container(
          width: 160,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('CONFORME NBR 12962 / NBR 13485 / NBR 12274',
                style: pw.TextStyle(font: bold, fontSize: 5.5)),
            pw.SizedBox(height: 4),
            pw.Align(alignment: pw.Alignment.bottomRight,
                child: pw.Text('FOLHA  $pag / $tot',
                    style: pw.TextStyle(font: bold, fontSize: 7))),
          ]),
        ),
      ]),
    );
  }

  // =========================================================================
  // 2. INFO CLIENTE
  // =========================================================================
  pw.Widget _infoCliente(DadosRelatorioOS d, pw.Font bold, pw.Font reg) {
    final os = d.os;
    final p  = d.parceiro;
    final dataTriagem = _resolverDataTriagem(d);
    final dataFim     = d.dataFinalizacao != null ? _fmt.format(d.dataFinalizacao!) : '---';

    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      child: pw.Column(children: [
        pw.Row(children: [
          _ci('CLIENTE', p.nome, bold, reg, flex: 4),
          _ci('CNPJ', _fmtCnpj(p.cnpj), bold, reg, flex: 2),
          _ci('SIRLA', p.sirla.isEmpty ? '---' : p.sirla, bold, reg),
          _ci('ATIVO FIXO?', 'Não', bold, reg),
          _ci('OBS.', '', bold, reg, flex: 2, last: true),
        ]),
        pw.Container(height: 0.5, color: _cinzaMd),
        pw.Row(children: [
          _ci('ENDEREÇO', p.endereco, bold, reg, flex: 4),
          _ci('MUNICÍPIO', p.cidade, bold, reg, flex: 2),
          _ci('ESTADO', p.estado, bold, reg),
          _ci('TRIAGEM', dataTriagem, bold, reg),
          _ci('FINALIZADA EM', dataFim, bold, reg),
          _ci('PROCEDIMENTO', 'Normal', bold, reg, last: true),
        ]),
      ]),
    );
  }

  pw.Widget _ci(String label, String valor, pw.Font bold, pw.Font reg,
      {int flex = 1, bool last = false}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        decoration: pw.BoxDecoration(
          border: pw.Border(right: last ? pw.BorderSide.none : const pw.BorderSide(width: 0.5)),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 5.5, color: _azul)),
          pw.Text(valor, style: pw.TextStyle(font: reg, fontSize: _fI),
              maxLines: 1, overflow: pw.TextOverflow.clip),
        ]),
      ),
    );
  }

  // =========================================================================
  // 3. TABELA PRINCIPAL (28 colunas A..AB)
  // =========================================================================
  pw.Widget _tabela(List<DadosItemRelatorio> itens, pw.Font bold, pw.Font reg) {
    const h = 13.5;

    pw.Widget cel(String t, {pw.Font? f, bool ctr = true, PdfColor? cor, PdfColor? bg}) =>
        pw.Container(
          height: h, color: bg,
          padding: const pw.EdgeInsets.symmetric(horizontal: 1),
          alignment: ctr ? pw.Alignment.center : pw.Alignment.centerLeft,
          child: pw.Text(t,
              style: pw.TextStyle(font: f ?? reg, fontSize: _fC, color: cor ?? _preto),
              maxLines: 1, overflow: pw.TextOverflow.clip),
        );

    final rows = <pw.TableRow>[];

    // Cabeçalho
    rows.add(pw.TableRow(children: _cols.map((c) =>
        pw.Container(
          color: _azul,
          padding: const pw.EdgeInsets.symmetric(horizontal: 1, vertical: 1),
          child: pw.Text(c.label,
              style: pw.TextStyle(font: bold, fontSize: _fH, color: _branco),
              textAlign: pw.TextAlign.center),
        )
    ).toList()));

    // Linhas de dados
    for (var i = 0; i < itens.length; i++) {
      final d  = itens[i];
      final eq = d.equipamento;
      final bg = i.isEven ? _cinzaCl : _branco;

      final corStatus = d.statusFinal == 'OK' ? _verde
          : d.statusFinal == 'NC' ? _vermelho : _preto;

      rows.add(pw.TableRow(decoration: pw.BoxDecoration(color: bg), children: [
        cel('${i + 1}'),                                          // A seq
        cel(eq.tipo),                                             // B tipo
        cel(eq.capacidade),                                       // C cap
        cel(d.nivelManutencao, f: bold),                         // D nível
        cel(eq.numeroCilindro),                                   // E cilindro
        cel(eq.anoFabricacao),                                    // F ano fabr
        cel(eq.numeroPintura ?? '---'),                           // G nº pintura
        cel(d.numeroCracha),                                      // H crachá
        cel(eq.capacidadeExtintora),                              // I cap ext
        cel(eq.fabricante, ctr: false),                           // J fabricante
        cel(eq.normaFabricacao),                                  // K norma
        cel(eq.projeto ?? '---'),                                 // L cod projeto
        cel(eq.pressaoTrabalho ?? '---'),                         // M p. trabalho
        cel(d.tara),                                              // N tara
        cel(d.pv),                                                // O PV
        cel(d.perdaMassaPct),                                     // P perda%
        cel(d.pc),                                                // Q PC
        cel(d.volumeLts),                                         // R volume
        cel(d.capMaxCarga),                                       // S cap max
        cel(d.pressaoTeste),                                      // T p. teste
        cel(d.et),                                                // U ET
        cel(d.ep),                                                // V EP
        cel(d.motivoCondenacao ?? '', ctr: false),                // W cond
        cel('---'),                                               // X ens. comp (futuro)
        cel(d.pecasTrocadas),                                     // Y peças
        cel(eq.lotePo ?? '---'),                                  // Z lote pó
        cel(eq.anoUltimoTH ?? '---'),                             // AA último TH
        cel(d.statusFinal, f: bold, cor: corStatus),              // AB status
      ]));
    }

    // Linhas vazias
    for (var i = itens.length; i < 20; i++) {
      final bg = i.isEven ? _cinzaCl : _branco;
      rows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: bg),
        children: _cols.map((_) => pw.Container(height: h)).toList(),
      ));
    }

    return pw.Table(
      border: pw.TableBorder.all(width: 0.3, color: _cinzaMd),
      columnWidths: {for (var i = 0; i < _cols.length; i++) i: pw.FixedColumnWidth(_cols[i].w)},
      children: rows,
    );
  }

  // =========================================================================
  // 4. TOTALIZADORES
  // =========================================================================
  pw.Widget _totalizadores(DadosRelatorioOS d, pw.Font bold, pw.Font reg) {
    final Map<String, int> cnt = {};
    for (final item in d.itens) {
      final k = item.equipamento.capacidadeExtintora;
      cnt[k] = (cnt[k] ?? 0) + 1;
    }
    final entries = cnt.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
          color: _azul, width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: pw.Text('TOTALIZADORES POR CAPACIDADE EXTINTORA / CARGA',
              style: pw.TextStyle(font: bold, fontSize: 6.5, color: _branco)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(children: entries.map((e) =>
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: const pw.BoxDecoration(
                    border: pw.Border(right: pw.BorderSide(width: 0.5))),
                child: pw.Text('${e.key}  =  ${e.value}',
                    style: pw.TextStyle(font: bold, fontSize: 7.5)),
              )
          ).toList()),
        ),
      ]),
    );
  }

  // =========================================================================
  // 5. RODAPÉ (legenda + laudo + assinaturas)
  // =========================================================================
  pw.Widget _rodape(DadosRelatorioOS d, pw.Font bold, pw.Font reg) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        // Legenda 1..30
        pw.Expanded(
          flex: 5,
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Wrap(
              spacing: 10, runSpacing: 1,
              children: _legenda().map((s) =>
                  pw.Text(s, style: pw.TextStyle(font: reg, fontSize: _fM))).toList(),
            ),
          ),
        ),
        pw.Container(width: 0.5, color: _cinzaMd),
        // Laudo
        pw.Container(
          width: 118,
          padding: const pw.EdgeInsets.all(4),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('INSP. GERAL:',
                style: pw.TextStyle(font: bold, fontSize: 6.5, color: _azul)),
            pw.Text('OK = EM CONFORMIDADE',
                style: pw.TextStyle(font: reg, fontSize: _fM)),
            pw.Text('NC = NÃO CONFORMIDADE',
                style: pw.TextStyle(font: reg, fontSize: _fM)),
            pw.SizedBox(height: 4),
            pw.Text('LAUDO MANUT. NV. III',
                style: pw.TextStyle(font: bold, fontSize: 6.5, color: _azul)),
            ...['A = ENSAIO VÁLVULA', 'B = ENSAIO MANGUEIRAS',
              'C = APROVADO', 'RG = GARANTIA'].map((t) =>
                pw.Text(t, style: pw.TextStyle(font: reg, fontSize: _fM))),
          ]),
        ),
        pw.Container(width: 0.5, color: _cinzaMd),
        // Assinaturas
        pw.Container(
          width: 185,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _assinatura('INSPETOR DE QUALIDADE', bold, reg),
              _assinatura(
                d.os.responsavelTecnico.isNotEmpty
                    ? d.os.responsavelTecnico
                    : 'RESPONSÁVEL TÉCNICO',
                bold, reg,
              ),
            ],
          ),
        ),
      ]),
    );
  }

  pw.Widget _assinatura(String titulo, pw.Font bold, pw.Font reg) =>
      pw.Column(children: [
        pw.SizedBox(height: 16),
        pw.Container(width: 70, height: 0.5, color: _preto),
        pw.SizedBox(height: 2),
        pw.Text(titulo, style: pw.TextStyle(font: reg, fontSize: _fM),
            textAlign: pw.TextAlign.center),
      ]);

  // ─── Legenda 1..30 ────────────────────────────────────────────────────────
  List<String> _legenda() => [
    '1. VÁLVULA DESC.', '2. MANGUEIRA',     '3. DIFUSOR',
    '4. MANÔMETRO',     '5. PISTOLA',        '6. PUNHO',
    '7. TRAVA',         '8. CORRENTE',       '9. SIFÃO',
    '10. CAPILAR',      '11. NYLON VÁLV.',   '12. CUPILHA',
    '13. PERA',         '14. GUARNIÇÃO',     '15. ORING',
    '16. TAMPA',        '17. SUPORTE',       '18. REG. NZ',
    '19. RODA',         '20. REP. TAMPA',    '21. REG. NZ',
    '22. VOLANTE VÁLV.','23. CO2',           '24. Nº 2',
    '25. TUBULAÇÃO',    '26. BUCHA',         '27. ADAP. AMPOLA',
    '28. T = TESTE HIDROST.', '29. P = PINTURA', '30. R = RECARGA',
  ];

  // ─── Auxiliares ──────────────────────────────────────────────────────────
  String _resolverDataTriagem(DadosRelatorioOS d) {
    if (d.itens.isEmpty) return '---';
    try {
      final hist = d.itens.first.item.historicoEtapas;
      if (hist.isNotEmpty) return _fmt.format(hist.first.dataHora);
    } catch (_) {}
    return '---';
  }

  String _fmtCnpj(String cnpj) {
    final n = cnpj.replaceAll(RegExp(r'\D'), '');
    if (n.length == 14) {
      return '${n.substring(0,2)}.${n.substring(2,5)}.${n.substring(5,8)}/${n.substring(8,12)}-${n.substring(12)}';
    }
    return cnpj;
  }
}

// ─── Auxiliar de coluna ───────────────────────────────────────────────────────
class _Col {
  final String label;
  final double w;
  const _Col(this.label, this.w);
}