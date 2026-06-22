import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.blue600,
        brightness: Brightness.light,
        primary: AppColors.blue600,
        secondary: AppColors.violet500,
        surface: AppColors.lightSurface,
        error: AppColors.error,
      ),
    );

    return _withCommonSettings(
      base,
      textColor: AppColors.lightTextPrimary,
      secondaryTextColor: AppColors.lightTextSecondary,
      cardColor: AppColors.lightSurface,
      borderColor: AppColors.lightBorder,
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.blue500,
        brightness: Brightness.dark,
        primary: AppColors.blue500,
        secondary: AppColors.violet400,
        surface: AppColors.darkSurface,
        error: AppColors.error,
      ),
    );

    return _withCommonSettings(
      base,
      textColor: AppColors.darkTextPrimary,
      secondaryTextColor: AppColors.darkTextSecondary,
      cardColor: AppColors.darkSurface,
      borderColor: AppColors.darkBorder,
    );
  }

  static ThemeData _withCommonSettings(
    ThemeData base, {
    required Color textColor,
    required Color secondaryTextColor,
    required Color cardColor,
    required Color borderColor,
  }) {
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: AppTextStyles.display.copyWith(color: textColor),
        headlineLarge: AppTextStyles.h1.copyWith(color: textColor),
        headlineMedium: AppTextStyles.h2.copyWith(color: textColor),
        bodyLarge: AppTextStyles.body.copyWith(color: textColor),
        bodyMedium: AppTextStyles.body.copyWith(color: secondaryTextColor),
        labelLarge: AppTextStyles.label.copyWith(color: textColor),
        bodySmall: AppTextStyles.caption.copyWith(color: secondaryTextColor),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: borderColor),
        ),
      ),
      dividerTheme: DividerThemeData(color: borderColor),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.h2.copyWith(color: textColor),
        iconTheme: IconThemeData(color: textColor),
      ),
    );
  }
}
