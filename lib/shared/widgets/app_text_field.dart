import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? clearTooltip;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final bool autofocus;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final bool showClearButton;
  final int minLines;
  final int? maxLines;

  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.clearTooltip,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.onClear,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.showClearButton = true,
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
    final controller = _effectiveController;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return _buildTextField(
          context,
          controller: controller,
          value: value,
        );
      },
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required TextEditingValue value,
  }) {
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
    final helperText = _normalizedText(widget.helperText);
    final errorText = _normalizedText(widget.errorText);
    final suffix = _buildSuffix(
      context,
      controller: controller,
      hasText: value.text.isNotEmpty,
    );

    return TextField(
      controller: controller,
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
        helperText: helperText,
        errorText: errorText,
        prefixIcon: widget.prefixIcon,
        suffixIcon: suffix,
        prefixIconColor: secondaryTextColor,
        suffixIconColor: secondaryTextColor,
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        labelStyle: AppTextStyles.body.copyWith(color: secondaryTextColor),
        floatingLabelStyle: AppTextStyles.label.copyWith(
          color: errorText == null ? AppColors.blue500 : AppColors.error,
        ),
        hintStyle: AppTextStyles.body.copyWith(color: secondaryTextColor),
        helperStyle: AppTextStyles.caption.copyWith(
          color: secondaryTextColor,
        ),
        errorStyle: AppTextStyles.caption.copyWith(color: AppColors.error),
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
        errorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: const BorderSide(
            color: AppColors.error,
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

  Widget? _buildSuffix(
    BuildContext context, {
    required TextEditingController controller,
    required bool hasText,
  }) {
    final canClear = widget.showClearButton &&
        widget.enabled &&
        !widget.readOnly &&
        hasText;

    if (widget.suffixIcon == null && !canClear) {
      return null;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.suffixIcon != null) widget.suffixIcon!,
        if (canClear)
          IconButton(
            tooltip: widget.clearTooltip ??
                MaterialLocalizations.of(context).clearButtonTooltip,
            icon: const Icon(Icons.clear_rounded),
            onPressed: () {
              controller.clear();
              widget.onChanged?.call('');
              widget.onClear?.call();
              _effectiveFocusNode.requestFocus();
            },
          ),
      ],
    );
  }

  String? _normalizedText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
