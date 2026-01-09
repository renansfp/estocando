// Salve como: lib/telas/producao/estacao/tela_balanco_lote.dart
// (VERSÃO v9.0 - VISUAL RESTAURADO + Lógica de Represa)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_balanco_item.dart';

class TelaBalancoLote extends StatefulWidget {
  final String osId;
  final List<String> filtrosAgente;

  const TelaBalancoLote({
    Key? key,
    required this.osId,
    required this.filtrosAgente,
  }) : super(key: key);

  @override
  _TelaBalancoLoteState createState() => _TelaBalancoLoteState();
}

class _TelaBalancoLoteState extends State<TelaBalancoLote> {

  @override
  Widget build(BuildContext context) {
    // 1. SEGURANÇA: Evita tela vermelha se o filtro vier vazio
    if (widget.filtrosAgente.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erro de Filtro')),
        body: const Center(child: Text('Erro: Nenhum tipo de agente selecionado para filtrar.')),
      );
    }

    final String tituloFiltro = widget.filtrosAgente
        .map((f) => f.toUpperCase().replaceAll('_', ' '))
        .join(' / ');

    final String idVisual = widget.osId.length > 6
        ? '${widget.osId.substring(0, 6)}...'
        : widget.osId;

    return Scaffold(
      appBar: AppBar(
        title: Text('Descarga: $tituloFiltro'),
        backgroundColor: Colors.blueGrey,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20.0),
          child: Text(
            'Lote ID: $idVisual',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('osId', isEqualTo: widget.osId)
            .where('tipoAgente', whereIn: widget.filtrosAgente)
            .snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {

          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Se não veio nada ou acabou
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildTelaConclusao(context, tituloFiltro);
          }

          // Filtra visualmente o que ainda falta (status 'aguardando_descarga')
          final itensParaFazer = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? '';
            return status == 'aguardando_descarga';
          }).toList();

          // Se a lista filtrada estiver vazia, significa que todos já foram feitos
          if (itensParaFazer.isEmpty) {
            return _buildTelaConclusao(context, tituloFiltro);
          }

          // --- AQUI ESTAVA O PROBLEMA: AGORA O VISUAL VOLTOU! ---
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: itensParaFazer.length,
            itemBuilder: (context, index) {
              final itemDoc = itensParaFazer[index];
              final itemData = itemDoc.data() as Map<String, dynamic>;
              final equipamentoId = itemData['equipamentoId'] ?? '';

              // Buscamos os dados do equipamento para montar o Card bonito
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('equipamentos').doc(equipamentoId).get(),
                builder: (context, snapshotEquip) {

                  bool deveDescartar = false;
                  bool mostrarAvisoPo = false;
                  bool carregando = true;
                  String textoEquipamento = "Carregando dados...";

                  if (snapshotEquip.hasData && snapshotEquip.data!.exists) {
                    final dataEquip = snapshotEquip.data!.data() as Map<String, dynamic>;
                    deveDescartar = dataEquip['substituirPo'] ?? false;

                    final String t = (dataEquip['tipo'] ?? '').toString().toUpperCase();
                    mostrarAvisoPo = t.contains('ABC') || t.contains('BC') || t.contains('PQS') || t.contains('PO');

                    final tipo = dataEquip['tipo'] ?? 'Desconhecido';
                    final cap = dataEquip['capacidade'] ?? '';
                    final fab = dataEquip['fabricante'] ?? '';
                    final cil = dataEquip['numeroCilindro'] ?? '?';

                    textoEquipamento = "$tipo $cap - $fab (Cil: $cil)";
                    carregando = false;
                  }

                  // Definição de Cores e Ícones
                  final Color corFundo = deveDescartar ? Colors.red.shade50 : Colors.green.shade50;
                  final Color corIcone = deveDescartar ? Colors.red : Colors.green;
                  final IconData iconeStatus = deveDescartar ? Icons.delete_forever : Icons.recycling;
                  final String textoAcao = deveDescartar ? "DESCARTAR PÓ" : "REUTILIZAR PÓ";

                  // Se não for pó, fundo branco normal
                  final Color corFinal = (mostrarAvisoPo && !carregando) ? corFundo : Colors.white;

                  return Card(
                    color: corFinal,
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: (mostrarAvisoPo && !carregando) ? corIcone : Colors.blueGrey,
                        radius: 25,
                        child: carregando
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Icon((mostrarAvisoPo ? iconeStatus : Icons.fire_extinguisher), color: Colors.white, size: 28),
                      ),
                      title: Text(
                        'Rastreio: ${itemData['idCrachaTemporario'] ?? "N/D"}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(textoEquipamento, style: TextStyle(fontSize: 15, color: Colors.grey[800], fontWeight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          if (!carregando && mostrarAvisoPo)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: corIcone.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: corIcone.withOpacity(0.5))
                              ),
                              child: Text(textoAcao, style: TextStyle(color: corIcone, fontWeight: FontWeight.bold, fontSize: 12)),
                            )
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TelaBalancoItem(
                              idRastreio: itemData['idCrachaTemporario'] ?? "N/D",
                              itemOsId: itemDoc.id,
                              equipamentoId: equipamentoId,
                              tipoAgente: itemData['tipoAgente'] ?? "desconhecido",
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Tela de Conclusão do Setor (Lógica da Represa)
  Widget _buildTelaConclusao(BuildContext context, String tituloFiltro) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text('Setor Finalizado!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              'Os itens de "$tituloFiltro" já foram processados.\nAgora eles aguardam os outros setores.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade700,
                  elevation: 5,
                ),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                label: const Text('VOLTAR', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}