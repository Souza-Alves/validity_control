import 'package:flutter/material.dart';
import '../controllers/configuracao_controller.dart';
import '../storage/storage.dart' as storage;
import '../theme/app_colors.dart';

class ConfiguracaoScreen extends StatefulWidget {
  const ConfiguracaoScreen({super.key});

  @override
  State<ConfiguracaoScreen> createState() => _ConfiguracaoScreenState();
}

class _ConfiguracaoScreenState extends State<ConfiguracaoScreen> {
  static const _controller = ConfiguracaoController();

  static const _nomesMeses = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  List<({int ano, int mes})> _periodos = [];
  final Set<({int ano, int mes})> _selecionados = {};

  @override
  void initState() {
    super.initState();
    _carregarPeriodos();
    storage.dataChanged.addListener(_carregarPeriodos);
  }

  @override
  void dispose() {
    storage.dataChanged.removeListener(_carregarPeriodos);
    super.dispose();
  }

  Future<void> _carregarPeriodos() async {
    final periodos = await _controller.periodosDisponiveis();
    if (!mounted) return;
    setState(() {
      _periodos = periodos;
      _selecionados.removeWhere((p) => !periodos.contains(p));
      if (_selecionados.isEmpty && periodos.isNotEmpty) {
        _selecionados.add(periodos.first);
      }
    });
  }

  String _labelPeriodo(({int ano, int mes}) p) =>
      '${_nomesMeses[p.mes - 1]}/${p.ano}';

  void _togglePeriodo(({int ano, int mes}) p) {
    setState(() {
      if (_selecionados.contains(p)) {
        _selecionados.remove(p);
      } else {
        _selecionados.add(p);
      }
    });
  }

  String get _selecionadosLabel {
    if (_selecionados.isEmpty) return 'Selecione';
    if (_selecionados.length == 1) {
      return _labelPeriodo(_selecionados.first);
    }
    if (_selecionados.length == _periodos.length) return 'Todos';
    return '${_selecionados.length} selecionados';
  }

  Future<void> _showPeriodoSelector() async {
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
                    'Selecionar períodos',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      for (final p in _periodos)
                        ListTile(
                          leading: Checkbox(
                            value: _selecionados.contains(p),
                            onChanged: (_) {
                              _togglePeriodo(p);
                              setSheetState(() {});
                            },
                          ),
                          title: Text(_labelPeriodo(p)),
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

  void _handleClearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: const Text(
          'Deseja apagar TODOS os dados (locais e produtos)? Esta acao nao pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              await _controller.clearAll();
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Todos os dados foram apagados.'),
                  ),
                );
              }
            },
            child: const Text('Apagar Tudo'),
          ),
        ],
      ),
    );
  }

  void _handleClearPeriodo() {
    if (_selecionados.isEmpty) return;
    final periodos = _selecionados.toList()
      ..sort((a, b) {
        final y = a.ano.compareTo(b.ano);
        return y != 0 ? y : a.mes.compareTo(b.mes);
      });
    final textoPeriodos = periodos.map(_labelPeriodo).join(', ');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text(
          'Deseja apagar os produtos com validade em $textoPeriodos? '
          'Esta acao nao pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              final n = await _controller.apagarPeriodos(periodos);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      n > 0
                          ? '$n produto(s) apagado(s).'
                          : 'Nenhum produto nos períodos selecionados.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Apagar Períodos'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Configuracoes',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textHeading,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Gerencie os dados do aplicativo.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 16),

              // ===== Apagar por período =====
              const Text(
                'Apagar por Mês/Ano',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHeading,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Apaga apenas os produtos com validade no período selecionado.',
                style: TextStyle(fontSize: 13, color: AppColors.neutralButton),
              ),
              const SizedBox(height: 12),
              if (_periodos.isEmpty)
                const Text(
                  'Nenhum período disponível.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                )
              else ...[
                GestureDetector(
                  onTap: _showPeriodoSelector,
                  child: Container(
                    width: double.infinity,
                    height: 42,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selecionadosLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textHeading,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.offline,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _handleClearPeriodo,
                    child: const Text(
                      'Apagar Dados do Período',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 16),
              const Text(
                'Dados',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHeading,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Apagar toda a base de dados incluindo locais e produtos cadastrados.',
                style: TextStyle(fontSize: 13, color: AppColors.neutralButton),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _handleClearAll,
                  child: const Text(
                    'Apagar Toda a Base',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
