import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'app_icon_button.dart';

class InfoBox extends StatelessWidget {
  final String message;
  final VoidCallback? onClose;
  final IconData icon;
  final String? closeTooltip;
  final EdgeInsetsGeometry padding;

  const InfoBox({
    super.key,
    required this.message,
    this.onClose,
    this.icon = Icons.info_outline_rounded,
    this.closeTooltip,
    this.padding = const EdgeInsets.all(12),
  }) : assert(message.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final backgroundColor = AppColors.blue500.withOpacity(isDark ? 0.14 : 0.08);
    final closeCallback = onClose;

    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  icon,
                  size: 22,
                  color: AppColors.blue500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.body.copyWith(color: textColor),
                ),
              ),
              if (closeCallback != null) ...<Widget>[
                const SizedBox(width: 4),
                AppIconButton(
                  icon: Icons.close_rounded,
                  onPressed: closeCallback,
                  size: 40,
                  iconSize: 18,
                  backgroundColor: Colors.transparent,
                  iconColor: textColor,
                  tooltip: closeTooltip ??
                      MaterialLocalizations.of(context).closeButtonTooltip,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
