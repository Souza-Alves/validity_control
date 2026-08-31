import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

/// Célula de cabeçalho das tabelas (clicável para ordenar).
class TableHeaderCell extends StatelessWidget {
  const TableHeaderCell({
    super.key,
    required this.text,
    required this.flex,
    required this.onTap,
    this.align = TextAlign.left,
  });

  final String text;
  final int flex;
  final VoidCallback onTap;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(text, textAlign: align, style: AppTextStyles.tableHeader),
        ),
      ),
    );
  }
}
