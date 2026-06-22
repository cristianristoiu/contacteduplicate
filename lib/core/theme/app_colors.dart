import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color navy950 = Color(0xFF061126);
  static const Color navy900 = Color(0xFF0D1839);
  static const Color navy800 = Color(0xFF111F4C);
  static const Color blue500 = Color(0xFF25D8FF);
  static const Color blue600 = Color(0xFF1F8BFF);
  static const Color violet500 = Color(0xFF5B35D5);
  static const Color violet400 = Color(0xFF8D5CFF);

  static const Color lightBackground = Color(0xFFF5F8FF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceMuted = Color(0xFFEDF3FF);
  static const Color lightTextPrimary = Color(0xFF121A33);
  static const Color lightTextSecondary = Color(0xFF596584);
  static const Color lightBorder = Color(0xFFE1E7F5);

  static const Color darkBackground = Color(0xFF061126);
  static const Color darkSurface = Color(0xFF0D1839);
  static const Color darkSurfaceMuted = Color(0xFF101B45);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFAEBCE4);
  static const Color darkBorder = Color(0xFF273661);

  static const Color success = Color(0xFF24B47E);
  static const Color warning = Color(0xFFFFB020);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF25D8FF);

  static const LinearGradient brandGradient = LinearGradient(
    colors: <Color>[blue500, violet400],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
