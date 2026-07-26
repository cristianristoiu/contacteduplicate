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
                  spans: difference.buildSpans(
                    context,
                    normalizedLeftValue,
                  ),
                );
                final rightPanel = _MergeValuePanel(
                  label: rightLabel.trim(),
                  value: normalizedRightValue,
                  spans: difference.buildSpans(
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
  final int commonPrefixRuneCount;
  final int commonSuffixRuneCount;
  final bool valuesMatch;

  const _TextDifference({
    required this.commonPrefixRuneCount,
    required this.commonSuffixRuneCount,
    required this.valuesMatch,
  });

  factory _TextDifference.between(String left, String right) {
    final leftRunes = left.runes.toList(growable: false);
    final rightRunes = right.runes.toList(growable: false);

    if (left == right) {
      return _TextDifference(
        commonPrefixRuneCount: leftRunes.length,
        commonSuffixRuneCount: 0,
        valuesMatch: true,
      );
    }

    final shortestLength = math.min(leftRunes.length, rightRunes.length);
    var prefixLength = 0;
    while (prefixLength < shortestLength &&
        leftRunes[prefixLength] == rightRunes[prefixLength]) {
      prefixLength++;
    }

    var suffixLength = 0;
    final remainingLength = shortestLength - prefixLength;
    while (suffixLength < remainingLength &&
        leftRunes[leftRunes.length - suffixLength - 1] ==
            rightRunes[rightRunes.length - suffixLength - 1]) {
      suffixLength++;
    }

    return _TextDifference(
      commonPrefixRuneCount: prefixLength,
      commonSuffixRuneCount: suffixLength,
      valuesMatch: false,
    );
  }

  List<InlineSpan> buildSpans(BuildContext context, String value) {
    final baseStyle = AppTextStyles.bodyStrong.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
    );
    if (valuesMatch) {
      return <InlineSpan>[
        TextSpan(text: value, style: baseStyle),
      ];
    }

    final runeOffsets = _RuneOffsets.from(value);
    final differenceStart =
        runeOffsets.codeUnitOffsetAt(commonPrefixRuneCount);
    final differenceEnd = runeOffsets.codeUnitOffsetAt(
      runeOffsets.runeCount - commonSuffixRuneCount,
    );
    final spans = <InlineSpan>[];

    if (differenceStart > 0) {
      spans.add(
        TextSpan(
          text: value.substring(0, differenceStart),
          style: baseStyle,
        ),
      );
    }

    if (differenceEnd > differenceStart) {
      spans.add(
        TextSpan(
          text: value.substring(differenceStart, differenceEnd),
          style: baseStyle.copyWith(
            color: AppColors.error,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    if (differenceEnd < value.length) {
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

class _RuneOffsets {
  final List<int> _codeUnitOffsets;

  const _RuneOffsets._(this._codeUnitOffsets);

  factory _RuneOffsets.from(String value) {
    final offsets = <int>[0];
    var codeUnitOffset = 0;

    for (final rune in value.runes) {
      codeUnitOffset += rune > 0xFFFF ? 2 : 1;
      offsets.add(codeUnitOffset);
    }

    return _RuneOffsets._(offsets);
  }

  int get runeCount => _codeUnitOffsets.length - 1;

  int codeUnitOffsetAt(int runeIndex) {
    assert(runeIndex >= 0 && runeIndex <= runeCount);
    return _codeUnitOffsets[runeIndex];
  }
}
