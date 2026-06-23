import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class AppEmptyState extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String description;
  final Widget? action;

  const AppEmptyState({
    super.key,
    this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.blue500 : AppColors.blue500).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: AppColors.blue500,
              ),
            ),
          const SizedBox(height: 32),
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
          if (action != null) ...[
            const SizedBox(height: 32),
            action!,
          ],
        ],
      ),
    );
  }
}
