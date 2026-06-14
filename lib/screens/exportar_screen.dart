import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/produto.dart';
import '../models/local.dart';
import '../storage/storage.dart';
import '../utils/date_utils.dart' as du;
import '../main.dart' show kPrimaryColor;

class ExportarScreen extends StatefulWidget {
  const ExportarScreen({super.key});

  @override
  State<ExportarScreen> createState() => _ExportarScreenState();
}

class _ExportarScreenState extends State<ExportarScreen> {
  List<Produto> _produtos = [];
  List<Local> _locais = [];
  final List<String> _filtrosLocal = [];
  String _filtroCondicao = '';
  String _filtroStatus = '';
  String _periodoInicio = '';
  String _periodoFim = '';
  String _sortField = 'validade';
  bool _sortAsc = true;
  final _periodoInicioCtrl = TextEditingController();
  final _periodoFimCtrl = TextEditingController();

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

  @override
  void dispose() {
    _periodoInicioCtrl.dispose();
    _periodoFimCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prods = await getProdutos();
    final locs = await getLocais();
    if (mounted) setState(() { _produtos = prods; _locais = locs; });
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
      if (_filtroCondicao.isNotEmpty && p.situacao != _filtroCondicao) return false;
      if (_filtroCondicao == 'Vencido' && _filtroStatus.isNotEmpty && p.status != _filtroStatus) return false;
      if (_periodoInicio.isNotEmpty && _periodoFim.isNotEmpty) {
        final d = du.parseDate(p.validade);
        final start = du.parseDate(_periodoInicio);
        final end = du.parseDate(_periodoFim);
        if (d != null && start != null && end != null) {
          if (d.isBefore(start) || d.isAfter(end)) return false;
        }
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
        case 'situacao':
          cmp = a.situacao.compareTo(b.situacao);
        case 'status':
          cmp = a.status.compareTo(b.status);
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

  Future<void> _handleExport() async {
    final sorted = _sorted;
    if (sorted.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum produto para enviar com os filtros aplicados.')));
      return;
    }
    final today = DateTime.now();
    var body = 'Relatorio de Produtos - Controle de Validades\n\n';
    body += 'Local | Qtd | Produto | Validade | Situacao | Status\n';
    body += '------|-----|---------|----------|----------|-------\n';
    for (final p in sorted) {
      body += '${p.localNome} | ${p.quantidade} | ${p.nome} | ${p.validade} | ${p.situacao.isEmpty ? '-' : p.situacao} | ${p.status.isEmpty ? '-' : p.status}\n';
    }
    body += '\nTotal: ${sorted.length} produto(s)';

    final subject = 'Controle de Validades - Relatorio (${du.formatDate(today)})';
    final uri = Uri(scheme: 'mailto', queryParameters: {'subject': subject, 'body': body});
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Servico de email nao disponivel.')));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCCCCCC)), borderRadius: BorderRadius.circular(6)),
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
                          const Text('Condicao:', style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 34,
                            child: DropdownButtonFormField<String>(
                              initialValue: _filtroCondicao.isEmpty ? null : _filtroCondicao,
                              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), isDense: true),
                              hint: const Text('Todos', style: TextStyle(fontSize: 14)),
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: '', child: Text('Todos')),
                                DropdownMenuItem(value: 'Vendido', child: Text('Vendido')),
                                DropdownMenuItem(value: 'Vencido', child: Text('Vencido')),
                              ],
                              onChanged: (v) => setState(() {
                                _filtroCondicao = v ?? '';
                                if (_filtroCondicao != 'Vencido') _filtroStatus = '';
                              }),
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
                          const Text('Status:', style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 34,
                            child: DropdownButtonFormField<String>(
                              initialValue: _filtroStatus.isEmpty ? null : _filtroStatus,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                isDense: true,
                                enabled: _filtroCondicao == 'Vencido',
                              ),
                              hint: Text(
                                _filtroCondicao == 'Vencido' ? 'Todos' : 'Apenas Vencido',
                                style: TextStyle(fontSize: 12, color: _filtroCondicao == 'Vencido' ? null : const Color(0xFFBBBBBB)),
                              ),
                              isExpanded: true,
                              items: _filtroCondicao == 'Vencido'
                                  ? const [
                                      DropdownMenuItem(value: '', child: Text('Todos')),
                                      DropdownMenuItem(value: 'Baixado', child: Text('Baixado')),
                                      DropdownMenuItem(value: 'Pendente', child: Text('Pendente')),
                                    ]
                                  : null,
                              onChanged: _filtroCondicao == 'Vencido' ? (v) => setState(() => _filtroStatus = v ?? '') : null,
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
                          const Text('Periodo Inicio:', style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 34,
                            child: TextField(
                              controller: _periodoInicioCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 10,
                              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'DD/MM/AAAA', counterText: '', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                              onChanged: (v) {
                                final masked = du.applyDateMask(v);
                                if (masked != v) {
                                  _periodoInicioCtrl.text = masked;
                                  _periodoInicioCtrl.selection = TextSelection.fromPosition(TextPosition(offset: masked.length));
                                }
                                setState(() => _periodoInicio = masked);
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
                          const Text('Periodo Fim:', style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 34,
                            child: TextField(
                              controller: _periodoFimCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 10,
                              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'DD/MM/AAAA', counterText: '', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                              onChanged: (v) {
                                final masked = du.applyDateMask(v);
                                if (masked != v) {
                                  _periodoFimCtrl.text = masked;
                                  _periodoFimCtrl.selection = TextSelection.fromPosition(TextPosition(offset: masked.length));
                                }
                                setState(() => _periodoFim = masked);
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
          // Table with sticky header
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
                        _headerCell('Local${_sortArrow('local')}', 2, () => _toggleSort('local')),
                        _headerCell('Qtd${_sortArrow('qtd')}', 1, () => _toggleSort('qtd')),
                        _headerCell('Produto${_sortArrow('produto')}', 3, () => _toggleSort('produto')),
                        _headerCell('Data${_sortArrow('validade')}', 2, () => _toggleSort('validade')),
                        _headerCell('Situação${_sortArrow('situacao')}', 2, () => _toggleSort('situacao')),
                        _headerCell('Status${_sortArrow('status')}', 2, () => _toggleSort('status')),
                      ],
                    ),
                  ),
                  Expanded(
                    child: sorted.isEmpty
                        ? const Center(child: Text('Nenhum produto encontrado', style: TextStyle(color: Color(0xFF999999))))
                        : ListView.builder(
                            itemCount: sorted.length,
                            itemBuilder: (_, i) {
                              final item = sorted[i];
                              return Container(
                                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))),
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                child: Row(
                                  children: [
                                    Expanded(flex: 2, child: Text(item.localNome, style: const TextStyle(fontSize: 11))),
                                    Expanded(flex: 1, child: Text('${item.quantidade}', style: const TextStyle(fontSize: 11))),
                                    Expanded(flex: 3, child: Text(item.nome, style: const TextStyle(fontSize: 11))),
                                    Expanded(flex: 2, child: Text(du.formatShort(item.validade), style: const TextStyle(fontSize: 11), maxLines: 1, softWrap: false, overflow: TextOverflow.visible)),
                                    Expanded(flex: 2, child: Text(item.situacao.isEmpty ? '-' : item.situacao, style: const TextStyle(fontSize: 11))),
                                    Expanded(flex: 2, child: Text(item.status.isEmpty ? '-' : item.status, style: const TextStyle(fontSize: 11))),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          // Email button outside table
          Padding(
            padding: const EdgeInsets.only(right: 12, bottom: 5),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, foregroundColor: Colors.white, minimumSize: const Size(170, 40)),
                onPressed: _handleExport,
                child: const Text('Enviar por Email', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String text, int flex, VoidCallback onTap) {
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
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
                onChanged: (_) { setState(() => _filtrosLocal.clear()); setSheetState(() {}); },
              ),
              title: const Text('Todos'),
              onTap: () { setState(() => _filtrosLocal.clear()); setSheetState(() {}); },
            ),
            ..._locais.where((l) => l.ativo).map((l) {
              final sel = _filtrosLocal.contains(l.nome);
              return ListTile(
                leading: Checkbox(value: sel, activeColor: kPrimaryColor, onChanged: (_) { _toggleLocalFilter(l.nome); setSheetState(() {}); }),
                title: Text(l.nome, style: sel ? const TextStyle(color: Color(0xFF4A8A1A), fontWeight: FontWeight.bold) : null),
                onTap: () { _toggleLocalFilter(l.nome); setSheetState(() {}); },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
