// Salve como: lib/telas/producao/tela_consulta_equipamentos.dart
// (VERSÃO v2.2 - Foco em Vencimento de Recarga Anual)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:protecin_producao/models/equipamento.dart';
import 'package:protecin_producao/models/parceiro.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/telas/producao/tela_cadastro_equipamento.dart';
import 'package:protecin_producao/widgets/autocomplete_parceiro.dart';
import 'package:provider/provider.dart';

class TelaConsultaEquipamentos extends StatefulWidget {
  const TelaConsultaEquipamentos({super.key});

  @override
  State<TelaConsultaEquipamentos> createState() => _TelaConsultaEquipamentosState();
}

class _TelaConsultaEquipamentosState extends State<TelaConsultaEquipamentos> {
  Parceiro? _clienteSelecionado;
  final TextEditingController _filtroLocalController = TextEditingController();
  String _filtroLocal = '';

  // --- NOVA LÓGICA: SÓ RECARGA ANUAL ---
  Widget _buildAlertaRecarga(Equipamento equip) {
    if (equip.ultimaRecarga == null || equip.ultimaRecarga!.length < 7) {
      return _chipAlerta("SEM DATA RECARGA", Colors.grey);
    }

    try {
      // Parse da Data (MM/AAAA)
      final partes = equip.ultimaRecarga!.split('/');
      final mesRecarga = int.parse(partes[0]);
      final anoRecarga = int.parse(partes[1]);

      // Vencimento é 1 ano depois
      final dataVencimento = DateTime(anoRecarga + 1, mesRecarga);

      // Data de Hoje (Normalizada para o dia 1 para comparar apenas Mês/Ano)
      final hoje = DateTime.now();
      final dataHoje = DateTime(hoje.year, hoje.month);

      // 1. Já venceu (Data de vencimento é anterior a este mês)
      if (dataVencimento.isBefore(dataHoje)) {
        return _chipAlerta("VENCIDO (${equip.ultimaRecarga})", Colors.red);
      }

      // 2. Vence neste mês exato
      if (dataVencimento.isAtSameMomentAs(dataHoje)) {
        return _chipAlerta("VENCE ESTE MÊS", Colors.orange.shade800);
      }

      // 3. Vence no mês que vem (Adiantar?)
      // Calcula o "próximo mês"
      final proximoMes = DateTime(hoje.year, hoje.month + 1);
      if (dataVencimento.isAtSameMomentAs(proximoMes)) {
        return _chipAlerta("Vence Próx. Mês", Colors.amber.shade700);
      }

    } catch (e) {
      return const SizedBox.shrink(); // Erro no formato, ignora
    }

    // Se estiver em dia (vence daqui 2+ meses), não mostra nada para não poluir
    return const SizedBox.shrink();
  }

  Widget _chipAlerta(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: cor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_filled, size: 14, color: cor),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(color: cor, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = Provider.of<UsuarioProvider>(context, listen: false).usuario;
    if (usuario == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Extintores'),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- ÁREA DE SELEÇÃO DO CLIENTE ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blueGrey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('PASSO 1: Selecione a Empresa',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 8),
                AutocompleteParceiroWidget(
                  empresaId: usuario.empresaId,
                  tipoParceiro: TipoParceiro.cliente,
                  label: 'Buscar Cliente...',
                  onParceiroSelected: (p) {
                    setState(() {
                      _clienteSelecionado = p;
                      _filtroLocal = '';
                      _filtroLocalController.clear();
                    });
                  },
                ),
              ],
            ),
          ),

          // --- BARRA DE BUSCA LOCAL ---
          if (_clienteSelecionado != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _filtroLocalController,
                decoration: InputDecoration(
                  labelText: 'Filtrar por Nº Cilindro ou Ativo Fixo',
                  prefixIcon: const Icon(Icons.filter_list),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: _filtroLocal.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _filtroLocalController.clear();
                        _filtroLocal = '';
                      });
                    },
                  )
                      : null,
                ),
                onChanged: (v) => setState(() => _filtroLocal = v.toUpperCase()),
              ),
            ),

          // --- LISTA DE EQUIPAMENTOS ---
          Expanded(
            child: _clienteSelecionado == null
                ? _buildEmptyState()
                : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('equipamentos')
                  .where('clienteId', isEqualTo: _clienteSelecionado!.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Erro ao carregar'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                // Filtragem Local
                final listaFiltrada = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final ativo = (data['ativoFixo'] ?? '').toString().toUpperCase();
                  final cilindro = (data['numeroCilindro'] ?? '').toString().toUpperCase();

                  if (_filtroLocal.isEmpty) return true;
                  return ativo.contains(_filtroLocal) || cilindro.contains(_filtroLocal);
                }).toList();

                // Ordenação: Mostra os VENCIDOS primeiro!
                // Isso ajuda muito na análise visual.
                listaFiltrada.sort((a, b) {
                  // Traz Vencidos pra cima, depois ordena por Ativo
                  // (Lógica simples: você pode refinar se quiser)
                  final atA = (a.data() as Map)['ativoFixo'] ?? '';
                  final atB = (b.data() as Map)['ativoFixo'] ?? '';
                  return atA.compareTo(atB);
                });

                if (listaFiltrada.isEmpty) {
                  return const Center(child: Text('Nenhum equipamento encontrado.'));
                }

                return ListView.builder(
                  itemCount: listaFiltrada.length,
                  itemBuilder: (context, index) {
                    final doc = listaFiltrada[index];
                    final equip = Equipamento.fromJson(
                        doc.data() as Map<String, dynamic>, doc.id);

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getCorStatus(equip.status),
                          child: Icon(_getIconeStatus(equip.status), color: Colors.white, size: 18),
                        ),
                        title: Text(
                          '${equip.ativoFixo} - ${equip.tipo} ${equip.capacidade}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cilindro: ${equip.numeroCilindro} | Fab: ${equip.anoFabricacao}\nUlt. Recarga: ${equip.ultimaRecarga ?? "--"}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            // AQUI ESTÁ O ALERTA DE VENCIMENTO ANUAL
                            _buildAlertaRecarga(equip),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.edit, color: Colors.blueGrey),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TelaCadastroEquipamento(
                                equipamentoParaEditar: equip,
                              ),
                            ),
                          );
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

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red.shade900,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('NOVO', style: TextStyle(color: Colors.white)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TelaCadastroEquipamento(
                clientePreSelecionado: _clienteSelecionado,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Selecione um Cliente acima\npara ver os equipamentos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Color _getCorStatus(StatusEquipamento status) {
    switch (status) {
      case StatusEquipamento.ativo: return Colors.green;
      case StatusEquipamento.emManutencao: return Colors.orange;
      case StatusEquipamento.baixado: return Colors.red;
    }
  }

  IconData _getIconeStatus(StatusEquipamento status) {
    switch (status) {
      case StatusEquipamento.ativo: return Icons.check;
      case StatusEquipamento.emManutencao: return Icons.build;
      case StatusEquipamento.baixado: return Icons.block;
    }
  }
}