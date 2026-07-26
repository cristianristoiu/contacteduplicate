import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showBackground;

  const AppLogo({
    super.key,
    this.size = 120,
    this.showBackground = false,
  }) : assert(size > 0);

  @override
  Widget build(BuildContext context) {
    final logo = SvgPicture.asset(
      'assets/brand/logo.svg',
      width: showBackground ? size * 0.64 : size,
      height: showBackground ? size * 0.64 : size,
      fit: BoxFit.contain,
      semanticsLabel: 'Contacte Duplicate',
    );

    if (!showBackground) {
      return logo;
    }

    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.brandGradient,
        ),
        child: Center(child: logo),
      ),
    );
  }
}
