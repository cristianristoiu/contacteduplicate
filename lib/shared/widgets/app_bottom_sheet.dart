import 'package:flutter/material.dart';

import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

class AppBottomSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final bool isExpanded;
  final EdgeInsetsGeometry padding;

  const AppBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.isExpanded = false,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.sm,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    bool isExpanded = false,
    bool isDismissible = true,
    bool enableDrag = true,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.sm,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AppBottomSheet(
          title: title,
          isExpanded: isExpanded,
          padding: padding,
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final titleText = title?.trim();
    final hasTitle = titleText != null && titleText.isNotEmpty;
    final disableAnimations = mediaQuery.disableAnimations;
    final bottomInset = mediaQuery.viewInsets.bottom;
    final availableHeight = (mediaQuery.size.height - bottomInset)
        .clamp(0.0, double.infinity)
        .toDouble();
    final maxSheetHeight = isExpanded
        ? availableHeight
        : availableHeight * 0.9;
    final surface = AppBoxShadows.elevatedSurface(
      theme.bottomSheetTheme.backgroundColor ?? theme.colorScheme.surface,
      theme.brightness,
      level: AppShadowLevel.medium,
    );
    final borderColor =
        theme.dividerTheme.color ?? theme.colorScheme.outlineVariant;

    final sheet = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: Material(
        color: surface,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
          side: BorderSide(color: borderColor),
        ),
        child: SafeArea(
          top: isExpanded,
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ExcludeSemantics(
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withOpacity(0.28),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                if (hasTitle) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    titleText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h2.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                if (isExpanded)
                  Expanded(child: child)
                else
                  Flexible(
                    child: SingleChildScrollView(child: child),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return AnimatedPadding(
      duration: disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: sheet,
    );
  }
}
