// lib/widgets/campo_com_scanner.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CampoComScanner extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Function(String)? onSubmitted; // Função que roda ao dar Enter ou ler o QR
  final bool isNumeric;
  final FocusNode? focusNode; // Para controlar o foco (cursor) de fora

  const CampoComScanner({
    super.key,
    required this.controller,
    required this.label,
    this.icon = Icons.qr_code_scanner,
    this.onSubmitted,
    this.isNumeric = false,
    this.focusNode,
  });

  @override
  State<CampoComScanner> createState() => _CampoComScannerState();
}

class _CampoComScannerState extends State<CampoComScanner> {

  // Função para abrir a câmera
  void _abrirScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TelaScanner(),
      ),
    );

    if (result != null && result is String) {
      if (!mounted) return;

      setState(() {
        widget.controller.text = result;
      });

      // Aguarda o próximo frame para o Flutter terminar o rebuild
      // antes de chamar o callback (necessário no Web).
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;

      if (widget.onSubmitted != null) {
        widget.onSubmitted!(result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode, // Aqui ligamos o controle do foco
      keyboardType: widget.isNumeric ? TextInputType.number : TextInputType.text,
      textInputAction: TextInputAction.next, // Botão "Próximo" no teclado do celular
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(widget.icon),
          onPressed: _abrirScanner,
          tooltip: 'Abrir Câmera',
        ),
      ),
      onFieldSubmitted: (value) {
        // Isso captura o "Enter" da pistola USB ou do teclado
        if (widget.onSubmitted != null) {
          widget.onSubmitted!(value);
        }
      },
    );
  }
}

// --- TELA DA CÂMERA (CORRIGIDA PARA V7) ---
class TelaScanner extends StatefulWidget {
  const TelaScanner({super.key});

  @override
  State<TelaScanner> createState() => _TelaScannerState();
}

class _TelaScannerState extends State<TelaScanner> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );

  // ESSA É A TRAVA DE SEGURANÇA
  bool _codigoJaLido = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aponte para o código'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: controller,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                  default:
                    return const Icon(Icons.no_flash, color: Colors.grey);
                }
              },
            ),
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          // 1. SE JÁ LEU, PARA TUDO E NÃO FAZ MAIS NADA
          if (_codigoJaLido) return;

          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              // 2. MARCA QUE LEU PARA BLOQUEAR LEITURAS REPETIDAS
              _codigoJaLido = true;

              // 3. FECHA A TELA COM O CÓDIGO
              Navigator.pop(context, barcode.rawValue);
              break;
            }
          }
        },
      ),
    );
  }
}