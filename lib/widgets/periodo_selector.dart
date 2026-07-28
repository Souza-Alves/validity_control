import 'package:flutter/material.dart';
import '../controllers/relatorio_controller.dart';
import '../theme/app_colors.dart';

/// Dropdown para escolher o período (mês/ano) exibido no relatório.
class PeriodoSelector extends StatelessWidget {
  final List<Periodo> periodos;
  final Periodo? selecionado;
  final ValueChanged<Periodo?> onChanged;

  const PeriodoSelector({
    super.key,
    required this.periodos,
    required this.selecionado,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (periodos.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.filter_alt, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        const Text(
          'Período:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Periodo>(
              value: selecionado,
              isDense: true,
              icon: const Icon(
                Icons.arrow_drop_down,
                color: AppColors.primary,
              ),
              items: [
                for (final p in periodos)
                  DropdownMenuItem<Periodo>(
                    value: p,
                    child: Text(
                      p.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHeading,
                      ),
                    ),
                  ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
