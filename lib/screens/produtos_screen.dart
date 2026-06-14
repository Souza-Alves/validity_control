import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/produto.dart';
import '../models/local.dart';
import '../storage/storage.dart';
import '../utils/date_utils.dart' as du;
import '../main.dart' show kPrimaryColor;

class ProdutosScreen extends StatefulWidget {
  const ProdutosScreen({super.key});

  @override
  State<ProdutosScreen> createState() => _ProdutosScreenState();
}

class _ProdutosScreenState extends State<ProdutosScreen>
    with AutomaticKeepAliveClientMixin {
  List<Produto> _produtos = [];
  List<Local> _locais = [];
  final List<String> _filtrosLocal = [];
  String _dataInicial = '';
  String _dataFinal = '';
  String _diasFiltro = '';
  String _sortField = 'validade';
  bool _sortAsc = true;
  bool _loading = true;
  final _dataInicialCtrl = TextEditingController();
  final _dataFinalCtrl = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted && _produtos.isEmpty) setState(() => _loading = true);
    final prods = await getProdutos();
    final locs = await getLocais();
    if (mounted) setState(() { _produtos = prods; _locais = locs; _loading = false; });
  }

  bool _isLocalAtivo(Produto p) {
    for (final l in _locais) {
      if (l.id == p.localId) return l.ativo;
    }
    for (final l in _locais) {
      if (l.nome.toLowerCase() == p.localNome.toLowerCase()) return l.ativo;
    }
    return false;
  }

  List<Produto> get _filtered {
    return _produtos.where((p) {
      if (!_isLocalAtivo(p)) return false;
      if (_filtrosLocal.isNotEmpty) {
        if (!_filtrosLocal.any((f) => p.localNome.toLowerCase() == f.toLowerCase())) return false;
      }
      if (_dataInicial.isNotEmpty && _dataFinal.isNotEmpty) {
        return du.isInRange(p.validade, _dataInicial, _dataFinal);
      }
      final days = int.tryParse(_diasFiltro);
      if (days != null && days >= 0) {
        return du.isWithinDays(p.validade, days);
      }
      return true;
    }).toList();
  }

  List<Produto> get _sorted {
    final list = List<Produto>.from(_filtered);
    list.sort((a, b) {
      int cmp;
      switch (_sortField) {
        case 'local':
          cmp = a.localNome.compareTo(b.localNome);
        case 'qtd':
          cmp = a.quantidade.compareTo(b.quantidade);
        case 'produto':
          cmp = a.nome.compareTo(b.nome);
        default:
          cmp = du.compareDates(a.validade, b.validade);
      }
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  void _toggleSort(String field) {
    setState(() {
      if (_sortField == field) {
        _sortAsc = !_sortAsc;
      } else {
        _sortField = field;
        _sortAsc = true;
      }
    });
  }

  String _sortArrow(String field) =>
      _sortField == field ? (_sortAsc ? ' ▲' : ' ▼') : '';

  void _toggleLocalFilter(String nome) {
    setState(() {
      if (_filtrosLocal.contains(nome)) {
        _filtrosLocal.remove(nome);
      } else {
        _filtrosLocal.add(nome);
      }
    });
  }

  Future<void> _openEditModal(Produto produto) async {
    final locaisAtivos = _locais.where((l) => l.ativo).toList();
    String editLocalId = produto.localId;
    String editLocalNome = produto.localNome;
    String editNome = produto.nome;
    String editValidade = produto.validade;
    String editQuantidade = produto.quantidade.toString();
    String editSituacao = produto.situacao;
    String editStatus = produto.status;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Editar Produto', textAlign: TextAlign.center),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Localizacao:', style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: locaisAtivos.any((l) => l.id == editLocalId) ? editLocalId : null,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: locaisAtivos.map((l) => DropdownMenuItem(value: l.id, child: Text(l.nome))).toList(),
                  onChanged: (v) {
                    final loc = locaisAtivos.firstWhere((l) => l.id == v);
                    setDialogState(() { editLocalId = loc.id; editLocalNome = loc.nome; });
                  },
                ),
                const SizedBox(height: 12),
                const Text('Produto:', style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
                const SizedBox(height: 4),
                TextFormField(
                  initialValue: editNome,
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  onChanged: (v) => editNome = v,
                ),
                const SizedBox(height: 12),
                const Text('Validade:', style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
                const SizedBox(height: 4),
                TextFormField(
                  initialValue: editValidade,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'DD/MM/AAAA', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  keyboardType: TextInputType.number,
                  maxLength: 10,
                  onChanged: (v) {
                    final masked = du.applyDateMask(v);
                    editValidade = masked;
                  },
                ),
                const SizedBox(height: 12),
                const Text('Quantidade:', style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
                const SizedBox(height: 4),
                TextFormField(
                  initialValue: editQuantidade,
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => editQuantidade = v,
                ),
                const SizedBox(height: 12),
                const Text('Situacao:', style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: editSituacao.isEmpty ? null : editSituacao,
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  hint: const Text('Selecione'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Nenhum')),
                    DropdownMenuItem(value: 'Vendido', child: Text('Vendido')),
                    DropdownMenuItem(value: 'Vencido', child: Text('Vencido')),
                  ],
                  onChanged: (v) => setDialogState(() {
                    editSituacao = v ?? '';
                    if (editSituacao != 'Vencido') editStatus = '';
                  }),
                ),
                const SizedBox(height: 12),
                Text('Status:', style: TextStyle(fontSize: 13, color: editSituacao == 'Vencido' ? const Color(0xFF666666) : const Color(0xFFBBBBBB))),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: editStatus.isEmpty ? null : editStatus,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    enabled: editSituacao == 'Vencido',
                  ),
                  hint: Text(editSituacao == 'Vencido' ? 'Selecione' : 'Disponivel apenas para Vencido'),
                  items: editSituacao == 'Vencido'
                      ? const [
                          DropdownMenuItem(value: '', child: Text('Nenhum')),
                          DropdownMenuItem(value: 'Baixado', child: Text('Baixado')),
                          DropdownMenuItem(value: 'Pendente', child: Text('Pendente')),
                        ]
                      : null,
                  onChanged: editSituacao == 'Vencido' ? (v) => setDialogState(() => editStatus = v ?? '') : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: const Color(0xFFE74C3C)),
              onPressed: () {
                showDialog(
                  context: ctx,
                  builder: (c) => AlertDialog(
                    title: const Text('Confirmar exclusao'),
                    content: Text('Deseja remover "${produto.nome}"?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () async {
                          await deleteProduto(produto.id);
                          if (c.mounted) Navigator.pop(c);
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadData();
                        },
                        child: const Text('Remover'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Remover'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, foregroundColor: Colors.white),
              onPressed: () async {
                if (editNome.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Nome do produto e obrigatorio.')));
                  return;
                }
                if (editValidade.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Data de validade e obrigatoria.')));
                  return;
                }
                final qty = int.tryParse(editQuantidade);
                if (qty == null || qty < 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Quantidade invalida.')));
                  return;
                }
                await updateProduto(produto.copyWith(
                  localId: editLocalId,
                  localNome: editLocalNome,
                  nome: editNome,
                  validade: editValidade,
                  quantidade: qty,
                  situacao: editSituacao,
                  status: editSituacao == 'Vencido' ? editStatus : '',
                ));
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enviarEmail() async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final futureDate = todayStart.add(const Duration(days: 4));

    final itens = _produtos.where((p) {
      final d = du.parseDate(p.validade);
      return d != null && !d.isBefore(todayStart) && !d.isAfter(futureDate);
    }).toList()
      ..sort((a, b) => a.localNome.compareTo(b.localNome));

    if (itens.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum produto com vencimento nos proximos 4 dias.')));
      }
      return;
    }

    var body = 'Produtos proximos ao vencimento:\n\n';
    body += 'Local | Qtd | Produto | Validade | Situacao | Status\n';
    body += '------|-----|---------|----------|----------|-------\n';
    for (final p in itens) {
      body += '${p.localNome} | ${p.quantidade} | ${p.nome} | ${p.validade} | ${p.situacao.isEmpty ? '-' : p.situacao} | ${p.status.isEmpty ? '-' : p.status}\n';
    }

    final subject = 'Controle de Validades - Produtos proximos ao vencimento (${du.formatDate(todayStart)})';
    final uri = Uri(scheme: 'mailto', queryParameters: {'subject': subject, 'body': body});
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Servico de email nao disponivel.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final sorted = _sorted;
    final localLabel = _filtrosLocal.isEmpty
        ? 'Todos'
        : _filtrosLocal.length <= 2
            ? _filtrosLocal.join(', ')
            : '${_filtrosLocal.length} selecionados';

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          // Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Local:', style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
                          const SizedBox(height: 2),
                          GestureDetector(
                            onTap: () => _showLocalFilterSheet(),
                            child: Container(
                              width: double.infinity,
                              height: 34,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFCCCCCC)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(localLabel, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Dias:', style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 34,
                            child: TextField(
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: '4',
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              ),
                              onChanged: (v) => setState(() => _diasFiltro = v),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Data Inicial:', style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 34,
                            child: TextField(
                              controller: _dataInicialCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 10,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'DD/MM/AAAA',
                                counterText: '',
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              ),
                              onChanged: (v) {
                                final masked = du.applyDateMask(v);
                                if (masked != v) {
                                  _dataInicialCtrl.text = masked;
                                  _dataInicialCtrl.selection = TextSelection.fromPosition(TextPosition(offset: masked.length));
                                }
                                setState(() => _dataInicial = masked);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Data Final:', style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 34,
                            child: TextField(
                              controller: _dataFinalCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 10,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'DD/MM/AAAA',
                                counterText: '',
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              ),
                              onChanged: (v) {
                                final masked = du.applyDateMask(v);
                                if (masked != v) {
                                  _dataFinalCtrl.text = masked;
                                  _dataFinalCtrl.selection = TextSelection.fromPosition(TextPosition(offset: masked.length));
                                }
                                setState(() => _dataFinal = masked);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Table
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kPrimaryColor),
                color: Colors.white,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    color: kPrimaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Row(
                      children: [
                        _headerCell('Local${_sortArrow('local')}', 3, () => _toggleSort('local')),
                        _headerCell('Qtd${_sortArrow('qtd')}', 1, () => _toggleSort('qtd')),
                        _headerCell('Produto${_sortArrow('produto')}', 4, () => _toggleSort('produto')),
                        _headerCell('Data${_sortArrow('validade')}', 2, () => _toggleSort('validade'), align: TextAlign.right),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: kPrimaryColor),
                                SizedBox(height: 12),
                                Text('Carregando...', style: TextStyle(color: Color(0xFF999999))),
                              ],
                            ),
                          )
                        : sorted.isEmpty
                        ? const Center(child: Text('Nenhum produto encontrado', style: TextStyle(color: Color(0xFF999999))))
                        : ListView.builder(
                            itemCount: sorted.length,
                            itemBuilder: (_, i) {
                              final item = sorted[i];
                              return InkWell(
                                onTap: () => _openEditModal(item),
                                child: Container(
                                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))),
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                  child: Row(
                                    children: [
                                      Expanded(flex: 3, child: Text(item.localNome, style: const TextStyle(fontSize: 11))),
                                      Expanded(flex: 1, child: Text('${item.quantidade}', style: const TextStyle(fontSize: 11))),
                                      Expanded(flex: 4, child: Text(item.nome, style: const TextStyle(fontSize: 11))),
                                      Expanded(flex: 2, child: Text(du.formatShort(item.validade), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          // Email button
          Padding(
            padding: const EdgeInsets.only(right: 12, bottom: 5),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, foregroundColor: Colors.white, minimumSize: const Size(170, 40)),
                onPressed: _enviarEmail,
                child: const Text('Enviar por Email', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String text, int flex, VoidCallback onTap, {TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(text, textAlign: align, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
      ),
    );
  }

  void _showLocalFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Checkbox(
                value: _filtrosLocal.isEmpty,
                onChanged: (_) {
                  setState(() => _filtrosLocal.clear());
                  setSheetState(() {});
                },
              ),
              title: const Text('Todos'),
              onTap: () {
                setState(() => _filtrosLocal.clear());
                setSheetState(() {});
              },
            ),
            ..._locais.where((l) => l.ativo).map((l) {
              final sel = _filtrosLocal.contains(l.nome);
              return ListTile(
                leading: Checkbox(
                  value: sel,
                  activeColor: kPrimaryColor,
                  onChanged: (_) {
                    _toggleLocalFilter(l.nome);
                    setSheetState(() {});
                  },
                ),
                title: Text(l.nome, style: sel ? const TextStyle(color: Color(0xFF4A8A1A), fontWeight: FontWeight.bold) : null),
                onTap: () {
                  _toggleLocalFilter(l.nome);
                  setSheetState(() {});
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dataInicialCtrl.dispose();
    _dataFinalCtrl.dispose();
    super.dispose();
  }
}
