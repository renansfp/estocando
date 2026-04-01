// lib/telas/producao/estacao/tela_lista_lotes_limpeza.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_limpeza.dart';
import 'package:protecin_producao/telas/estoque/tela_criar_requisicao.dart';
import 'package:protecin_producao/utils/mapeador_custos.dart';

class TelaListaLotesLimpeza extends StatefulWidget {
  const TelaListaLotesLimpeza({super.key});

  @override
  State<TelaListaLotesLimpeza> createState() => _TelaListaLotesLimpezaState();
}

class _TelaListaLotesLimpezaState extends State<TelaListaLotesLimpeza> {

  String _obterIdCurto(String idCompleto, Map<String, dynamic> dados) {
    if (dados['numeroOS'] != null && dados['numeroOS'].toString().isNotEmpty) {
      return dados['numeroOS'];
    }
    return idCompleto.length >= 5 ? idCompleto.substring(idCompleto.length - 5).toUpperCase() : idCompleto;
  }

  // FUNÇÃO DE REVERSÃO PARA ADMIN
  Future<void> _reverterParaDescarga(String osId, BuildContext context) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ REVERTER LOTE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text('Deseja devolver este lote inteiro para a etapa de DESCARGA?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SIM, DEVOLVER', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmou != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Busca itens que estão travados na limpeza
      final snapshot = await FirebaseFirestore.instance
          .collection('itens_os')
          .where('osId', isEqualTo: osId)
          .where('status', isEqualTo: 'aguardando_limpeza')
          .get();

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'status': 'aguardando_descarga'});
      }

      // Volta o status da OS principal
      final osRef = FirebaseFirestore.instance.collection('ordens_servico').doc(osId);
      batch.update(osRef, {'etapaAtual': 'descarga', 'statusLote': 'em_descarga'});

      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lote devolvido para a Descarga!'), backgroundColor: Colors.orange)
        );
      }
    } catch (e) {
      print("Erro ao reverter: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = Provider.of<UsuarioProvider>(context, listen: false).usuario;
    final bool isAdmin = usuario?.permissao.toLowerCase() == 'admin' ||
        usuario?.permissao.toLowerCase() == 'administrador';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fila de Limpeza'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        // BOTÃO HOME PARA VOLTAR AO INÍCIO
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          tooltip: 'Ir para Home',
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ordens_servico')
            .orderBy('dataEntrada', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final lotes = snapshot.data!.docs;
          if (lotes.isEmpty) return const Center(child: Text('Nenhuma OS na fila.'));

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: lotes.length,
            itemBuilder: (context, index) {
              final doc = lotes[index];
              final dados = doc.data() as Map<String, dynamic>;
              final osId = doc.id;

              // Stream interna para contar apenas itens que realmente estão na limpeza
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('itens_os')
                    .where('osId', isEqualTo: osId)
                    .where('status', isEqualTo: 'aguardando_limpeza')
                    .snapshots(),
                builder: (context, itemSnapshot) {
                  if (!itemSnapshot.hasData || itemSnapshot.data!.docs.isEmpty) {
                    return const SizedBox.shrink(); // Se não tem itens na limpeza, não mostra o card
                  }

                  final totalItens = itemSnapshot.data!.docs.length;

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      // FUNÇÃO ADMIN: SEGURAR PARA REVERTER
                      onLongPress: isAdmin ? () => _reverterParaDescarga(osId, context) : null,

                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => TelaEstacaoLimpeza(osId: osId))
                      ),

                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF1565C0),
                        child: Text(_obterIdCurto(osId, dados), style: const TextStyle(fontSize: 10, color: Colors.white)),
                      ),

                      title: Text(dados['clienteNome'] ?? 'Cliente N/D', style: const TextStyle(fontWeight: FontWeight.bold)),

                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$totalItens cilindros aguardando'),
                          if (isAdmin) const Text('(Segure para reverter)', style: TextStyle(color: Colors.red, fontSize: 10, fontStyle: FontStyle.italic)),
                        ],
                      ),

                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // BOTÃO DE REQUISIÇÃO (CC 4221)
                          IconButton(
                            icon: const Icon(Icons.shopping_cart_checkout, color: Colors.blue),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TelaCriarRequisicao(
                                    osPrePreenchida: dados['numeroOS'] ?? osId,
                                    ccPrePreenchido: MapeadorCustos.obterCC('DESCARGA E PREPARAÇÃO'),
                                    subTipoPrePreenchido: 'OS',
                                  ),
                                ),
                              );
                            },
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
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
}