import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'app_dialog.dart';
import 'app_primary_button.dart';
import 'app_secondary_button.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final bool isDestructive;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    this.isDestructive = false,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    required String cancelText,
    bool isDestructive = false,
    bool barrierDismissible = false,
  }) async {
    final normalizedTitle = title.trim();
    final normalizedMessage = message.trim();
    final normalizedConfirm = confirmText.trim();
    final normalizedCancel = cancelText.trim();
    if (normalizedTitle.isEmpty ||
        normalizedMessage.isEmpty ||
        normalizedConfirm.isEmpty ||
        normalizedCancel.isEmpty ||
        normalizedConfirm == normalizedCancel) {
      return false;
    }

    final result = await AppDialog.show<bool>(
      context,
      title: normalizedTitle,
      barrierDismissible: isDestructive ? false : barrierDismissible,
      child: _ConfirmationMessage(
        message: normalizedMessage,
        isDestructive: isDestructive,
      ),
      actions: _buildActions(
        confirmText: normalizedConfirm,
        cancelText: normalizedCancel,
        isDestructive: isDestructive,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final normalizedTitle = title.trim();
    final normalizedMessage = message.trim();
    final normalizedConfirm = confirmText.trim();
    final normalizedCancel = cancelText.trim();
    if (normalizedTitle.isEmpty ||
        normalizedMessage.isEmpty ||
        normalizedConfirm.isEmpty ||
        normalizedCancel.isEmpty ||
        normalizedConfirm == normalizedCancel) {
      return const SizedBox.shrink();
    }
    return AppDialog(
      title: normalizedTitle,
      actions: _buildActions(
        confirmText: normalizedConfirm,
        cancelText: normalizedCancel,
        isDestructive: isDestructive,
      ),
      child: _ConfirmationMessage(
        message: normalizedMessage,
        isDestructive: isDestructive,
      ),
    );
  }

  static List<Widget> _buildActions({
    required String confirmText,
    required String cancelText,
    required bool isDestructive,
  }) {
    return <Widget>[
      Builder(
        builder: (dialogContext) => AppSecondaryButton(
          label: cancelText,
          semanticLabel: 'Anuleaza: $cancelText',
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
      ),
      Builder(
        builder: (dialogContext) {
          final onConfirm = () => Navigator.of(dialogContext).pop(true);
          if (isDestructive) {
            return _DangerConfirmationButton(
              label: confirmText,
              onPressed: onConfirm,
            );
          }
          return AppPrimaryButton(
            label: confirmText,
            semanticLabel: 'Confirma: $confirmText',
            onPressed: onConfirm,
          );
        },
      ),
    ];
  }
}

class _ConfirmationMessage extends StatelessWidget {
  final String message;
  final bool isDestructive;

  const _ConfirmationMessage({
    required this.message,
    required this.isDestructive,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: isDestructive,
      label: isDestructive ? 'Atentie. $message' : message,
      child: ExcludeSemantics(
        child: Text(
          message,
          style: AppTextStyles.body.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _DangerConfirmationButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _DangerConfirmationButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: true,
      label: 'Actiune distructiva: $label',
      child: ExcludeSemantics(
        child: FilledButton(
          onPressed: () {
            AppHaptics.importantAction();
            onPressed();
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
