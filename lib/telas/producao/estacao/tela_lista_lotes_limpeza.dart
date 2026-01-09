// Salve como: lib/telas/producao/estacao/tela_estacao_limpeza.dart
// (VERSÃO v3.0 - Com Reversão de Lote Admin)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:protecin_producao/provider/usuario_provider.dart'; // Import necessário
import 'package:provider/provider.dart'; // Import necessário
// import 'package:protecin_producao/telas/producao/estacao/tela_estacao_limpeza_detalhe.dart'; // Supondo que seja essa a tela de detalhe
import 'package:intl/intl.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_estacao_limpeza.dart';

class TelaListaLotesLimpeza extends StatefulWidget {
  const TelaListaLotesLimpeza({super.key});

  @override
  State<TelaListaLotesLimpeza> createState() => _TelaListaLotesLimpezaState();
}

class _TelaListaLotesLimpezaState extends State<TelaListaLotesLimpeza> {

  // Função auxiliar visual
  String _obterIdCurto(String idCompleto, Map<String, dynamic> dados) {
    if (dados['numeroOS'] != null && dados['numeroOS'].toString().isNotEmpty) {
      return dados['numeroOS'];
    }
    if (idCompleto.length >= 5) {
      return idCompleto.substring(idCompleto.length - 5).toUpperCase();
    }
    return idCompleto;
  }

  // --- FUNÇÃO DE REVERSÃO (ADMIN) ---
  Future<void> _reverterParaDescarga(String osId, BuildContext context) async {
    // Diálogo de confirmação
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ REVERTER LOTE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text(
          'Tem certeza que deseja devolver este lote inteiro para a etapa de DESCARGA?\n\n'
              'Os itens sumirão desta tela e voltarão para o controle de descarga.',
        ),
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

    // Executa a reversão
    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Busca itens desta OS que estão na Limpeza
      final snapshot = await FirebaseFirestore.instance
          .collection('itens_os')
          .where('osId', isEqualTo: osId)
          .where('status', isEqualTo: 'aguardando_limpeza')
          .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum item encontrado para reverter.')));
        return;
      }

      // 2. Atualiza itens para 'aguardando_descarga'
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'status': 'aguardando_descarga',
          // Opcional: pode remover o campo 'historico_descarga' se quiser limpar o rastro
          // 'historico_descarga': FieldValue.delete(),
        });
      }

      // 3. Atualiza a OS Mãe para voltar o status
      final osRef = FirebaseFirestore.instance.collection('ordens_servico').doc(osId);
      batch.update(osRef, {
        'etapaAtual': 'descarga',
        'statusLote': 'em_descarga',
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lote devolvido para a Descarga!'), backgroundColor: Colors.orange),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao reverter: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Pega usuário para checar permissão
    final usuario = Provider.of<UsuarioProvider>(context, listen: false).usuario;
    final bool isAdmin = usuario?.permissao.toLowerCase() == 'admin' ||
        usuario?.permissao.toLowerCase() == 'administrador';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lotes na Limpeza (Fila)'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ordens_servico')
            .orderBy('dataEntrada', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final lotes = snapshot.data!.docs;
          if (lotes.isEmpty) return const Center(child: Text('Nenhuma OS encontrada.'));

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: lotes.length,
            itemBuilder: (context, index) {
              final doc = lotes[index];
              final dados = doc.data() as Map<String, dynamic>;
              final osId = doc.id;
              final cliente = dados['clienteNome'] ?? 'Cliente Desconhecido';

              String dataFormatada = "Data N/D";
              if (dados['dataEntrada'] != null) {
                final timestamp = dados['dataEntrada'] as Timestamp;
                dataFormatada = DateFormat('dd/MM HH:mm').format(timestamp.toDate());
              }

              String idVisual = _obterIdCurto(osId, dados);

              // Stream interna (Caça-Fantasmas)
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('itens_os')
                    .where('osId', isEqualTo: osId)
                    .where('status', isEqualTo: 'aguardando_limpeza')
                    .snapshots(),
                builder: (context, itemSnapshot) {
                  if (!itemSnapshot.hasData || itemSnapshot.data!.docs.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final itensPendentes = itemSnapshot.data!.docs.length;

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: InkWell( // InkWell adiciona o efeito de clique e suporte a LongPress
                      borderRadius: BorderRadius.circular(10),

                      // --- A MÁGICA ACONTECE AQUI ---
                      onLongPress: isAdmin ? () => _reverterParaDescarga(osId, context) : null,

                      onTap: () {
                        // Navegação normal para a tela de trabalhar na limpeza
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            // Ajuste aqui para o nome da sua classe real de detalhe da limpeza
                            builder: (context) => TelaEstacaoLimpeza(osId: osId),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        child: Row(
                          children: [
                            // Ícone/Avatar
                            CircleAvatar(
                              backgroundColor: const Color(0xFF1565C0),
                              radius: 24,
                              child: Text(
                                idVisual,
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Texto Central
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cliente, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text('Entrada: $dataFormatada', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  if (isAdmin)
                                    const Text(
                                        '(Segure para devolver)',
                                        style: TextStyle(fontSize: 10, color: Colors.redAccent, fontStyle: FontStyle.italic)
                                    ),
                                ],
                              ),
                            ),
                            // Contador
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange)
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.cleaning_services, size: 16, color: Colors.deepOrange),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$itensPendentes',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[900], fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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