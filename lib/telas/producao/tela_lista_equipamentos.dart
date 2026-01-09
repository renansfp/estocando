// Salve como: lib/telas/tela_lista_equipamentos.dart

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
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      final data = userDoc.data() as Map<String, dynamic>?;
      if (data == null || data['empresaId'] == null) {
        throw Exception('Usuário sem empresaId.');
      }

      final idEmpresa = data['empresaId'];

      if (mounted) {
        setState(() {
          _empresaId = idEmpresa;
          _inicializarStream();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
    }
  }

  void _inicializarStream() {
    setState(() {
      _equipamentosStream = FirebaseFirestore.instance
          .collection('equipamentos')
          .where('empresaId', isEqualTo: _empresaId)
          .snapshots();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipamentos Cadastrados'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildListaEquipamentos(),
    );
  }

  Widget _buildListaEquipamentos() {
    if (_equipamentosStream == null) {
      return const Center(child: Text('Erro de permissão.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _equipamentosStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Nenhum equipamento cadastrado.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];

            // Converte usando o novo modelo v3.0
            Equipamento equipamento = Equipamento.fromJson(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blueGrey.shade100,
                  child: Text(equipamento.tipo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                title: Text(
                  'Cilindro: ${equipamento.numeroCilindro}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Ativo: ${equipamento.ativoFixo} | ${equipamento.clienteNome}'),
                trailing: Text(equipamento.capacidade),
              ),
            );
          },
        );
      },
    );
  }
}