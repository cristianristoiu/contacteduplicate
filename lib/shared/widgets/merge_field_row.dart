import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

class MergeFieldRow extends StatelessWidget {
  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;
  final String? fieldLabel;
  final String emptyValuePlaceholder;
  final double stackedBreakpoint;
  final EdgeInsetsGeometry padding;

  const MergeFieldRow({
    super.key,
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
    this.fieldLabel,
    this.emptyValuePlaceholder = '—',
    this.stackedBreakpoint = 520,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  })  : assert(leftLabel.trim().isNotEmpty),
        assert(rightLabel.trim().isNotEmpty),
        assert(emptyValuePlaceholder.isNotEmpty),
        assert(stackedBreakpoint > 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedFieldLabel = fieldLabel?.trim();
    final hasFieldLabel = normalizedFieldLabel != null &&
        normalizedFieldLabel.isNotEmpty;
    final normalizedLeftValue = _normalizeValue(leftValue);
    final normalizedRightValue = _normalizeValue(rightValue);
    final difference = _TextDifference.between(
      normalizedLeftValue,
      normalizedRightValue,
    );
    final borderColor = theme.dividerTheme.color ??
        theme.colorScheme.outlineVariant;
    final surfaceColor = theme.brightness == Brightness.dark
        ? AppColors.darkSurfaceMuted
        : AppColors.lightSurfaceMuted;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (hasFieldLabel) ...<Widget>[
              Text(
                normalizedFieldLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final isStacked =
                    constraints.maxWidth < stackedBreakpoint;
                final leftPanel = _MergeValuePanel(
                  label: leftLabel.trim(),
                  value: normalizedLeftValue,
                  spans: difference.spansForLeft(
                    context,
                    normalizedLeftValue,
                  ),
                );
                final rightPanel = _MergeValuePanel(
                  label: rightLabel.trim(),
                  value: normalizedRightValue,
                  spans: difference.spansForRight(
                    context,
                    normalizedRightValue,
                  ),
                );

                if (isStacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      leftPanel,
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: borderColor,
                        ),
                      ),
                      rightPanel,
                    ],
                  );
                }

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(child: leftPanel),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: borderColor,
                        ),
                      ),
                      Expanded(child: rightPanel),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _normalizeValue(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? emptyValuePlaceholder : normalized;
  }
}

class _MergeValuePanel extends StatelessWidget {
  final String label;
  final String value;
  final List<InlineSpan> spans;

  const _MergeValuePanel({
    required this.label,
    required this.value,
    required this.spans,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryColor = theme.brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Semantics(
      container: true,
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: secondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text.rich(
              TextSpan(children: spans),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _TextDifference {
  final int commonPrefixLength;
  final int commonSuffixLength;
  final bool valuesMatch;

  const _TextDifference({
    required this.commonPrefixLength,
    required this.commonSuffixLength,
    required this.valuesMatch,
  });

  factory _TextDifference.between(String left, String right) {
    if (left == right) {
      return _TextDifference(
        commonPrefixLength: left.length,
        commonSuffixLength: 0,
        valuesMatch: true,
      );
    }

    final shortestLength = math.min(left.length, right.length);
    var prefixLength = 0;
    while (prefixLength < shortestLength &&
        left.codeUnitAt(prefixLength) == right.codeUnitAt(prefixLength)) {
      prefixLength++;
    }

    var suffixLength = 0;
    final remainingLength = shortestLength - prefixLength;
    while (suffixLength < remainingLength &&
        left.codeUnitAt(left.length - suffixLength - 1) ==
            right.codeUnitAt(right.length - suffixLength - 1)) {
      suffixLength++;
    }

    return _TextDifference(
      commonPrefixLength: prefixLength,
      commonSuffixLength: suffixLength,
      valuesMatch: false,
    );
  }

  List<InlineSpan> spansForLeft(BuildContext context, String value) {
    return _buildSpans(context, value);
  }

  List<InlineSpan> spansForRight(BuildContext context, String value) {
    return _buildSpans(context, value);
  }

  List<InlineSpan> _buildSpans(BuildContext context, String value) {
    final baseStyle = AppTextStyles.bodyStrong.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
    );
    if (valuesMatch) {
      return <InlineSpan>[
        TextSpan(text: value, style: baseStyle),
      ];
    }

    final differenceEnd = value.length - commonSuffixLength;
    final spans = <InlineSpan>[];

    if (commonPrefixLength > 0) {
      spans.add(
        TextSpan(
          text: value.substring(0, commonPrefixLength),
          style: baseStyle,
        ),
      );
    }

    if (differenceEnd > commonPrefixLength) {
      spans.add(
        TextSpan(
          text: value.substring(commonPrefixLength, differenceEnd),
          style: baseStyle.copyWith(
            color: AppColors.error,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    if (commonSuffixLength > 0) {
      spans.add(
        TextSpan(
          text: value.substring(differenceEnd),
          style: baseStyle,
        ),
      );
    }

    return spans;
  }
}
