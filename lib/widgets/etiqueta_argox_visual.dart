import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:protecin_producao/utils/impressao_argox.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

class EtiquetaArgoxVisual extends StatefulWidget {
  final String docId;
  final String clienteNome;
  final String clienteId;
  final String tipoExtintor;
  final String lote;
  final String numeroFabricacao;
  final String servicoRealizado;
  final String proximaManutencaoN2;
  final String proximaManutencaoN3;

  final bool permitirImpressao;
  final String nomeImpressora;

  const EtiquetaArgoxVisual({
    super.key,
    required this.docId,
    required this.clienteNome,
    required this.clienteId,
    required this.tipoExtintor,
    required this.lote,
    required this.numeroFabricacao,
    required this.servicoRealizado,
    required this.proximaManutencaoN2,
    required this.proximaManutencaoN3,
    this.permitirImpressao = true,
    this.nomeImpressora = "Argox01",
  });

  @override
  State<EtiquetaArgoxVisual> createState() => _EtiquetaArgoxVisualState();
}

class _EtiquetaArgoxVisualState extends State<EtiquetaArgoxVisual> {
  // Controlador para capturar a imagem do widget
  final ScreenshotController screenshotController = ScreenshotController();
  bool _gerandoImagem = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- A ETIQUETA (Envolvida pelo Screenshot) ---
          Screenshot(
            controller: screenshotController,
            child: Container(
              // Tamanho fixo Proporção 2:1 (100mm x 50mm)
              width: 500,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 1),
              ),
              padding: const EdgeInsets.all(8),
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 500,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. CABEÇALHO
                      const Text(
                        "PROTECIN - Proteção Técnica contra Incêndio Ltda.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.black), // Preto Puro
                      ),
                      const Text(
                        "R. Lacônia, 600 - Pq. Capuava - Santo André - SP",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 9, color: Colors.black), // Preto Puro
                      ),
                      const Text(
                        "Fone: 11 4977-8720  |  CNPJ: 48.046.510/0001-26",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.black), // Preto Puro
                      ),
                      const Divider(color: Colors.black, thickness: 1.5),

                      // 2. LINHA 1
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              flex: 4,
                              child: _campo("Cliente:",
                                  "${widget.clienteNome} (${widget.clienteId})")),
                          _divisorVertical(),
                          Expanded(
                              flex: 2,
                              child: _campo("Tipo:", widget.tipoExtintor)),
                          _divisorVertical(),
                          Expanded(
                              flex: 2, child: _campo("Lote:", widget.lote)),
                        ],
                      ),
                      const Divider(color: Colors.black, thickness: 1.5),

                      // 3. LINHA 2
                      Row(
                        children: [
                          Expanded(
                              flex: 3,
                              child: _campo(
                                  "No Fab.:", widget.numeroFabricacao)),
                          _divisorVertical(),
                          Expanded(
                              flex: 5,
                              child: _campo("SERVIÇO REALIZADO:",
                                  widget.servicoRealizado)),
                        ],
                      ),
                      const Divider(color: Colors.black, thickness: 1.5),

                      // 4. LINHA 3
                      Row(
                        children: [
                          Expanded(
                              child: _campo("Prox Manut. Nível II:",
                                  widget.proximaManutencaoN2,
                                  destaque: true)),
                          _divisorVertical(),
                          Expanded(
                              child: _campo("Prox Manut. Nível III:",
                                  widget.proximaManutencaoN3,
                                  destaque: true)),
                        ],
                      ),
                      const Divider(color: Colors.black, thickness: 1.5),

                      // 5. RODAPÉ + QR CODE
                      SizedBox(
                        height: 100,
                        child: Row(
                          children: [
                            // Texto de Garantia
                            Expanded(
                              flex: 3,
                              child: Text(
                                "TERMOS DE GARANTIA: 1) VALIDADE DA GARANTIA DA CARGA CONF. PROXIMA MANUTENCAO NIVEL II DESCRITO ACIMA. 2) O EXTINTOR DEVE SER INSPECIONADO MENSALMENTE CONF. A NBR 12962. 3) O OPERADOR DEVE ESTAR DEVIDAMENTE TREINADO. SUSPENSAO DA GARANTIA QUANDO: HOUVER VIOLACAO DO SELO INMETRO, ANEL OU LACRE; MAU USO; QUEDAS OU DANOS NO EXTINTOR.",
                                // MUDANÇA IMPORTANTE: Negrito para ficar nítido na térmica
                                style: TextStyle(
                                    fontSize: 7,
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold
                                ),
                                textAlign: TextAlign.justify,
                              ),
                            ),

                            const VerticalDivider(
                                color: Colors.black, thickness: 1),

                            // QR CODE
                            Expanded(
                              flex: 1,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 60,
                                    height: 60,
                                    child: QrImageView(
                                      data: widget.numeroFabricacao,
                                      version: QrVersions.auto,
                                      size: 60.0,
                                      backgroundColor: Colors.white,
                                      padding: const EdgeInsets.all(0),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.numeroFabricacao,
                                    style: const TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black), // Preto Puro
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // --- BOTÕES ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(backgroundColor: Colors.white),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.red),
                label:
                const Text("Fechar", style: TextStyle(color: Colors.red)),
              ),
              if (widget.permitirImpressao)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  icon: _gerandoImagem
                      ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.print, color: Colors.white),
                  label: Text(
                      _gerandoImagem ? "GERANDO..." : "IMPRIMIR GARANTIA",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    setState(() => _gerandoImagem = true);
                    // Captura o provider antes de qualquer await — regra do BuildContext async
                    final provider = context.read<ItemOsProvider>();
                    try {
                      // 1. SE ESTIVER NO WINDOWS: Imprime direto e local (Sem Nuvem)
                      if (Theme.of(context).platform == TargetPlatform.windows) {
                        final pdfBytes = await ImpressaoArgox.gerarLoteEtiquetas(
                            dadosEtiquetas: [{
                              'tipo': 'Garantia',
                              'clienteNome': widget.clienteNome,
                              'tipoExtintor': widget.tipoExtintor,
                              'lote': widget.lote,
                              'numeroFabricacao': widget.numeroFabricacao,
                              'servicoRealizado': widget.servicoRealizado,
                              'proximaManutencaoN2': widget.proximaManutencaoN2,
                              'proximaManutencaoN3': widget.proximaManutencaoN3,
                            }]
                        );

                        await Printing.layoutPdf(
                          onLayout: (format) async => pdfBytes,
                          name: 'Etiqueta_${widget.numeroFabricacao}',
                          format: const PdfPageFormat(100 * PdfPageFormat.mm, 50 * PdfPageFormat.mm),
                          usePrinterSettings: true,
                        );
                      }
                      // 2. SE ESTIVER NO CELULAR/WEB: Mantém a lógica da Fábrica (Nuvem)
                      else {
                        String? impressoraEscolhida = await _selecionarImpressoraDestino();
                        if (impressoraEscolhida != null) {
                          await provider.criarPrintJob(
                            itensIds: [widget.docId],
                            osId: widget.lote,
                            imprimirGarantia: true,
                            imprimirNR23: false,
                            impressora: impressoraEscolhida,
                          );
                        }
                      }

                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
                    } finally {
                      if (mounted) setState(() => _gerandoImagem = false);
                    }
                  },
                ),
            ],
          )
        ],
      ),
    );
  }
  Future<String?> _selecionarImpressoraDestino() async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Selecione a Impressora'),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () { Navigator.pop(context, 'Argox01'); },
              child: const Row(
                children: [
                  Icon(Icons.print, color: Colors.blue),
                  SizedBox(width: 10),
                  Text('Argox Produção (USB)')],
              ),
            ),
            SimpleDialogOption(
              onPressed: () { Navigator.pop(context, 'PDF_Nuvem'); },
              child: const Row(
                children: [Icon(Icons.cloud_upload), SizedBox(width: 10), Text('Salvar na Nuvem')],
              ),
            ),
          ],
        );
      },
    );
  }

  // Widget auxiliar para os campos de texto
  Widget _campo(String label, String valor, {bool destaque = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label,
            // MUDANÇA: Tirei o black54 (cinza) e coloquei black (preto puro)
            style: const TextStyle(fontSize: 9, color: Colors.black)),
        Text(
          valor,
          style: TextStyle(
              fontSize: destaque ? 14 : 11,
              fontWeight: FontWeight.bold,
              color: Colors.black),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // Widget auxiliar para a linha vertical
  Widget _divisorVertical() {
    return Container(
      width: 1,
      height: 30,
      // MUDANÇA: Tirei o black26 (cinza claro) e coloquei black (preto puro)
      color: Colors.black,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}