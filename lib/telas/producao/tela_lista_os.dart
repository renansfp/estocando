// lib/telas/producao/tela_lista_os.dart
// Migrada para Repository Pattern — sem acesso direto ao Firestore.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/ordem_servico_provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
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
          // Barra de filtros
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
                      hintStyle:
                      TextStyle(color: Colors.white.withOpacity(0.7)),
                      prefixIcon:
                      const Icon(Icons.search, color: Colors.white),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    onChanged: (val) =>
                        setState(() => _textoBusca = val.toUpperCase()),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _ocultarFinalizadas
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.white,
                  ),
                  tooltip: _ocultarFinalizadas
                      ? 'Mostrar finalizadas'
                      : 'Ocultar finalizadas',
                  onPressed: () =>
                      setState(() => _ocultarFinalizadas = !_ocultarFinalizadas),
                ),
              ],
            ),
          ),

          // Lista de OS
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              // somentAbertas: true filtra no Firestore quando o usuário
              // oculta finalizadas — evita baixar todas as OS do banco.
              stream: context
                  .read<OrdemServicoProvider>()
                  .streamTodasOrdenadas(
                context.read<UsuarioProvider>().usuario?.empresaId ?? '',
                somentAbertas: _ocultarFinalizadas,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Erro: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var lista = snapshot.data!;

                // Filtro em memória apenas por texto (cliente ou nº OS).
                // O filtro de finalizadas já ocorre no Firestore via
                // somentAbertas — não precisa repetir aqui.
                if (_textoBusca.isNotEmpty) {
                  lista = lista.where((os) {
                    final cliente =
                    (os['clienteNome'] ?? '').toString().toUpperCase();
                    final numero =
                    (os['numeroOS'] ?? '').toString().toUpperCase();
                    return cliente.contains(_textoBusca) ||
                        numero.contains(_textoBusca);
                  }).toList();
                }


                if (lista.isEmpty) {
                  return const Center(child: Text('Nenhuma OS encontrada.'));
                }

                return ListView.builder(
                  itemCount: lista.length,
                  itemBuilder: (context, index) {
                    final os = lista[index];
                    final osId = os['id'] as String;

                    String dataFormatada = '---';
                    if (os['dataEntrada'] != null) {
                      try {
                        final dt = os['dataEntrada'] as DateTime;
                        dataFormatada =
                            DateFormat('dd/MM/yyyy').format(dt);
                      } catch (_) {}
                    }

                    final status =
                    (os['statusLote'] ?? 'Aberto').toString();
                    final numeroOS =
                        os['numeroOS']?.toString() ?? '#';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            numeroOS.length >= 2
                                ? numeroOS.substring(0, 2)
                                : numeroOS,
                          ),
                        ),
                        title: Text(
                          '$numeroOS - ${os['clienteNome'] ?? 'Cliente N/D'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                            'Data: $dataFormatada | Itens: ${os['quantidadeTotal'] ?? 0}'),
                        trailing: Chip(
                          label: Text(
                            status
                                .replaceAll('_', ' ')
                                .toUpperCase(),
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white),
                          ),
                          backgroundColor: Colors.blueGrey,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  TelaDetalhesOS(osId: osId)),
                        ),
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
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TelaCriarOS()),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}