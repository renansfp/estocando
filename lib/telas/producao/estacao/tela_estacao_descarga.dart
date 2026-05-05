import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/provider/item_os_provider.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:protecin_producao/models/item_os.dart';
import 'package:protecin_producao/telas/producao/estacao/tela_balanco_lote.dart';
import 'package:protecin_producao/telas/estoque/tela_criar_requisicao.dart';
import 'package:protecin_producao/utils/mapeador_custos.dart';

class TelaEstacaoDescarga extends StatefulWidget {
  final List<String> filtrosAgente;
  final String tituloEstacao;

  const TelaEstacaoDescarga({
    super.key,
    required this.filtrosAgente,
    required this.tituloEstacao,
  });

  @override
  State<TelaEstacaoDescarga> createState() => _TelaEstacaoDescargaState();
}

class _TelaEstacaoDescargaState extends State<TelaEstacaoDescarga> {
  String _obterIdCurto(String idCompleto) {
    return idCompleto.length >= 5
        ? idCompleto.substring(idCompleto.length - 5).toUpperCase()
        : idCompleto;
  }

  @override
  Widget build(BuildContext context) {
    final usuario = Provider.of<UsuarioProvider>(context, listen: false).usuario;
    if (usuario == null) {
      return const Scaffold(body: Center(child: Text('Erro de usuário')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tituloEstacao),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          tooltip: 'Ir para Home',
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: context.read<ItemOsProvider>().streamItensAguardandoDescarga(
          usuario.empresaId,
          widget.filtrosAgente,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
                child: Text('Nenhuma OS aguardando descarga neste setor.'));
          }

          // Agrupa os itens por OS para montar a fila
          final Map<String, List<ItemOS>> lotesAgrupados = {};
          for (final dados in snapshot.data!) {
            final item = ItemOS.fromJson(dados, dados['id']);
            lotesAgrupados.putIfAbsent(item.osId, () => []).add(item);
          }

          final osIds = lotesAgrupados.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: osIds.length,
            itemBuilder: (context, index) {
              final osId = osIds[index];
              final totalItens = lotesAgrupados[osId]!.length;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TelaBalancoLote(
                        osId: osId,
                        filtrosAgente: widget.filtrosAgente,
                      ),
                    ),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueGrey.shade700,
                    child: Text(
                      _obterIdCurto(osId),
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ),
                  title: const Text('Ordem de Serviço',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$totalItens cilindros aguardando descarga'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.shopping_cart_checkout,
                            color: Colors.blue),
                        tooltip: 'Solicitar Material',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TelaCriarRequisicao(
                                osPrePreenchida: osId,
                                ccPrePreenchido: MapeadorCustos.obterCC(
                                    'DESCARGA E PREPARAÇÃO'),
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
      ),
    );
  }
}