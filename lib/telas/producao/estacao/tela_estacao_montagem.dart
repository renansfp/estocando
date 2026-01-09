// Salve como: lib/telas/producao/estacao/tela_estacao_montagem.dart
// (VERSÃO v2.1 - Sem Lacre + Com Leitor de QR Code)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // <--- NÃO ESQUEÇA DE ADICIONAR ESSE PACOTE
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:provider/provider.dart';

class TelaEstacaoMontagem extends StatefulWidget {
  final String osId;
  const TelaEstacaoMontagem({super.key, required this.osId});

  @override
  State<TelaEstacaoMontagem> createState() => _TelaEstacaoMontagemState();
}

class _TelaEstacaoMontagemState extends State<TelaEstacaoMontagem> {
  // Controladores
  final _seloController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Controle de Cor do Anel (Padrão Verde 2026)
  String _corAnel = 'VERDE';
  final List<String> _coresAnel = ['VERDE', 'AMARELO', 'BRANCO', 'AZUL', 'PRETO', 'ALARANJADO', 'ROXO'];

  @override
  void dispose() {
    _seloController.dispose();
    super.dispose();
  }

  // --- LÓGICA DO SCANNER ---
  void _abrirScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Scaffold(
          appBar: AppBar(title: const Text("Ler Selo Inmetro"), backgroundColor: Colors.black, foregroundColor: Colors.white),
          body: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _processarCodigoLido(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
        );
      },
    );
  }

  void _processarCodigoLido(String rawCode) {
    // Lógica para limpar o link e pegar só o código
    String codigoLimpo = rawCode;
    if (rawCode.contains('http') || rawCode.contains('www')) {
      if (rawCode.contains('=')) {
        codigoLimpo = rawCode.split('=').last;
      } else {
        codigoLimpo = rawCode.split('/').last;
      }
    }

    setState(() {
      _seloController.text = codigoLimpo.trim().toUpperCase();
    });

    Navigator.pop(context); // Fecha o scanner
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Selo lido com sucesso!'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
    );
  }
  // -------------------------

  // Abre a janelinha pedindo os dados finais
  void _abrirDialogFinalizacao(DocumentSnapshot itemDoc) {
    final data = itemDoc.data() as Map<String, dynamic>;
    final codigoItem = data['idCrachaTemporario'] ?? '???';
    final tipoAgente = data['tipoAgente'] ?? '???';

    // Limpa os campos para o próximo item
    _seloController.clear();
    _corAnel = 'VERDE'; // Reseta para o padrão

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Montagem Final: $codigoItem'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      'Tipo: $tipoAgente',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)
                  ),
                  const SizedBox(height: 20),

                  // CAMPO SELO INMETRO COM BOTÃO DE CÂMERA
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _seloController,
                          decoration: const InputDecoration(
                            labelText: 'Nº Selo Inmetro *',
                            hintText: 'Bipe ou Digite',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.verified_user, color: Colors.brown),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        icon: const Icon(Icons.qr_code_scanner, size: 28),
                        style: IconButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            minimumSize: const Size(55, 55)
                        ),
                        onPressed: _abrirScanner,
                      )
                    ],
                  ),
                  const SizedBox(height: 15),

                  // CAMPO ANEL (Colorido e Visual)
                  DropdownButtonFormField<String>(
                    value: _corAnel,
                    decoration: const InputDecoration(
                      labelText: 'Cor do Anel',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.circle_outlined),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: _coresAnel.map((cor) {
                      return DropdownMenuItem(
                        value: cor,
                        child: Row(
                          children: [
                            Container(width: 15, height: 15, color: _getCorReal(cor), margin: const EdgeInsets.only(right: 10)),
                            Text(cor),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => _corAnel = v!,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  Navigator.pop(ctx); // Fecha o dialog
                  _finalizarMontagem(itemDoc); // Salva no banco
                }
              },
              child: const Text('FINALIZAR'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _finalizarMontagem(DocumentSnapshot itemDoc) async {
    final usuario = Provider.of<UsuarioProvider>(context, listen: false).usuario;
    final dados = itemDoc.data() as Map<String, dynamic>;
    final equipId = dados['equipamentoId'];
    final codigo = dados['idCrachaTemporario'];

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final itemRef = FirebaseFirestore.instance.collection('itens_os').doc(itemDoc.id);

        // 1. Atualiza Item da OS
        transaction.update(itemRef, {
          'status': 'aguardando_expedicao', // Pronto
          'montagem': {
            'data': FieldValue.serverTimestamp(),
            'operador': usuario?.nome ?? 'Desconhecido',
            'selo_inmetro': _seloController.text.trim(),
            'cor_anel': _corAnel,
            // 'lacre': REMOVIDO CONFORME SOLICITADO
          }
        });

        // 2. Atualiza o Cadastro do Extintor (Para histórico)
        if (equipId != null && equipId.isNotEmpty) {
          final equipRef = FirebaseFirestore.instance.collection('equipamentos').doc(equipId);
          transaction.update(equipRef, {
            'seloInmetroAtual': _seloController.text.trim(),
            'dataUltimaMontagem': FieldValue.serverTimestamp(),
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Item $codigo montado com sucesso!'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red)
        );
      }
    }
  }

  Color _getCorReal(String nomeCor) {
    switch (nomeCor) {
      case 'VERDE': return Colors.green;
      case 'AMARELO': return Colors.yellow;
      case 'BRANCO': return Colors.grey;
      case 'AZUL': return Colors.blue;
      case 'ALARANJADO': return Colors.orange;
      case 'ROXO': return Colors.purple;
      case 'PRETO': return Colors.black;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Execução: Montagem'),
        backgroundColor: Colors.deepPurple[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('osId', isEqualTo: widget.osId)
        // IMPORTANTE: O status deve bater com o que sai da Recarga/Estanqueidade
            .where('status', isEqualTo: 'aguardando_montagem')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final itens = snapshot.data!.docs;

          if (itens.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                  const SizedBox(height: 20),
                  const Text('Lote de Montagem Finalizado!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Voltar para Lista")
                  )
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: itens.length,
            itemBuilder: (context, index) {
              final doc = itens[index];
              final data = doc.data() as Map<String, dynamic>;
              final codigo = data['idCrachaTemporario'] ?? 'Item';
              final tipo = data['tipoAgente'] ?? '';

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurple[100],
                    child: const Icon(Icons.build, color: Colors.deepPurple),
                  ),
                  title: Text(codigo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Text('Agente: $tipo'),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
                    ),
                    onPressed: () => _abrirDialogFinalizacao(doc),
                    child: const Text('FINALIZAR'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}