import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum StatusBadgeType {
  secure,
  probable,
  manual,
}

class StatusBadge extends StatelessWidget {
  final int score;
  final String label;

  const StatusBadge({
    super.key,
    required this.score,
    required this.label,
  });

  StatusBadgeType get type {
    if (score >= 95) return StatusBadgeType.secure;
    if (score >= 80) return StatusBadgeType.probable;
    return StatusBadgeType.manual;
  }

  Color _getColor(BuildContext context) {
    switch (type) {
      case StatusBadgeType.secure:
        return AppColors.statusSuccess;
      case StatusBadgeType.probable:
        return AppColors.brandBlue600;
      case StatusBadgeType.manual:
        return AppColors.statusWarning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$score%',
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 10,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
