import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Indicador de carregamento padrão (spinner + texto).
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key, this.message = 'Carregando...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 12),
          Text(message, style: AppTextStyles.hint),
        ],
      ),
    );
  }
}
