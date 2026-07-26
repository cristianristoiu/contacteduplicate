import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'app_secondary_button.dart';

class AppErrorState extends StatelessWidget {
  final String title;
  final String message;
  final String? technicalDetails;
  final bool showTechnicalDetails;
  final IconData icon;
  final bool fullScreen;
  final VoidCallback? onRetry;
  final String retryLabel;

  const AppErrorState({
    super.key,
    required this.title,
    required this.message,
    this.technicalDetails,
    this.showTechnicalDetails = false,
    this.icon = Icons.error_outline_rounded,
    this.fullScreen = true,
    this.onRetry,
    this.retryLabel = 'Reincearca',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final visibleTechnicalDetails = _visibleTechnicalDetails;
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: fullScreen ? MainAxisSize.min : MainAxisSize.min,
      children: <Widget>[
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
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        if (visibleTechnicalDetails != null) ...<Widget>[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            label: 'Detalii tehnice pentru depanare',
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
              child: SelectableText(
                visibleTechnicalDetails,
                textAlign: TextAlign.left,
                style: AppTextStyles.caption.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ),
          ),
        ],
        if (onRetry != null) ...<Widget>[
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
      child: fullScreen
          ? Center(
              child: SingleChildScrollView(
                child: content,
              ),
            )
          : content,
    );
  }

  String? get _visibleTechnicalDetails {
    if (!kDebugMode || !showTechnicalDetails) {
      return null;
    }

    final details = technicalDetails?.trim();
    if (details == null || details.isEmpty) {
      return null;
    }

    var redacted = details
        .replaceAll(RegExp(r'\S+@\S+\.\S+'), '[email-redacted]')
        .replaceAll(RegExp(r'(\+?\d[\d\s().-]{6,}\d)'), '[phone-redacted]');
    const maxLength = 500;
    if (redacted.length > maxLength) {
      redacted = '${redacted.substring(0, maxLength)}...';
    }
    return redacted;
  }
}
