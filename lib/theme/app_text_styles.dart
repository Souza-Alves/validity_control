import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Estilos de texto reutilizados pelas telas.
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle heading = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textHeading,
  );

  static const TextStyle appBarTitle = TextStyle(
    color: AppColors.white,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle fieldLabel = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
  );

  static const TextStyle input = TextStyle(
    fontSize: 14,
    color: AppColors.textHeading,
  );

  static const TextStyle hint = TextStyle(color: AppColors.textMuted);

  static const TextStyle tableHeader = TextStyle(
    color: AppColors.white,
    fontWeight: FontWeight.bold,
    fontSize: 11,
  );

  static const TextStyle tableCell = TextStyle(fontSize: 11);

  static const TextStyle offlineBanner = TextStyle(
    color: AppColors.white,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );
}
