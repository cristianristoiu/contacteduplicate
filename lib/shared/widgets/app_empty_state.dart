import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'app_primary_button.dart';

class AppEmptyState extends StatelessWidget {
  final IconData? icon;
  final String? illustrationPath;
  final double illustrationHeight;
  final String title;
  final String description;
  final Widget? action;
  final AppPrimaryButton? primaryButton;
  final bool isFullWidthButton;

  const AppEmptyState({
    super.key,
    this.icon,
    this.illustrationPath,
    this.illustrationHeight = 180,
    required this.title,
    required this.description,
    this.action,
    this.primaryButton,
    this.isFullWidthButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final visual = _buildVisual(isDark);
    final footer = _buildFooter();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (visual != null) ...[
            visual,
            const SizedBox(height: 32),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.h2.copyWith(
              color: isDark ? Colors.white : AppColors.blue900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              color: (isDark ? Colors.white : AppColors.blue900).withOpacity(0.6),
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 24),
            footer,
          ],
        ],
      ),
    );
  }

  Widget? _buildVisual(bool isDark) {
    final fallbackIcon = _buildFallbackIcon(isDark);
    final normalizedPath = illustrationPath?.trim();

    if (normalizedPath != null && normalizedPath.isNotEmpty) {
      return _EmptyStateIllustration(
        path: normalizedPath,
        height: illustrationHeight,
        fallback: fallbackIcon,
      );
    }

    return fallbackIcon;
  }

  Widget? _buildFallbackIcon(bool isDark) {
    if (icon == null) {
      return null;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.blue500.withOpacity(isDark ? 0.1 : 0.08),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 64,
        color: AppColors.blue500,
      ),
    );
  }

  Widget? _buildFooter() {
    final button = primaryButton;

    if (button != null) {
      if (isFullWidthButton) {
        return SizedBox(
          width: double.infinity,
          child: button,
        );
      }

      return button;
    }

    return action;
  }
}

class _EmptyStateIllustration extends StatelessWidget {
  final String path;
  final double height;
  final Widget? fallback;

  const _EmptyStateIllustration({
    required this.path,
    required this.height,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: rootBundle.loadString(path),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || snapshot.hasError || snapshot.data == null) {
          return fallback ?? SizedBox(height: height);
        }

        return SvgPicture.string(
          snapshot.data!,
          height: height,
          fit: BoxFit.contain,
        );
      },
    );
  }
}
