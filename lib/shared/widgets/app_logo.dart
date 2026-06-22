import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showBackground;

  const AppLogo({
    super.key,
    this.size = 120,
    this.showBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    if (showBackground) {
      return Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SvgPicture.asset(
            'docs/theme/design/logo-background.svg',
            width: size,
            height: size,
          ),
          SvgPicture.asset(
            'docs/theme/design/logo-foreground.svg',
            width: size * 0.6,
            height: size * 0.6,
          ),
        ],
      );
    }

    return SvgPicture.asset(
      'assets/brand/logo.svg',
      width: size,
      height: size,
    );
  }
}
