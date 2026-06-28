import 'package:flutter/material.dart';
import '../controllers/relatorio_controller.dart';
import '../models/produto.dart';
import '../theme/app_colors.dart';
import '../widgets/loading_indicator.dart';

class TopVencidosScreen extends StatefulWidget {
  const TopVencidosScreen({super.key});

  @override
  State<TopVencidosScreen> createState() => _TopVencidosScreenState();
}

class _TopVencidosScreenState extends State<TopVencidosScreen>
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

  @override
  void dispose() {
    _c.removeListener(_onControllerChanged);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final mesRef = _c.mesReferencia() ?? DateTime.now().month;
    final mesAtual = _meses[mesRef - 1];

    if (_c.loading) {
      return const LoadingIndicator();
    }

    final topGlobal = _c.topVencidosGlobal();

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
              'Top Produtos Vencidos',
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
            if (_c.resumos.isNotEmpty) ...[
              _TopCard(
                titulo: 'Geral (todos os locais)',
                subtitulo: 'Top 10 mais vencidos',
                icon: Icons.summarize,
                headerColor: AppColors.primaryDark,
                itens: topGlobal,
                showLocal: true,
                vazio: 'Nenhum produto vencido',
              ),
              const SizedBox(height: 16),
            ],
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
                          child: _TopCard(
                            titulo: r.nome,
                            subtitulo: 'Top 5 mais vencidos',
                            icon: Icons.location_on,
                            headerColor: AppColors.primary,
                            itens: _c.topVencidosLocal(r.nome),
                            vazio: 'Nenhum produto vencido',
                            collapsible: true,
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

class _TopCard extends StatefulWidget {
  final String titulo;
  final String subtitulo;
  final IconData icon;
  final Color headerColor;
  final List<Produto> itens;
  final bool showLocal;
  final String vazio;
  final bool collapsible;

  const _TopCard({
    required this.titulo,
    required this.subtitulo,
    required this.icon,
    required this.headerColor,
    required this.itens,
    required this.vazio,
    this.showLocal = false,
    this.collapsible = false,
  });

  @override
  State<_TopCard> createState() => _TopCardState();
}

class _TopCardState extends State<_TopCard> {
  late bool _expanded = !widget.collapsible;

  void _toggle() {
    if (!widget.collapsible) return;
    setState(() => _expanded = !_expanded);
  }

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
            onTap: widget.collapsible ? _toggle : null,
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
                  if (widget.collapsible) ...[
                    const SizedBox(width: 6),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.white,
                      size: 22,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_expanded)
            if (widget.itens.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  widget.vazio,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 10,
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < widget.itens.length; i++)
                      _RankRow(
                        posicao: i + 1,
                        produto: widget.itens[i],
                        showLocal: widget.showLocal,
                        divider: i < widget.itens.length - 1,
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final int posicao;
  final Produto produto;
  final bool showLocal;
  final bool divider;

  const _RankRow({
    required this.posicao,
    required this.produto,
    required this.showLocal,
    required this.divider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: divider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            )
          : null,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: Row(
        children: [
          _RankBadge(posicao: posicao),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  produto.nome.isEmpty ? '(sem nome)' : produto.nome,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textHeading,
                  ),
                ),
                if (showLocal && produto.localNome.isNotEmpty)
                  Text(
                    produto.localNome,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Qtd: ${produto.quantidade}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int posicao;
  const _RankBadge({required this.posicao});

  Color get _cor {
    switch (posicao) {
      case 1:
        return const Color(0xFFD4AF37); // ouro
      case 2:
        return const Color(0xFF9E9E9E); // prata
      case 3:
        return const Color(0xFFCD7F32); // bronze
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _cor, shape: BoxShape.circle),
      child: Text(
        '$posicaoº',
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
