import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class ContactAvatar extends StatelessWidget {
  final Uint8List? imageBytes;
  final String name;
  final double size;
  final bool showBorder;

  const ContactAvatar({
    super.key,
    this.imageBytes,
    required this.name,
    this.size = 48,
    this.showBorder = false,
  }) : assert(size > 0);

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) {
      return '?';
    }

    final first = _firstCharacter(parts.first);
    if (parts.length == 1) {
      return first;
    }

    return '$first${_firstCharacter(parts.last)}';
  }

  String _firstCharacter(String value) {
    final runes = value.runes;
    if (runes.isEmpty) {
      return '?';
    }

    return String.fromCharCode(runes.first).toUpperCase();
  }

  Color _getBackgroundColor() {
    const colors = <Color>[
      AppColors.blue600,
      AppColors.violet500,
      AppColors.violet400,
      Color(0xFF1CB5E0),
      Color(0xFF000046),
    ];
    final normalizedName = name.trim().toLowerCase();
    final hash = normalizedName.hashCode.abs();
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final image = imageBytes;

    return Semantics(
      image: true,
      label: name.trim().isEmpty ? 'Contact fara nume' : name.trim(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: showBorder
              ? Border.all(
                  color: Theme.of(context).brightness == Brightness.light
                      ? AppColors.lightBorder
                      : AppColors.darkBorder,
                  width: 2,
                )
              : null,
          boxShadow: showBorder
              ? <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ClipOval(
          child: image == null || image.isEmpty
              ? _buildInitials()
              : Image.memory(
                  image,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildInitials(),
                ),
        ),
      ),
    );
  }

  Widget _buildInitials() {
    return ColoredBox(
      color: _getBackgroundColor(),
      child: Center(
        child: Text(
          _initials,
          maxLines: 1,
          style: AppTextStyles.label.copyWith(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
