import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Tema global do aplicativo.
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    useMaterial3: true,
  );
}
