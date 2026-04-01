import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class TelaExecucaoMontagem extends StatefulWidget {
  final DocumentSnapshot itemDoc;
  final String osId;

  const TelaExecucaoMontagem({super.key, required this.itemDoc, required this.osId});

  @override
  State<TelaExecucaoMontagem> createState() => _TelaExecucaoMontagemState();
}

class _TelaExecucaoMontagemState extends State<TelaExecucaoMontagem> {
  Uint8List? _bytesImagem;
  bool _carregando = false;

  // Upload começa assim que a foto é tirada.
  // Guardamos a Future para aguardar quando o operador apertar "Concluir".
  Future<String>? _uploadFuture;

  final ImagePicker _picker = ImagePicker();

  // ─── Tira a foto E já dispara o upload em background ──────────────────────
  Future<void> _tirarFoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 55,   // Suficiente para legibilidade do selo
      maxWidth: 1280,     // Limita resolução → arquivo menor → upload mais rápido
      maxHeight: 1280,
    );

    if (photo == null) return;

    final bytes = await photo.readAsBytes();

    setState(() {
      _bytesImagem = bytes;
      _uploadFuture = null; // Cancela referência de foto anterior
    });

    // Dispara o upload IMEDIATAMENTE, sem esperar o operador apertar Concluir
    _uploadFuture = _iniciarUpload(bytes);
  }

  // Upload real — roda em background enquanto o operador confere a foto
  Future<String> _iniciarUpload(Uint8List bytes) async {
    final String idItem = widget.itemDoc.id;
    final ref = FirebaseStorage.instance
        .ref()
        .child('producao/selos/${widget.osId}/$idItem.jpg');

    final task = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    final snapshot = await task;
    return snapshot.ref.getDownloadURL();
  }

  // ─── Concluir — o upload já está feito (ou quase) ─────────────────────────
  Future<void> _finalizarMontagem() async {
    if (_bytesImagem == null || _uploadFuture == null) {
      _notificar('É obrigatório tirar a foto do Selo Inmetro!', Colors.orange);
      return;
    }

    setState(() => _carregando = true);

    try {
      // Aguarda a URL — se o upload já terminou, retorna instantaneamente
      final String urlFoto = await _uploadFuture!;

      await FirebaseFirestore.instance
          .collection('itens_os')
          .doc(widget.itemDoc.id)
          .update({
        'status': 'aguardando_expedicao',
        'montagem_final': {
          'data'       : FieldValue.serverTimestamp(),
          'fotoSeloUrl': urlFoto,
        },
      });

      if (mounted) {
        Navigator.pop(context);
        _notificar('Montagem finalizada!', Colors.green);
      }
    } catch (e) {
      // Se o upload falhou por algum motivo, tenta de novo agora
      if (_bytesImagem != null) {
        try {
          final urlFoto = await _iniciarUpload(_bytesImagem!);
          await FirebaseFirestore.instance
              .collection('itens_os')
              .doc(widget.itemDoc.id)
              .update({
            'status': 'aguardando_expedicao',
            'montagem_final': {
              'data'       : FieldValue.serverTimestamp(),
              'fotoSeloUrl': urlFoto,
            },
          });
          if (mounted) {
            Navigator.pop(context);
            _notificar('Montagem finalizada!', Colors.green);
          }
          return;
        } catch (_) {}
      }
      if (mounted) _notificar('Erro no upload: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _notificar(String msg, Color cor) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: cor));
  }

  @override
  Widget build(BuildContext context) {
    final dados = widget.itemDoc.data() as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Selo Inmetro'),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildInfoCard(dados),
          Expanded(
            child: Center(
              child: _bytesImagem == null
                  ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, size: 100, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Aguardando foto do selo...',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              )
                  : Stack(
                alignment: Alignment.topRight,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.memory(_bytesImagem!, fit: BoxFit.contain),
                  ),
                  // Indicador de upload em progresso
                  FutureBuilder<String>(
                    future: _uploadFuture,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircleAvatar(
                            backgroundColor: Colors.green,
                            radius: 14,
                            child: Icon(Icons.cloud_done, color: Colors.white, size: 18),
                          ),
                        );
                      }
                      return const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircleAvatar(
                          backgroundColor: Colors.orange,
                          radius: 14,
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: Text(_bytesImagem == null ? 'TIRAR FOTO DO SELO' : 'REFAZER FOTO'),
                    onPressed: _tirarFoto,
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.deepPurple),
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: (_carregando || _bytesImagem == null) ? null : _finalizarMontagem,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white),
                    child: _carregando
                        ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        SizedBox(width: 14),
                        Text('Salvando...', style: TextStyle(fontSize: 16)),
                      ],
                    )
                        : const Text('CONCLUIR E FINALIZAR ITEM',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Map<String, dynamic> dados) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        border: Border(bottom: BorderSide(color: Colors.deepPurple.shade100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CRACHÁ: ${dados['idCrachaTemporario']}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepPurple)),
          Text('${dados['tipoAgente']} ${dados['capacidade']}',
              style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}