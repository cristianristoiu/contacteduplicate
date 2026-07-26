import 'package:flutter/material.dart';

enum AppShadowLevel {
  soft,
  medium,
  hard,
}

class AppBoxShadows {
  const AppBoxShadows._();

  static const Color _shadowColor = Color(0xFF172554);

  static List<BoxShadow> soft(Brightness brightness) {
    return _resolve(
      brightness: brightness,
      opacity: 0.05,
      blurRadius: 8,
      offset: const Offset(0, 2),
    );
  }

  static List<BoxShadow> medium(Brightness brightness) {
    return _resolve(
      brightness: brightness,
      opacity: 0.08,
      blurRadius: 16,
      offset: const Offset(0, 6),
    );
  }

  static List<BoxShadow> hard(Brightness brightness) {
    return _resolve(
      brightness: brightness,
      opacity: 0.12,
      blurRadius: 28,
      offset: const Offset(0, 12),
    );
  }

  static Color elevatedSurface(
    Color surface,
    Brightness brightness, {
    AppShadowLevel level = AppShadowLevel.soft,
  }) {
    if (brightness != Brightness.dark) {
      return surface;
    }

    final overlayOpacity = switch (level) {
      AppShadowLevel.soft => 0.04,
      AppShadowLevel.medium => 0.07,
      AppShadowLevel.hard => 0.10,
    };

    return Color.alphaBlend(
      Colors.white.withOpacity(overlayOpacity),
      surface,
    );
  }

  static List<BoxShadow> _resolve({
    required Brightness brightness,
    required double opacity,
    required double blurRadius,
    required Offset offset,
  }) {
    if (brightness == Brightness.dark) {
      return const <BoxShadow>[];
    }

    return <BoxShadow>[
      BoxShadow(
        color: _shadowColor.withOpacity(opacity),
        blurRadius: blurRadius,
        offset: offset,
      ),
    ];
  }
}
