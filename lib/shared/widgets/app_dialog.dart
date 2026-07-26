import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

class AppDialog extends StatelessWidget {
  final String? title;
  final Widget child;
  final List<Widget> actions;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const AppDialog({
    super.key,
    this.title,
    required this.child,
    this.actions = const <Widget>[],
    this.maxWidth = 520,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  }) : assert(maxWidth > 0);

  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    required Widget child,
    List<Widget> actions = const <Widget>[],
    bool barrierDismissible = true,
    String? barrierLabel,
    double maxWidth = 520,
    EdgeInsetsGeometry padding = const EdgeInsets.all(AppSpacing.lg),
  }) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel ??
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AppDialog(
          title: title,
          actions: actions,
          maxWidth: maxWidth,
          padding: padding,
          child: child,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final scaleAnimation = animation.drive(
          Tween<double>(begin: 0.92, end: 1).chain(
            CurveTween(curve: Curves.easeOutBack),
          ),
        );

        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final titleText = title?.trim();
    final hasTitle = titleText != null && titleText.isNotEmpty;
    final viewportHeight = MediaQuery.of(context).size.height;
    final maxHeight = viewportHeight > 48 ? viewportHeight - 48 : viewportHeight;
    final surface = AppBoxShadows.elevatedSurface(
      theme.cardTheme.color ?? theme.colorScheme.surface,
      brightness,
      level: AppShadowLevel.hard,
    );
    final borderColor =
        theme.dividerTheme.color ?? theme.colorScheme.outlineVariant;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: ColoredBox(
                color: Colors.black.withOpacity(
                  brightness == Brightness.dark ? 0.36 : 0.18,
                ),
              ),
            ),
          ),
        ),
        Center(
          child: SafeArea(
            minimum: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: Semantics(
                scopesRoute: true,
                namesRoute: hasTitle,
                explicitChildNodes: true,
                label: hasTitle ? titleText : null,
                child: Material(
                  color: surface,
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: borderColor),
                  ),
                  child: Padding(
                    padding: padding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (hasTitle) ...<Widget>[
                          Text(
                            titleText,
                            style: AppTextStyles.h2.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        Flexible(
                          child: SingleChildScrollView(
                            child: child,
                          ),
                        ),
                        if (actions.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.lg),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: actions,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
