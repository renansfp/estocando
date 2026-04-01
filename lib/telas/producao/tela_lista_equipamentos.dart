// Salve como: lib/telas/tela_lista_equipamentos.dart
// (VERSÃO COM AUTO-CORREÇÃO DE "ZUMBIS")

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:protecin_producao/models/equipamento.dart';

class TelaListaEquipamentos extends StatefulWidget {
  const TelaListaEquipamentos({super.key});

  @override
  State<TelaListaEquipamentos> createState() => _TelaListaEquipamentosState();
}

class _TelaListaEquipamentosState extends State<TelaListaEquipamentos> {
  String? _empresaId;
  Stream<QuerySnapshot>? _equipamentosStream;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  Future<void> _carregarDadosIniciais() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      final data = userDoc.data() as Map<String, dynamic>?;

      if (data == null || data['empresaId'] == null) throw Exception('Usuário sem empresaId.');

      if (mounted) {
        setState(() {
          _empresaId = data['empresaId'];
          _equipamentosStream = FirebaseFirestore.instance
              .collection('equipamentos')
              .where('empresaId', isEqualTo: _empresaId)
              .snapshots();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FUNÇÃO DE CURA (CORRIGE O BUG DO ZUMBI) ---
  Future<void> _verificarECorrigirBloqueio(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final equipId = doc.id;
    final osIdTravada = data['osIdAtual'];
    final statusAtual = data['status'];

    // Se não tem OS vinculada, não tem o que corrigir
    if (osIdTravada == null || osIdTravada.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. Busca a OS que está segurando o equipamento
      final docOS = await FirebaseFirestore.instance.collection('ordens_servico').doc(osIdTravada).get();

      Navigator.pop(context); // Fecha loading

      bool osExiste = docOS.exists;
      bool osFinalizada = false;

      if (osExiste) {
        final dadosOS = docOS.data() as Map<String, dynamic>;
        osFinalizada = dadosOS['statusLote'] == 'finalizada';
      }

      // 2. Análise do Problema
      if (!osExiste) {
        _dialogoCorrecao(
            titulo: "OS Inexistente",
            msg: "Este equipamento está vinculado à OS $osIdTravada, mas ela não existe mais.",
            equipId: equipId
        );
      } else if (osFinalizada) {
        _dialogoCorrecao(
            titulo: "Bloqueio Fantasma Detectado",
            msg: "A OS $osIdTravada JÁ FOI FINALIZADA, mas esqueceu de liberar este cilindro.\nDeseja corrigir o status para 'Disponível' agora?",
            equipId: equipId
        );
      } else {
        // Se a OS ainda está aberta, o bloqueio é legítimo!
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este equipamento está corretamente em produção.')));
      }

    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao verificar: $e')));
    }
  }

  void _dialogoCorrecao({required String titulo, required String msg, required String equipId}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo, style: const TextStyle(color: Colors.orange)),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            icon: const Icon(Icons.build_circle, color: Colors.white),
            label: const Text('CORRIGIR / LIBERAR', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('equipamentos').doc(equipId).update({
                'status': 'ativo',
                'osIdAtual': FieldValue.delete(), // A MÁGICA QUE FALTOU ANTES
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Equipamento liberado com sucesso!'), backgroundColor: Colors.green));
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Equipamentos Cadastrados')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
        stream: _equipamentosStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text('Nenhum equipamento cadastrado.'));

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              // Lógica Visual
              String status = data['status'] ?? 'ativo';
              String? osAtual = data['osIdAtual'];
              bool ocupado = status == 'em_manutencao' || (osAtual != null && osAtual.isNotEmpty);

              return Card(
                color: ocupado ? Colors.orange.shade50 : Colors.white,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: ocupado ? Colors.orange : Colors.green,
                    child: Icon(ocupado ? Icons.lock : Icons.check, color: Colors.white),
                  ),
                  title: Text('Cilindro: ${data['numeroCilindro'] ?? '---'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${data['tipo'] ?? ''} - ${data['capacidade'] ?? ''}'),
                      if (ocupado)
                        Text("🔒 Preso na OS: $osAtual", style: TextStyle(color: Colors.deepOrange[800], fontWeight: FontWeight.bold))
                      else
                        const Text("Disponível", style: TextStyle(color: Colors.green))
                    ],
                  ),
                  trailing: const Icon(Icons.touch_app, size: 16),
                  onTap: () {
                    // Se estiver ocupado, ao clicar, roda o diagnóstico
                    if (ocupado) {
                      _verificarECorrigirBloqueio(doc);
                    } else {
                      // Se estiver livre, pode abrir detalhes (futuro)
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Equipamento livre e pronto para uso.')));
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}