import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'app_secondary_button.dart';

class AppErrorState extends StatelessWidget {
  final String title;
  final String message;
  final String? technicalDetails;
  final IconData icon;
  final bool fullScreen;
  final VoidCallback? onRetry;
  final String retryLabel;

  const AppErrorState({
    super.key,
    required this.title,
    required this.message,
    this.technicalDetails,
    this.icon = Icons.error_outline_rounded,
    this.fullScreen = true,
    this.onRetry,
    this.retryLabel = 'Reincearca',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: fullScreen ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 56,
          color: AppColors.error,
          semanticLabel: title,
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.h2.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        if (_hasTechnicalDetails) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            label: technicalDetails,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(isDark ? 0.12 : 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.error.withOpacity(isDark ? 0.35 : 0.18),
                ),
              ),
              child: Text(
                technicalDetails!,
                textAlign: TextAlign.left,
                style: AppTextStyles.caption.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
          ),
        ],
        if (onRetry != null) ...[
          const SizedBox(height: 20),
          AppSecondaryButton(
            label: retryLabel,
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: fullScreen ? Center(child: content) : content,
    );
  }

  bool get _hasTechnicalDetails {
    final details = technicalDetails?.trim();
    return details != null && details.isNotEmpty;
  }
}
