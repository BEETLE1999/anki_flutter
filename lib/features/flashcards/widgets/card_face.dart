// lib/features/flashcards/widgets/card_face.dart
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/constants/app_enum.dart';
import '../../../core/theme/app_colors.dart';

class CardFace extends StatelessWidget {
  const CardFace({
    super.key,
    required this.child,
    this.isBookmarked = false,
    this.onBookmarkTap,
    this.completed = false,
    this.onCompletedTap,
  });

  final Widget child;
  final bool isBookmarked;
  final VoidCallback? onBookmarkTap;
  final bool completed;
  final VoidCallback? onCompletedTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Card(
          color: AppColors.appWhite,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: child),
          ),
        ),
        // 右上ブックマーク
        Positioned(
          top: -12,
          right: 16,
          child: IconButton(
            icon: Icon(
              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              size: 40,
              color: isBookmarked
                  ? AppColors.sacredGreen
                  : AppColors.textSecondary,
            ),
            onPressed: onBookmarkTap,
          ),
        ),
        // 右下「完了アイコン」
        Positioned(
          bottom: 14,
          right: 18,
          child: IconButton(
            icon: Icon(
              Symbols.check_circle,
              fill: completed ? IconFill.filled.value : IconFill.outlined.value,
              size: 36,
              color: completed
                  ? AppColors.sacredGreen
                  : AppColors.textSecondary,
            ),
            onPressed: onCompletedTap,
          ),
        ),
      ],
    );
  }
}
