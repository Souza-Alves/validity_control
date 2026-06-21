import 'package:flutter/material.dart';
import '../controllers/relatorio_controller.dart';
import '../models/produto.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart' as du;
import '../widgets/loading_indicator.dart';

class RelatorioScreen extends StatefulWidget {
  const RelatorioScreen({super.key});

  @override
  State<RelatorioScreen> createState() => _RelatorioScreenState();
}

class _RelatorioScreenState extends State<RelatorioScreen>
    with AutomaticKeepAliveClientMixin {
  late final RelatorioController _c;

  static const _meses = [
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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _c = RelatorioController()..addListener(_onControllerChanged);
    _c.load();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> refresh() async {
    await _c.load();
  }

  static String _categoriaLabel(RelatorioCategoria cat) {
    switch (cat) {
      case RelatorioCategoria.total:
        return 'Total Geral de Produtos';
      case RelatorioCategoria.vendidos:
        return 'Vendidos';
      case RelatorioCategoria.pendentes:
        return 'Pendentes';
      case RelatorioCategoria.baixados:
        return 'Baixados';
    }
  }

  void _showItens(String localNome, RelatorioCategoria cat) {
    final itens = _c.itens(localNome, cat);
    final totalQtd = itens.fold<int>(0, (s, p) => s + p.quantidade);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  width: double.infinity,
                  color: AppColors.primary,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localNome,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_categoriaLabel(cat)}  •  $totalQtd produto(s)',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: itens.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhum produto nesta categoria',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: itens.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            color: AppColors.divider,
                          ),
                          itemBuilder: (_, i) => _ItemTile(produto: itens[i]),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _c.removeListener(_onControllerChanged);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final mesAtual = _meses[DateTime.now().month - 1];

    if (_c.loading) {
      return const LoadingIndicator();
    }

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
              'Relatório de Produtos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textHeading,
              ),
            ),
            const SizedBox(height: 8),
            _MesHeader(mes: mesAtual),
            const SizedBox(height: 16),
            if (_c.resumos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Text(
                  'Nenhum produto para exibir',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 12.0;
                  final twoCols = constraints.maxWidth >= 560;
                  final cardWidth = twoCols
                      ? (constraints.maxWidth - spacing) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (final r in _c.resumos)
                        SizedBox(
                          width: cardWidth,
                          child: _LocalCard(
                            resumo: r,
                            onTap: (cat) => _showItens(r.nome, cat),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _MesHeader extends StatelessWidget {
  final String mes;
  const _MesHeader({required this.mes});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Expanded(child: Divider(color: AppColors.primary, thickness: 2)),
        const SizedBox(width: 8),
        const Icon(Icons.calendar_month, color: AppColors.primary, size: 28),
        const SizedBox(width: 8),
        Text(
          mes,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.calendar_month, color: AppColors.primary, size: 28),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: AppColors.primary, thickness: 2)),
      ],
    );
  }
}

class _LocalCard extends StatelessWidget {
  final LocalResumo resumo;
  final void Function(RelatorioCategoria) onTap;
  const _LocalCard({required this.resumo, required this.onTap});

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
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    resumo.nome,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      const Text(
                        'Total Geral\nde Produtos',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => onTap(RelatorioCategoria.total),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '${resumo.totalGeral}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textHeading,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 96,
                  color: AppColors.divider,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      const Text(
                        'Total de Produtos',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatColumn(
                            icon: Icons.shopping_cart,
                            color: AppColors.primary,
                            label: 'Vendidos',
                            value: resumo.vendidos,
                            onTap: () => onTap(RelatorioCategoria.vendidos),
                          ),
                          _StatColumn(
                            icon: Icons.access_time,
                            color: AppColors.offline,
                            label: 'Pendentes',
                            value: resumo.pendentes,
                            onTap: () => onTap(RelatorioCategoria.pendentes),
                          ),
                          _StatColumn(
                            icon: Icons.arrow_downward,
                            color: AppColors.danger,
                            label: 'Baixados',
                            value: resumo.baixados,
                            onTap: () => onTap(RelatorioCategoria.baixados),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int value;
  final VoidCallback onTap;

  const _StatColumn({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color,
              child: Icon(icon, color: AppColors.white, size: 18),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final Produto produto;
  const _ItemTile({required this.produto});

  @override
  Widget build(BuildContext context) {
    final detalhes = <String>[
      'Validade: ${du.formatShort(produto.validade)}',
      if (produto.situacao.isNotEmpty) produto.situacao,
      if (produto.status.isNotEmpty) produto.status,
    ];
    return ListTile(
      dense: true,
      title: Text(
        produto.nome.isEmpty ? '(sem nome)' : produto.nome,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        detalhes.join('  •  '),
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
      trailing: Text(
        'Qtd: ${produto.quantidade}',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
