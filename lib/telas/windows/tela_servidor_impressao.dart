import 'package:flutter/material.dart';
import 'package:protecin_producao/services/monitor_impressao_windows.dart';

class TelaServidorImpressao extends StatefulWidget {
  const TelaServidorImpressao({super.key});

  @override
  State<TelaServidorImpressao> createState() => _TelaServidorImpressaoState();
}

class _TelaServidorImpressaoState extends State<TelaServidorImpressao> {
  final TextEditingController _nomeImpressoraController =
  TextEditingController(text: "Argox OS-214 plus series PPLA");
  bool _ativo = false;
  MonitorImpressaoWindows? _monitor;

  // Lista para mostrar o que está acontecendo na tela
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();

  void _adicionarLog(String mensagem) {
    if (!mounted) return;
    setState(() {
      _logs.add("[${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}] $mensagem");
    });
    // Rola para o final automaticamente
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _alternarMonitor() {
    if (_ativo) {
      // Desligar
      _monitor?.parar();
      setState(() => _ativo = false);
    } else {
      // Ligar
      if (_nomeImpressoraController.text.isEmpty) return;

      FocusScope.of(context).unfocus(); // Fecha teclado

      setState(() => _ativo = true);

      _monitor = MonitorImpressaoWindows(
        nomeImpressora: _nomeImpressoraController.text,
        onLog: _adicionarLog, // Passa a função que escreve na tela
      );
      _monitor!.iniciar();
    }
  }

  @override
  void dispose() {
    _monitor?.parar(); // Garante que para se fechar a tela
    _nomeImpressoraController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servidor de Impressão'),
        backgroundColor: _ativo ? Colors.green[700] : Colors.blueGrey,
      ),
      body: Row(
        children: [
          // LADO ESQUERDO: CONFIGURAÇÃO
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.print, size: 80, color: _ativo ? Colors.green : Colors.grey),
                  const SizedBox(height: 20),
                  const Text(
                    'Configuração Argox',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nomeImpressoraController,
                    enabled: !_ativo,
                    decoration: const InputDecoration(
                      labelText: 'Nome do Compartilhamento',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.settings_ethernet),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: Icon(_ativo ? Icons.stop : Icons.play_arrow),
                      label: Text(_ativo ? 'PARAR SERVIDOR' : 'INICIAR SERVIDOR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _ativo ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _alternarMonitor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // LADO DIREITO: LOGS (CONSOLE NA TELA)
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black87,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("LOG DE EXECUÇÃO:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const Divider(color: Colors.white24),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _logs.length,
                      itemBuilder: (ctx, i) => Text(
                        _logs[i],
                        style: const TextStyle(color: Colors.greenAccent, fontFamily: 'Courier', fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}