// Salve como: lib/telas/producao/tela_lista_os.dart
// (VERSÃO CORRIGIDA - Lê os campos corretos do banco)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:protecin_producao/telas/producao/tela_criar_os.dart';
import 'package:protecin_producao/telas/producao/tela_detalhe_os.dart';

class TelaListaOS extends StatefulWidget {
  const TelaListaOS({super.key});

  @override
  State<TelaListaOS> createState() => _TelaListaOSState();
}

class _TelaListaOSState extends State<TelaListaOS> {
  String _textoBusca = '';
  bool _ocultarFinalizadas = false;
  final TextEditingController _buscaController = TextEditingController();

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ordens de Serviço'),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // FILTROS
          Container(
            color: Colors.red.shade900,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _buscaController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Buscar Cliente ou Nº OS...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      prefixIcon: const Icon(Icons.search, color: Colors.white),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onChanged: (val) => setState(() => _textoBusca = val.toUpperCase()),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(_ocultarFinalizadas ? Icons.visibility_off : Icons.visibility, color: Colors.white),
                  onPressed: () => setState(() => _ocultarFinalizadas = !_ocultarFinalizadas),
                ),
              ],
            ),
          ),

          // LISTA
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ordens_servico')
              // CORREÇÃO: Usar 'dataEntrada' (que é o que estamos salvando)
                  .orderBy('dataEntrada', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;

                // Filtragem manual
                final docsFiltrados = docs.where((doc) {
                  final dados = doc.data() as Map<String, dynamic>;
                  final cliente = (dados['clienteNome'] ?? '').toString().toUpperCase();
                  final numeroOS = (dados['numeroOS'] ?? '').toString().toUpperCase();

                  // CORREÇÃO: Usar 'statusLote' em vez de 'statusGeral'
                  final status = (dados['statusLote'] ?? 'na_descarga').toString();

                  bool bateTexto = cliente.contains(_textoBusca) || numeroOS.contains(_textoBusca);
                  bool bateStatus = _ocultarFinalizadas ? !status.contains('finaliz') : true;

                  return bateTexto && bateStatus;
                }).toList();

                if (docsFiltrados.isEmpty) {
                  return const Center(child: Text("Nenhuma OS encontrada."));
                }

                return ListView.builder(
                  itemCount: docsFiltrados.length,
                  itemBuilder: (context, index) {
                    final doc = docsFiltrados[index];
                    final os = doc.data() as Map<String, dynamic>;
                    final osId = doc.id;

                    // CORREÇÃO: Usar 'dataEntrada'
                    String dataFormatada = '---';
                    if (os['dataEntrada'] != null) {
                      try {
                        DateTime dt = (os['dataEntrada'] as Timestamp).toDate();
                        dataFormatada = DateFormat('dd/MM/yyyy').format(dt);
                      } catch (e) {}
                    }

                    // CORREÇÃO: Usar 'statusLote'
                    final status = os['statusLote'] ?? 'Aberto';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text(os['numeroOS']?.toString().substring(0,2) ?? '#'),
                        ),
                        title: Text("${os['numeroOS']} - ${os['clienteNome']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Data: $dataFormatada | Itens: ${os['quantidadeTotal'] ?? 0}"),
                        trailing: Chip(
                          label: Text(status.toString().replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white)),
                          backgroundColor: Colors.blueGrey,
                        ),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => TelaDetalhesOS(osId: osId)));
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red.shade900,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaCriarOS())),
      ),
    );
  }
}