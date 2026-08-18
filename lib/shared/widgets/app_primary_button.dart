import 'package:flutter/material.dart';

import '../../core/platform/app_haptics.dart';
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
    this.semanticLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final bool isLoading;
  final bool isEnabled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final canUse = onPressed != null && isEnabled;
    final canActivate = canUse && !isLoading;
    final effectiveLeadingIcon = icon != null
        ? Icon(icon, color: Colors.white, size: 20)
        : leadingIcon;
    final accessibleLabel = semanticLabel?.trim().isNotEmpty == true
        ? semanticLabel!.trim()
        : label.trim();

    return Semantics(
      button: true,
      enabled: canActivate,
      label: accessibleLabel,
      value: isLoading ? 'in curs' : null,
      liveRegion: isLoading,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: canUse ? 1 : 0.5,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: canUse ? AppColors.brandGradient : null,
                color: canUse
                    ? null
                    : Theme.of(context).disabledColor.withOpacity(0.16),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  canRequestFocus: canActivate,
                  mouseCursor: canActivate
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic,
                  onTap: canActivate
                      ? () {
                          AppHaptics.importantAction();
                          onPressed?.call();
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: AnimatedSwitcher(
                      duration: MediaQuery.maybeOf(context)?.disableAnimations == true
                          ? Duration.zero
                          : const Duration(milliseconds: 160),
                      child: isLoading
                          ? const SizedBox(
                              key: ValueKey<String>('loading'),
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : IconTheme.merge(
                              data: const IconThemeData(
                                color: Colors.white,
                                size: 20,
                              ),
                              child: Row(
                                key: const ValueKey<String>('content'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  if (effectiveLeadingIcon != null) ...<Widget>[
                                    effectiveLeadingIcon,
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: Text(
                                      label,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
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
          ),
        ),
      ),
    );
  }
}
