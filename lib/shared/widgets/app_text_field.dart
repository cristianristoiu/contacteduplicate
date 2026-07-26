import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool autofocus;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final int minLines;
  final int? maxLines;

  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.minLines = 1,
    this.maxLines = 1,
  })  : assert(minLines > 0),
        assert(maxLines == null || maxLines >= minLines),
        assert(!obscureText || maxLines == 1);

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  TextEditingController? _internalController;
  FocusNode? _internalFocusNode;

  TextEditingController get _effectiveController =>
      widget.controller ??
      (_internalController ??= TextEditingController());

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ??
      (_internalFocusNode ??= FocusNode(debugLabel: 'AppTextField'));

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller == null && widget.controller != null) {
        _internalController?.dispose();
        _internalController = null;
      } else if (oldWidget.controller != null && widget.controller == null) {
        _internalController = TextEditingController.fromValue(
          oldWidget.controller!.value,
        );
      }
    }

    if (oldWidget.focusNode != widget.focusNode) {
      if (oldWidget.focusNode == null && widget.focusNode != null) {
        _internalFocusNode?.dispose();
        _internalFocusNode = null;
      } else if (oldWidget.focusNode != null && widget.focusNode == null) {
        final hadFocus = oldWidget.focusNode!.hasFocus;
        _internalFocusNode = FocusNode(debugLabel: 'AppTextField');

        if (hadFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _internalFocusNode?.requestFocus();
            }
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _internalController?.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final fillColor = widget.enabled
        ? (isDark ? AppColors.darkSurface : AppColors.lightSurface)
        : (isDark
            ? AppColors.darkSurfaceMuted
            : AppColors.lightSurfaceMuted);
    final borderRadius = BorderRadius.circular(12);

    return TextField(
      controller: _effectiveController,
      focusNode: _effectiveFocusNode,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      obscureText: widget.obscureText,
      autocorrect: widget.autocorrect,
      enableSuggestions: widget.enableSuggestions,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      cursorColor: AppColors.blue500,
      style: AppTextStyles.body.copyWith(color: textColor),
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        prefixIcon: widget.prefixIcon,
        prefixIconColor: secondaryTextColor,
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        labelStyle: AppTextStyles.body.copyWith(color: secondaryTextColor),
        floatingLabelStyle: AppTextStyles.label.copyWith(
          color: AppColors.blue500,
        ),
        hintStyle: AppTextStyles.body.copyWith(color: secondaryTextColor),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: const BorderSide(
            color: AppColors.blue500,
            width: 1.5,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: borderColor.withOpacity(0.65)),
        ),
      ),
    );
  }
}
