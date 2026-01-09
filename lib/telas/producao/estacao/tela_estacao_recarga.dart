// Salve como: lib/telas/producao/estacao/tela_estacao_recarga.dart
// (VERSÃO v6.0 - Correção de Capacidade Real e Unidade Litros/Kg)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:protecin_producao/models/movimentacao.dart';
import 'package:protecin_producao/provider/usuario_provider.dart';
import 'package:provider/provider.dart';
import 'package:protecin_producao/models/dados_tecnicos.dart';

class TelaEstacaoRecarga extends StatefulWidget {
  final String osId;
  final List<String> filtrosAgente;
  final String titulo;

  const TelaEstacaoRecarga({
    super.key,
    required this.osId,
    required this.filtrosAgente,
    required this.titulo,
  });

  @override
  State<TelaEstacaoRecarga> createState() => _TelaEstacaoRecargaState();
}

class _TelaEstacaoRecargaState extends State<TelaEstacaoRecarga> {
  // Controles
  final _pesoRecargaController = TextEditingController();

  // Seleção de Produto do Estoque
  String? _produtoEstoqueId;
  Map<String, dynamic>? _produtoEstoqueDados;
  List<DocumentSnapshot> _listaProdutosPo = [];

  // Seleção de Lote
  String? _loteSelecionadoId;
  Map<String, dynamic>? _loteSelecionadoDados;
  List<DocumentSnapshot> _listaLotesDisponiveis = [];

  bool _carregandoEstoque = false;
  bool _buscandoLotes = false;

  @override
  void initState() {
    super.initState();
    // Carrega estoque se for estação de Pó (PQS)
    if (widget.titulo.toUpperCase().contains('PÓ') || widget.titulo.toUpperCase().contains('PQS')) {
      _carregarEstoquePo();
    }
  }

  Future<void> _carregarEstoquePo() async {
    final usuario = Provider.of<UsuarioProvider>(context, listen: false).usuario;
    if (usuario == null) return;

    setState(() => _carregandoEstoque = true);
    try {
      final query = await FirebaseFirestore.instance
          .collection('produtos')
          .where('empresaId', isEqualTo: usuario.empresaId)
          .where('ativo', isEqualTo: true)
          .orderBy('nome')
          .get();

      setState(() {
        _listaProdutosPo = query.docs.where((doc) {
          final nome = (doc['nome'] ?? '').toString().toUpperCase();
          return nome.contains('PO ') || nome.contains('PÓ ') || nome.contains('PQS');
        }).toList();
      });
    } catch (e) {
      print("Erro ao carregar estoque: $e");
    } finally {
      setState(() => _carregandoEstoque = false);
    }
  }

