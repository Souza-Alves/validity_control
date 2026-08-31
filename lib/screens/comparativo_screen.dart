import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../controllers/relatorio_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/loading_indicator.dart';

enum _ComparativoTipo { vencidos, vendidos, geral }

/// Relatório comparativo: o usuário escolhe vários meses/anos e vê
/// a quantidade de vencidos, vendidos ou total de produtos por local em cada
/// período (Local × Qtd por período).
class ComparativoScreen extends StatefulWidget {
  const ComparativoScreen({super.key});

  @override
  State<ComparativoScreen> createState() => _ComparativoScreenState();
}

class _ComparativoScreenState extends State<ComparativoScreen>
    with AutomaticKeepAliveClientMixin {
  late final RelatorioController _c;
  final Set<_ComparativoTipo> _tiposSelecionados = {_ComparativoTipo.vencidos};
  final Set<Periodo> _selecionados = {};
  bool _inicializado = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _c = RelatorioController()..addListener(_onControllerChanged);
    _c.load();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (!_inicializado) {
      final disp = _c.periodosDisponiveis;
      if (disp.isNotEmpty) {
        _selecionados.addAll(disp.take(2));
        _inicializado = true;
      }
    }
    _selecionados.removeWhere((p) => !_c.periodosDisponiveis.contains(p));
    setState(() {});
  }

  Future<void> refresh() async {
    await _c.load();
  }

  @override
  void dispose() {
    _c.removeListener(_onControllerChanged);
    _c.dispose();
    super.dispose();
  }

  void _togglePeriodo(Periodo p) {
    if (!_selecionados.contains(p) && _selecionados.length >= 3) {
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selecione no máximo 3 meses para comparar.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      });
      return;
    }
    setState(() {
      if (_selecionados.contains(p)) {
        _selecionados.remove(p);
      } else {
        _selecionados.add(p);
      }
    });
  }

  void _toggleTipo(_ComparativoTipo t) {
    setState(() {
      if (_tiposSelecionados.contains(t)) {
        if (_tiposSelecionados.length > 1) _tiposSelecionados.remove(t);
      } else {
        _tiposSelecionados.add(t);
      }
    });
  }

  String get _titulo => 'Comparativo';

  String get _mensagemVazio {
    if (_tiposSelecionados.length == 1) {
      final t = _tiposSelecionados.first;
      switch (t) {
        case _ComparativoTipo.vencidos:
          return 'Nenhum vencido nos períodos selecionados.';
        case _ComparativoTipo.vendidos:
          return 'Nenhum vendido nos períodos selecionados.';
        case _ComparativoTipo.geral:
          return 'Nenhum produto nos períodos selecionados.';
      }
    }
    return 'Nenhum dado nos períodos selecionados.';
  }

  String _labelTipo(_ComparativoTipo t) {
    switch (t) {
      case _ComparativoTipo.vencidos:
        return 'Vencidos';
      case _ComparativoTipo.vendidos:
        return 'Vendidos';
      case _ComparativoTipo.geral:
        return 'Geral';
    }
  }

  String get _tipoLabel {
    if (_tiposSelecionados.isEmpty) return 'Selecione';
    if (_tiposSelecionados.length == 1) {
      return _labelTipo(_tiposSelecionados.first);
    }
    if (_tiposSelecionados.length == _ComparativoTipo.values.length) {
      return 'Todos';
    }
    return '${_tiposSelecionados.length} selecionados';
  }

  String get _periodoLabel {
    if (_selecionados.isEmpty) return 'Selecione';
    if (_selecionados.length == 1) return _selecionados.first.label;
    if (_selecionados.length == _c.periodosDisponiveis.length) return 'Todos';
    return '${_selecionados.length} selecionados';
  }

  Future<void> _showTipoFilterSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text(
                    'Filtrar por tipo',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final t in _ComparativoTipo.values)
                        ListTile(
                          leading: Checkbox(
                            value: _tiposSelecionados.contains(t),
                            onChanged: (_) {
                              _toggleTipo(t);
                              setSheetState(() {});
                            },
                          ),
                          title: Text(_labelTipo(t)),
                          onTap: () {
                            _toggleTipo(t);
                            setSheetState(() {});
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPeriodoFilterSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text(
                    'Filtrar por período',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      ListTile(
                        leading: Checkbox(
                          value: _selecionados.isEmpty,
                          onChanged: (_) {
                            setState(() => _selecionados.clear());
                            setSheetState(() {});
                          },
                        ),
                        title: const Text('Nenhum'),
                        onTap: () {
                          setState(() => _selecionados.clear());
                          setSheetState(() {});
                        },
                      ),
                      for (final p in _c.periodosDisponiveis)
                        ListTile(
                          leading: Checkbox(
                            value: _selecionados.contains(p),
                            onChanged: (_) {
                              _togglePeriodo(p);
                              setSheetState(() {});
                            },
                          ),
                          title: Text(p.label),
                          onTap: () {
                            _togglePeriodo(p);
                            setSheetState(() {});
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_c.loading) return const LoadingIndicator();

    final disponiveis = _c.periodosDisponiveis;
    final colunas = _selecionados.toList()
      ..sort((a, b) {
        final y = a.ano.compareTo(b.ano);
        return y != 0 ? y : a.mes.compareTo(b.mes);
      });

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textHeading,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Selecione os tipos e meses/anos que deseja comparar',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tipo:',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: _showTipoFilterSheet,
                        child: Container(
                          width: double.infinity,
                          height: 34,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _tipoLabel,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                      const Text(
                        'Período:',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: _showPeriodoFilterSheet,
                        child: Container(
                          width: double.infinity,
                          height: 34,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _periodoLabel,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (disponiveis.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Text(
                  'Nenhum produto para exibir',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            else if (colunas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'Selecione ao menos um período acima.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            else ...[
              _CollapsibleCard(
                titulo: 'Total por mês',
                subtitulo: 'Geral',
                icon: Icons.summarize,
                headerColor: AppColors.primaryDark,
                child: _ComparativoGeralChart(
                  controller: _c,
                  colunas: colunas,
                ),
              ),
              const SizedBox(height: 12),
              _CollapsibleCard(
                titulo: 'Geral',
                subtitulo: 'Por local',
                icon: Icons.location_on,
                headerColor: AppColors.primary,
                child: _ComparativoChart(
                  controller: _c,
                  colunas: colunas,
                  tipos: const {_ComparativoTipo.geral},
                ),
              ),
              const SizedBox(height: 12),
              _CollapsibleCard(
                titulo: 'Vendidos',
                subtitulo: 'Por local',
                icon: Icons.shopping_cart,
                headerColor: AppColors.primary,
                child: _ComparativoChart(
                  controller: _c,
                  colunas: colunas,
                  tipos: const {_ComparativoTipo.vendidos},
                ),
              ),
              const SizedBox(height: 12),
              _CollapsibleCard(
                titulo: 'Vencidos',
                subtitulo: 'Por local',
                icon: Icons.warning,
                headerColor: AppColors.danger,
                child: _ComparativoChart(
                  controller: _c,
                  colunas: colunas,
                  tipos: const {_ComparativoTipo.vencidos},
                ),
              ),
              const SizedBox(height: 12),
              _ComparativoTable(
                controller: _c,
                colunas: colunas,
                tipos: _tiposSelecionados,
                mensagemVazio: _mensagemVazio,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComparativoChart extends StatelessWidget {
  final RelatorioController controller;
  final List<Periodo> colunas;
  final Set<_ComparativoTipo> tipos;

  const _ComparativoChart({
    required this.controller,
    required this.colunas,
    required this.tipos,
  });

  static const _cores = [
    AppColors.primary,
    AppColors.offline,
    AppColors.danger,
    Colors.blue,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
  ];

  int _valor(String localNome, Periodo periodo) {
    var total = 0;
    for (final t in tipos) {
      switch (t) {
        case _ComparativoTipo.vencidos:
          total += controller.vencidosNoPeriodo(localNome, periodo);
        case _ComparativoTipo.vendidos:
          total += controller.vendidosNoPeriodo(localNome, periodo);
        case _ComparativoTipo.geral:
          total += controller.totalNoPeriodo(localNome, periodo);
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final locais = controller.nomesLocais;
    final linhas = <String>[];
    final dadosPorLocal = <String, Map<Periodo, int>>{};

    for (final nome in locais) {
      final row = <Periodo, int>{};
      var somaLocal = 0;
      for (final p in colunas) {
        final v = _valor(nome, p);
        row[p] = v;
        somaLocal += v;
      }
      if (somaLocal > 0) {
        linhas.add(nome);
        dadosPorLocal[nome] = row;
      }
    }

    if (linhas.isEmpty) return const SizedBox.shrink();

    final maxY = dadosPorLocal.values
        .expand((m) => m.values)
        .fold<int>(0, (m, v) => v > m ? v : m)
        .toDouble();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxY == 0 ? 1 : maxY * 1.1,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    fitInsideVertically: true,
                    fitInsideHorizontally: true,
                    getTooltipColor: (_) => AppColors.textHeading.withAlpha(230),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final local = linhas[group.x];
                      final periodo = colunas[rodIndex].label;
                      return BarTooltipItem(
                        '$local\n$periodo: ${rod.toY.toInt()}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= linhas.length) {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          width: 64,
                          alignment: Alignment.topCenter,
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            linhas[i],
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                            softWrap: true,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: maxY <= 20
                          ? 1
                          : maxY <= 50
                          ? 5
                          : 10,
                      minIncluded: true,
                      maxIncluded: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY <= 20
                      ? 1
                      : maxY <= 50
                      ? 5
                      : 10,
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  for (var i = 0; i < linhas.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        for (var j = 0; j < colunas.length; j++)
                          BarChartRodData(
                            toY:
                                (dadosPorLocal[linhas[i]]![colunas[j]] ?? 0)
                                    .toDouble(),
                            color: _cores[j % _cores.length],
                            width: 10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.start,
            children: [
              for (var j = 0; j < colunas.length; j++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _cores[j % _cores.length],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      colunas[j].label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _CollapsibleCard extends StatefulWidget {
  final String titulo;
  final String subtitulo;
  final IconData icon;
  final Color headerColor;
  final Widget child;

  const _CollapsibleCard({
    required this.titulo,
    required this.subtitulo,
    required this.icon,
    required this.headerColor,
    required this.child,
  });

  @override
  State<_CollapsibleCard> createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<_CollapsibleCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
  }

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _toggle,
            child: Container(
              color: widget.headerColor,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: Row(
                children: [
                  Icon(widget.icon, color: AppColors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.titulo,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    widget.subtitulo,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.white,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.all(12),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

class _ComparativoGeralChart extends StatelessWidget {
  final RelatorioController controller;
  final List<Periodo> colunas;

  const _ComparativoGeralChart({
    required this.controller,
    required this.colunas,
  });

  @override
  Widget build(BuildContext context) {
    if (colunas.isEmpty) return const SizedBox.shrink();

    final totais = <Periodo, int>{};
    for (final p in colunas) {
      var total = 0;
      for (final local in controller.nomesLocais) {
        total += controller.totalNoPeriodo(local, p);
      }
      totais[p] = total;
    }

    final maxValor = totais.values.fold<int>(0, (m, v) => v > m ? v : m);
    final yInterval = maxValor <= 50
        ? 10
        : maxValor <= 100
        ? 20
        : maxValor <= 500
        ? 50
        : maxValor <= 1000
        ? 100
        : 200;
    final maxY = maxValor == 0
        ? 1.0
        : ((maxValor / yInterval).ceil() * yInterval).toDouble();

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              fitInsideVertically: true,
              fitInsideHorizontally: true,
              getTooltipColor: (_) => AppColors.textHeading.withAlpha(230),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final periodo = colunas[group.x].label;
                return BarTooltipItem(
                  '$periodo\nTotal: ${rod.toY.toInt()}',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= colunas.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      colunas[i].label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                interval: yInterval.toDouble(),
                minIncluded: true,
                maxIncluded: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yInterval.toDouble(),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var i = 0; i < colunas.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: (totais[colunas[i]] ?? 0).toDouble(),
                    color: AppColors.primary,
                    width: 24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ComparativoTable extends StatelessWidget {
  final RelatorioController controller;
  final List<Periodo> colunas;
  final Set<_ComparativoTipo> tipos;
  final String mensagemVazio;

  const _ComparativoTable({
    required this.controller,
    required this.colunas,
    required this.tipos,
    required this.mensagemVazio,
  });

  int _valor(String localNome, Periodo periodo) {
    var total = 0;
    for (final t in tipos) {
      switch (t) {
        case _ComparativoTipo.vencidos:
          total += controller.vencidosNoPeriodo(localNome, periodo);
        case _ComparativoTipo.vendidos:
          total += controller.vendidosNoPeriodo(localNome, periodo);
        case _ComparativoTipo.geral:
          total += controller.totalNoPeriodo(localNome, periodo);
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final locais = controller.nomesLocais;

    final linhas = <String>[];
    final totalPorColuna = <Periodo, int>{for (final p in colunas) p: 0};
    final dadosPorLocal = <String, Map<Periodo, int>>{};

    for (final nome in locais) {
      final row = <Periodo, int>{};
      var somaLocal = 0;
      for (final p in colunas) {
        final v = _valor(nome, p);
        row[p] = v;
        somaLocal += v;
        totalPorColuna[p] = totalPorColuna[p]! + v;
      }
      if (somaLocal > 0) {
        linhas.add(nome);
        dadosPorLocal[nome] = row;
      }
    }

    if (linhas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(
          mensagemVazio,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    const headerStyle = TextStyle(
      color: AppColors.white,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.primary),
                headingRowHeight: 44,
                dataRowMinHeight: 38,
                dataRowMaxHeight: 44,
                columnSpacing: 20,
                horizontalMargin: 12,
                columns: [
                  const DataColumn(label: Text('Local', style: headerStyle)),
                  for (final p in colunas)
                    DataColumn(
                      label: Text(p.label, style: headerStyle),
                      numeric: true,
                    ),
                ],
                rows: [
                  for (final nome in linhas)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            nome,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        for (final p in colunas)
                          DataCell(
                            Text(
                              '${dadosPorLocal[nome]![p]}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  DataRow(
                    color: WidgetStateProperty.all(AppColors.background),
                    cells: [
                      const DataCell(
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      for (final p in colunas)
                        DataCell(
                          Text(
                            '${totalPorColuna[p]}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
