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
  ({int ano, int mes})? _selecionado;

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
      if (_selecionado == null || !periodos.contains(_selecionado)) {
        _selecionado = periodos.isNotEmpty ? periodos.first : null;
      }
    });
  }

  String _labelPeriodo(({int ano, int mes}) p) =>
      '${_nomesMeses[p.mes - 1]}/${p.ano}';

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
    final sel = _selecionado;
    if (sel == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text(
          'Deseja apagar os produtos com validade em ${_labelPeriodo(sel)}? '
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
              final n = await _controller.apagarPeriodo(sel.ano, sel.mes);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      n > 0
                          ? '$n produto(s) de ${_labelPeriodo(sel)} apagado(s).'
                          : 'Nenhum produto em ${_labelPeriodo(sel)}.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Apagar Periodo'),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<({int ano, int mes})>(
                      isExpanded: true,
                      value: _selecionado,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: AppColors.primary,
                      ),
                      items: [
                        for (final p in _periodos)
                          DropdownMenuItem(
                            value: p,
                            child: Text(
                              _labelPeriodo(p),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textHeading,
                              ),
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _selecionado = v),
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
