import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isEnabled = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final bool isLoading;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final canUse = onPressed != null && isEnabled;
    final effectiveLeadingIcon = icon != null ? Icon(icon, color: Colors.white, size: 20) : leadingIcon;

    return Opacity(
      opacity: canUse ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: canUse ? AppColors.brandGradient : null,
          color: canUse ? null : Theme.of(context).disabledColor.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: canUse && !isLoading ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: isLoading
                    ? const SizedBox(
                        key: ValueKey<String>('loading'),
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : IconTheme.merge(
                        data: const IconThemeData(color: Colors.white, size: 20),
                        child: Row(
                          key: const ValueKey<String>('content'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (effectiveLeadingIcon != null) ...<Widget>[
                              effectiveLeadingIcon,
                              const SizedBox(width: 8),
                            ],
                            Text(
                              label,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (trailingIcon != null) ...<Widget>[
                              const SizedBox(width: 8),
                              trailingIcon!,
                            ],
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
