import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'app_card.dart';

class SummaryCard extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final String prefix;
  final String suffix;
  final Color? iconColor;
  final double size;
  final Duration animationDuration;

  const SummaryCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.prefix = '',
    this.suffix = '',
    this.iconColor,
    this.size = 100,
    this.animationDuration = const Duration(milliseconds: 700),
  })  : assert(value >= 0),
        assert(label.trim().isNotEmpty),
        assert(size >= 88),
        assert(!animationDuration.isNegative);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final effectiveIconColor = iconColor ?? AppColors.blue500;
    final semanticValue = '$prefix$value$suffix';

    return Semantics(
      container: true,
      label: '${label.trim()}: $semanticValue',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.sm + AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  icon,
                  size: 20,
                  color: effectiveIconColor,
                ),
                const Spacer(),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0,
                    end: value.toDouble(),
                  ),
                  duration: disableAnimations
                      ? Duration.zero
                      : animationDuration,
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedValue, _) {
                    return FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$prefix${animatedValue.round()}$suffix',
                        maxLines: 1,
                        style: AppTextStyles.h1.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: theme.brightness == Brightness.dark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
