// lib/telas/producao/estacao/tela_lista_lotes_limpeza.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/repositories/item_os_repository.dart';
import 'package:protecin_producao/repositories/ordem_servico_repository.dart';
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
    return idCompleto.length >= 5
        ? idCompleto.substring(idCompleto.length - 5).toUpperCase()
        : idCompleto;
  }

  Future<void> _reverterParaDescarga(String osId, BuildContext context) async {
    // Captura o repository antes do await — regra do BuildContext async
    final repository = context.read<ItemOsRepository>();

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ REVERTER LOTE',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text('Deseja devolver este lote inteiro para a etapa de DESCARGA?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SIM, DEVOLVER',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmou != true) return;

    try {
      await repository.reverterLote(
        osId: osId,
        statusAtual: 'aguardando_limpeza',
        statusAnterior: 'aguardando_descarga',
        dadosOS: {'etapaAtual': 'descarga', 'statusLote': 'em_descarga'},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Lote devolvido para a Descarga!'),
                backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
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
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          tooltip: 'Ir para Home',
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // ← stream externo: todas as OS ordenadas
        stream: context.read<OrdemServicoRepository>().streamTodasOrdenadas(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final ordens = snapshot.data!;
          if (ordens.isEmpty) return const Center(child: Text('Nenhuma OS na fila.'));

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: ordens.length,
            itemBuilder: (context, index) {
              final dados = ordens[index];
              final osId = dados['id'].toString();

              // ← stream interno: itens aguardando limpeza desta OS
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: context.read<ItemOsRepository>()
                    .streamItensPorOsEStatus(osId, 'aguardando_limpeza'),
                builder: (context, itemSnapshot) {
                  if (!itemSnapshot.hasData || itemSnapshot.data!.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final totalItens = itemSnapshot.data!.length;

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      onLongPress: isAdmin
                          ? () => _reverterParaDescarga(osId, context)
                          : null,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => TelaEstacaoLimpeza(osId: osId))),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF1565C0),
                        child: Text(_obterIdCurto(osId, dados),
                            style: const TextStyle(fontSize: 10, color: Colors.white)),
                      ),
                      title: Text(dados['clienteNome'] ?? 'Cliente N/D',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$totalItens cilindros aguardando'),
                          if (isAdmin)
                            const Text('(Segure para reverter)',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.shopping_cart_checkout,
                                color: Colors.blue),
                            onPressed: () => Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) => TelaCriarRequisicao(
                                      osPrePreenchida: dados['numeroOS'] ?? osId,
                                      ccPrePreenchido: MapeadorCustos.obterCC(
                                          'DESCARGA E PREPARAÇÃO'),
                                      subTipoPrePreenchido: 'OS',
                                    ))),
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