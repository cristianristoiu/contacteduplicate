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
  })  : assert(title.trim().isNotEmpty),
        assert(message.trim().isNotEmpty),
        assert(confirmText.trim().isNotEmpty),
        assert(cancelText.trim().isNotEmpty);

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    required String cancelText,
    bool isDestructive = false,
    bool barrierDismissible = true,
  }) async {
    assert(title.trim().isNotEmpty);
    assert(message.trim().isNotEmpty);
    assert(confirmText.trim().isNotEmpty);
    assert(cancelText.trim().isNotEmpty);

    final result = await AppDialog.show<bool>(
      context,
      title: title,
      barrierDismissible: barrierDismissible,
      child: _ConfirmationMessage(message: message),
      actions: _buildActions(
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: title,
      actions: _buildActions(
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
      ),
      child: _ConfirmationMessage(message: message),
    );
  }

  static List<Widget> _buildActions({
    required String confirmText,
    required String cancelText,
    required bool isDestructive,
  }) {
    return <Widget>[
      Builder(
        builder: (dialogContext) {
          return AppSecondaryButton(
            label: cancelText,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          );
        },
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
            onPressed: onConfirm,
          );
        },
      ),
    ];
  }
}

class _ConfirmationMessage extends StatelessWidget {
  final String message;

  const _ConfirmationMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: AppTextStyles.body.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
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
    return FilledButton(
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
      child: Text(label),
    );
  }
}