  Future<void> _carregarLotesDoProduto(String produtoId) async {
    setState(() {
      _buscandoLotes = true;
      _listaLotesDisponiveis = [];
      _loteSelecionadoId = null;
      _loteSelecionadoDados = null;
    });

    try {
      final query = await FirebaseFirestore.instance
          .collection('produtos')
          .doc(produtoId)
          .collection('lotes')
          .where('quantidadeAtual', isGreaterThan: 0)
          .orderBy('quantidadeAtual')
          .get();

      setState(() {
        _listaLotesDisponiveis = query.docs;
        // FIFO: Ordena por validade
        _listaLotesDisponiveis.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>?;
          final dataB = b.data() as Map<String, dynamic>?;
          Timestamp? valA = (dataA != null && dataA.containsKey('validade')) ? dataA['validade'] : null;
          Timestamp? valB = (dataB != null && dataB.containsKey('validade')) ? dataB['validade'] : null;
          if(valA == null) return 1;
          if(valB == null) return -1;
          return valA.compareTo(valB);
        });
      });
    } catch (e) {
      print("Erro ao buscar lotes: $e");
    } finally {
      setState(() => _buscandoLotes = false);
    }
  }

  // --- VERSÃO CORRIGIDA E MAIS INTELIGENTE ---
  double _extrairValorNumerico(String texto) {
    if (texto.isEmpty) return 0.0;
    try {
      // Tenta achar o primeiro padrão numérico isolado (ex: "6", "4.5", "10")
      // Isso evita que "Pó 50% 6kg" vire "506". Ele vai pegar o "50" ou "6" dependendo da ordem,
      // mas se pegarmos o campo 'capacidade' puro do cadastro, ele costuma ser limpo ("6kg").

      // Regex busca: digitos, opcionalmente ponto/virgula e mais digitos
      final regex = RegExp(r'(\d+[.,]?\d*)');
      final match = regex.firstMatch(texto);

      if (match != null) {
        String limpo = match.group(0)!.replaceAll(',', '.');
        return double.tryParse(limpo) ?? 0.0;
      }
    } catch (e) {
      return 0.0;
    }
    return 0.0;
  }

  // Agora a função é ASYNC para buscar o dado real no cadastro
  Future<void> _abrirDialogRecarga(DocumentSnapshot itemDoc) async {
    // Mostra um carregando rápido para o usuário não achar que travou
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    final dataItem = itemDoc.data() as Map<String, dynamic>;
    final equipId = dataItem['equipamentoId'];

    String capacidadeReal = '';
    String tipoReal = dataItem['tipoAgente']?.toString().toUpperCase() ?? '';
    String projetoReal = dataItem['projeto'] ?? '';
    bool deveTrocarPo = (dataItem['substituirPo'] == true);

    // --- 1. BUSCA O DADO FRESCO NO CADASTRO DO EQUIPAMENTO ---
    if (equipId != null && equipId.isNotEmpty) {
      try {
        final docEquip = await FirebaseFirestore.instance.collection('equipamentos').doc(equipId).get();
        if (docEquip.exists) {
          final dataEq = docEquip.data() as Map<String, dynamic>;
          // AQUI ESTÁ A CORREÇÃO: Lemos direto da fonte
          capacidadeReal = dataEq['capacidade']?.toString() ?? '';

          // Aproveita para atualizar outros dados se necessário
          if (dataEq['tipo'] != null) tipoReal = dataEq['tipo'].toString().toUpperCase();

          // Se o cadastro do equipamento mandar trocar, respeitamos
          if (dataEq['substituirPo'] == true) deveTrocarPo = true;
        }
      } catch (e) {
        print("Erro ao buscar equipamento: $e");
      }
    }

    // Fecha o loading
    if (mounted) Navigator.pop(context);

    // --- LÓGICA DE VALOR ---
    double valorSugerido = 0.0;

    // Prioridade 1: Campo Capacidade do Cadastro (Ex: "6 KG")
    if (capacidadeReal.isNotEmpty) {
      valorSugerido = _extrairValorNumerico(capacidadeReal);
    }

    // Prioridade 2: Se falhar, tenta o campo do Item OS
    if (valorSugerido == 0) {
      valorSugerido = _extrairValorNumerico(dataItem['capacidade']?.toString() ?? '');
    }

    // Prioridade 3: Nome do Agente (Fallback)
    if (valorSugerido == 0) {
      valorSugerido = _extrairValorNumerico(tipoReal);
    }

    // Atualiza Controller
    _pesoRecargaController.text = valorSugerido > 0 ? valorSugerido.toString() : '';

    // Reseta Dropdowns
    _produtoEstoqueId = null;
    _loteSelecionadoId = null;

    final codigo = dataItem['idCrachaTemporario'] ?? '???';
    final triagem = dataItem['triagem'] as Map<String, dynamic>? ?? {};

    // Atualiza lógica de troca com os dados da triagem também
    if (triagem['poCondenado'] == true) deveTrocarPo = true;

    // Identificação de Unidade
    bool isLitros = tipoReal.contains('AGUA') || tipoReal.contains('ÁGUA') || tipoReal.contains('ESPUMA');
    String suffixUnidade = isLitros ? 'L' : 'kg';
    bool isPQS = tipoReal.contains('PO') || tipoReal.contains('PQS') || tipoReal.contains('ABC') || tipoReal.contains('BC');

    // Filtro de Estoque
    List<DocumentSnapshot> produtosFiltrados = _listaProdutosPo;
    if (isPQS) {
      produtosFiltrados = _listaProdutosPo.where((doc) {
        String nomeProd = (doc['nome'] ?? '').toString().toUpperCase();
        if (tipoReal.contains('ABC')) return nomeProd.contains('ABC');
        if (tipoReal.contains('BC')) return nomeProd.contains('BC') && !nomeProd.contains('ABC');
        return true;
      }).toList();
    }

    if (!mounted) return;

    // --- ABRE O DIALOG (Igual ao anterior, mas com variáveis atualizadas) ---
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Recarga: $codigo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Agente: $tipoReal', style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (capacidadeReal.isNotEmpty)
                      Text('Capacidade Cadastro: $capacidadeReal', style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),

                    const SizedBox(height: 15),

                    // --- AVISOS VISUAIS ---
                    if (isPQS) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                        decoration: BoxDecoration(
                          color: deveTrocarPo ? Colors.deepOrange : Colors.green[700],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(deveTrocarPo ? Icons.delete_forever : Icons.recycling, color: Colors.white, size: 30),
                            const SizedBox(height: 5),
                            Text(
                              deveTrocarPo ? "ORDEM: TROCAR PÓ" : "ORDEM: REUTILIZAR PÓ",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                        decoration: BoxDecoration(
                          color: isLitros ? Colors.blue : Colors.grey[700],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(isLitros ? Icons.water_drop : Icons.cloud, color: Colors.white, size: 30),
                            const SizedBox(height: 5),
                            const Text("RECARGA DIRETA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // --- CAMPOS DE ESTOQUE (Só se for PQS e TROCA) ---
                    if (isPQS && deveTrocarPo) ...[
                      const Text("Pó Novo (Compatível):", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        hint: const Text('Selecione o Produto'),
                        value: _produtoEstoqueId,
                        items: produtosFiltrados.map((doc) {
                          final p = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem(value: doc.id, child: Text(p['nome'], overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)));
                        }).toList(),
                        onChanged: (v) {
                          setStateDialog(() {
                            _produtoEstoqueId = v;
                            _produtoEstoqueDados = _listaProdutosPo.firstWhere((d) => d.id == v).data() as Map<String, dynamic>;
                            _loteSelecionadoId = null;
                          });
                          _carregarLotesDoProduto(v!).then((_) => setStateDialog(() {}));
                        },
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 10),
                      if (_buscandoLotes) const LinearProgressIndicator()
                      else if (_produtoEstoqueId != null)
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          hint: const Text('Qual Lote?'),
                          value: _loteSelecionadoId,
                          items: _listaLotesDisponiveis.map((doc) {
                            final l = doc.data() as Map<String, dynamic>;
                            final numero = l['numero'];
                            final saldo = (l['quantidadeAtual'] ?? 0).toDouble();
                            String validade = '---';
                            if (l['validade'] != null) validade = DateFormat('MM/yy').format((l['validade'] as Timestamp).toDate());

                            // AQUI ESTÁ A CORREÇÃO DO ERRO ANTERIOR TAMBÉM (valorSugerido)
                            return DropdownMenuItem(
                              value: doc.id,
                              child: Text("Lote $numero (Val: $validade) - Restam: $saldo kg",
                                style: TextStyle(fontSize: 13, color: saldo < valorSugerido ? Colors.red : Colors.black),
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => setStateDialog(() {
                            _loteSelecionadoId = v;
                            _loteSelecionadoDados = _listaLotesDisponiveis.firstWhere((d) => d.id == v).data() as Map<String, dynamic>;
                          }),
                          decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Colors.amberAccent),
                        ),
                    ],

                    const SizedBox(height: 15),

                    TextFormField(
                      controller: _pesoRecargaController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isLitros ? 'Volume (Litros)' : 'Peso (Kg)',
                        border: const OutlineInputBorder(),
                        suffixText: suffixUnidade,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    // Validações Básicas
                    if (isPQS && deveTrocarPo) {
                      if (_produtoEstoqueId == null || _loteSelecionadoId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione o Pó e o Lote!')));
                        return;
                      }
                    }
                    Navigator.pop(ctx);
                    _processarRecarga(itemDoc, isPQS, deveTrocarPo);
                  },
                  child: const Text('CONFIRMAR', style: TextStyle(color: Colors.white)),
                )
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _processarRecarga(DocumentSnapshot itemDoc, bool isPQS, bool trocarPo) async {
    final usuario = Provider.of<UsuarioProvider>(context, listen: false).usuario;
    final dadosItem = itemDoc.data() as Map<String, dynamic>;
    final equipId = dadosItem['equipamentoId'];

    // Define Unidade (L ou Kg)
    final bool isLitros = dadosItem['tipoAgente'].toString().toUpperCase().contains('AGUA') ||
        dadosItem['tipoAgente'].toString().toUpperCase().contains('ESPUMA');
    final String unidade = isLitros ? 'L' : 'kg';

    try {
      final double qtdInput = double.parse(_pesoRecargaController.text.replaceAll(',', '.'));

      final itemRef = FirebaseFirestore.instance.collection('itens_os').doc(itemDoc.id);
      final movRef = FirebaseFirestore.instance.collection('movimentacoes').doc();
      DocumentReference? equipRef;

      if (equipId != null && equipId.isNotEmpty) {
        equipRef = FirebaseFirestore.instance.collection('equipamentos').doc(equipId);
      }

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 1. Lógica de Estoque (Baixa apenas se for PQS e houver TROCA)
        if (isPQS && trocarPo) {
          final produtoRef = FirebaseFirestore.instance.collection('produtos').doc(_produtoEstoqueId);
          final loteRef = produtoRef.collection('lotes').doc(_loteSelecionadoId);

          final loteSnap = await transaction.get(loteRef);
          if (!loteSnap.exists) throw Exception("Lote não encontrado!");

          final double saldoLote = (loteSnap.data()!['quantidadeAtual'] ?? 0).toDouble();
          if (saldoLote < qtdInput) throw Exception("Saldo do Lote Insuficiente!");

          final prodSnap = await transaction.get(produtoRef);
          final double saldoGeral = (prodSnap.data()!['quantidadeAtual'] ?? 0).toDouble();

          transaction.update(loteRef, {'quantidadeAtual': saldoLote - qtdInput});
          transaction.update(produtoRef, {'quantidadeAtual': saldoGeral - qtdInput});

          final novaMov = Movimentacao(
            empresaId: usuario!.empresaId,
            produtoId: _produtoEstoqueId!,
            produtoCodigo: _produtoEstoqueDados?['codigo'] ?? '',
            produtoNome: _produtoEstoqueDados?['nome'] ?? '',
            tipo: TipoMovimentacao.saida,
            quantidade: qtdInput,
            data: DateTime.now(),
            subTipo: 'Produção / OS',
            numeroOS: dadosItem['osId'],
            nomeColaborador: usuario.nome,
            motivoAcerto: "Recarga Item ${dadosItem['idCrachaTemporario']}",
          );

          final jsonMov = novaMov.toJson();
          jsonMov['loteId'] = _loteSelecionadoId;
          jsonMov['loteNumero'] = _loteSelecionadoDados?['numero'];

          transaction.set(movRef, jsonMov);
        }

        // 2. Atualiza o Item da OS
        transaction.update(itemRef, {
          'status': 'aguardando_estanqueidade',
          'recarga': {
            'data': FieldValue.serverTimestamp(),
            'operador': usuario!.nome,
            'tipo': (isPQS && trocarPo) ? 'TROCA_PO' : (isPQS ? 'MANTER_PO' : 'RECARGA_SIMPLES'),
            'produtoId': _produtoEstoqueId,
            'loteId': _loteSelecionadoId,
            'loteNumero': _loteSelecionadoDados?['numero'],
            'qtd': qtdInput,
            'unidade': unidade
          }
        });

        // 3. ATUALIZA O CADASTRO DO EQUIPAMENTO (Histórico Futuro)
        if (equipRef != null) {
          Map<String, dynamic> updatesEquip = {
            // A Última Recarga sempre atualiza (todo ano)
            'ultimaRecarga': DateFormat('MM/yyyy').format(DateTime.now()),
            'origemSelo': 'NOSSA', // Agora o extintor é "Nosso"
          };

          if (isPQS && trocarPo) {
            // Se trocou o pó, atualizamos os dados específicos do pó
            updatesEquip['substituirPo'] = false; // Resetamos o alerta
            updatesEquip['lotePo'] = _loteSelecionadoDados?['numero'];

            // --- CAMPO NOVO SOLICITADO ---
            // Salva a data exata da troca do pó (Ex: 01/2026)
            // Assim saberemos que a validade dele vai até 01/2031 (5 anos)
            updatesEquip['ultimaTrocaPo'] = DateFormat('MM/yyyy').format(DateTime.now());
          }

          transaction.update(equipRef, updatesEquip);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recarga e Cadastro Atualizados!'), backgroundColor: Colors.green));
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: ${e.toString().replaceAll("Exception:", "")}'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo), backgroundColor: Colors.green[700]),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('itens_os')
            .where('osId', isEqualTo: widget.osId)
            .where('status', isEqualTo: 'aguardando_recarga')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final itens = snapshot.data!.docs.where((doc) {
            final tipo = (doc['tipoAgente'] ?? '').toString().toUpperCase();
            return widget.filtrosAgente.any((filtro) => tipo.contains(filtro));
          }).toList();

          if (itens.isEmpty) return const Center(child: Text('Nenhum item pendente.'));

          return ListView.builder(
            itemCount: itens.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              final doc = itens[index];
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(Icons.build, color: Colors.green[800])),
                  title: Text(data['idCrachaTemporario'] ?? ''),
                  subtitle: Text(data['tipoAgente'] ?? ''),
                  trailing: ElevatedButton(
                    onPressed: () => _abrirDialogRecarga(doc),
                    child: const Text('RECARREGAR'),
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