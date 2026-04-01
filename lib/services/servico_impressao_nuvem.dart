import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data'; // Importante para Uint8List

class ServicoImpressaoNuvem {

  /// Envia um comando PPLA para a fila 'print_jobs' que o Monitor está ouvindo
  static Future<void> enviarParaFila({
    required BuildContext context,
    required dynamic comandoPPLA, // Aceita List<int> ou Uint8List
    required String nomeImpressoraDestino, // Ex: "Argox01"
  }) async {
    try {
      final usuario = Provider.of<UsuarioProvider>(context, listen: false).usuario;


      // --- AQUI ESTÁ A CORREÇÃO ---
      // Enviamos para 'print_jobs' com os campos em inglês que o Monitor espera
      await FirebaseFirestore.instance.collection('print_jobs').add({
        'printerName': nomeImpressoraDestino,
        // Forçamos o dado a ser um array de bytes puro
        'command_list': comandoPPLA,//Uint8List.fromList(
           // comandoPPLA is String ? ascii.encode(comandoPPLA) : List<int>.from(comandoPPLA)
        //),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'usuario_solicitante': usuario?.nome ?? 'Desconhecido',
        'empresa_id': usuario?.empresaId ?? '',
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enviado para $nomeImpressoraDestino!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print("Erro Firestore: $e");
    }
  }
}