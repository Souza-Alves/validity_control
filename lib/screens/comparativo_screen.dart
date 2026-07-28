import 'package:flutter/material.dart';
import '../controllers/relatorio_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/loading_indicator.dart';

/// Relatório comparativo de vencidos: o usuário escolhe vários meses/anos e vê
/// a quantidade de vencidos por local em cada período (Local × Qtd por período).
class ComparativoScreen extends StatefulWidget {
  const ComparativoScreen({super.key});

  @override
  State<ComparativoScreen> createState() => _ComparativoScreenState();
}

class _ComparativoScreenState extends State<ComparativoScreen>
    with AutomaticKeepAliveClientMixin {
  late final RelatorioController _c;
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
    // Ao carregar os dados pela primeira vez, seleciona os 2 períodos mais
    // recentes para já mostrar uma comparação.
    if (!_inicializado) {
      final disp = _c.periodosDisponiveis;
      if (disp.isNotEmpty) {
        _selecionados.addAll(disp.take(2));
        _inicializado = true;
      }
    }
    // Remove seleções que não existem mais nos dados.
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

  void _toggle(Periodo p) {
    setState(() {
      if (_selecionados.contains(p)) {
        _selecionados.remove(p);
      } else {
        _selecionados.add(p);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_c.loading) return const LoadingIndicator();

    final disponiveis = _c.periodosDisponiveis;
    // Ordena os períodos escolhidos (mais antigos primeiro) para as colunas.
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
            const Text(
              'Comparativo de Vencidos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textHeading,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Selecione os meses/anos que deseja comparar',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            if (disponiveis.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Text(
                  'Nenhum produto para exibir',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final p in disponiveis)
                    FilterChip(
                      label: Text(p.label),
                      selected: _selecionados.contains(p),
                      onSelected: (_) => _toggle(p),
                      selectedColor: AppColors.primary,
                      checkmarkColor: AppColors.white,
                      labelStyle: TextStyle(
                        color: _selecionados.contains(p)
                            ? AppColors.white
                            : AppColors.textHeading,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      backgroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (colunas.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Selecione ao menos um período acima.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              else
                _ComparativoTable(controller: _c, colunas: colunas),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComparativoTable extends StatelessWidget {
  final RelatorioController controller;
  final List<Periodo> colunas;

  const _ComparativoTable({required this.controller, required this.colunas});

  @override
  Widget build(BuildContext context) {
    final locais = controller.nomesLocais;

    // Só exibe locais com ao menos um vencido nos períodos escolhidos.
    final linhas = <String>[];
    final totalPorColuna = <Periodo, int>{for (final p in colunas) p: 0};
    var totalGeral = 0;
    final dadosPorLocal = <String, Map<Periodo, int>>{};

    for (final nome in locais) {
      final row = <Periodo, int>{};
      var somaLocal = 0;
      for (final p in colunas) {
        final v = controller.vencidosNoPeriodo(nome, p);
        row[p] = v;
        somaLocal += v;
        totalPorColuna[p] = totalPorColuna[p]! + v;
      }
      if (somaLocal > 0) {
        linhas.add(nome);
        dadosPorLocal[nome] = row;
        totalGeral += somaLocal;
      }
    }

    if (linhas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Text(
          'Nenhum vencido nos períodos selecionados.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted),
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
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
            const DataColumn(label: Text('Total', style: headerStyle)),
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
                  DataCell(
                    Text(
                      '${dadosPorLocal[nome]!.values.fold<int>(0, (s, v) => s + v)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
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
                DataCell(
                  Text(
                    '$totalGeral',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
