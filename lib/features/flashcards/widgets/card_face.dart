// lib/features/flashcards/widgets/card_face.dart

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/constants/app_enum.dart';
import '../../../core/theme/app_colors.dart';

class CardFace extends StatefulWidget {
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
  State<CardFace> createState() => _CardFaceState();
}

class _CardFaceState extends State<CardFace> {
  final scrollKey = GlobalKey();
  double? scrollHeight;

  @override
  void initState() {
    super.initState();

    // 描画完了後に高さ取得
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = scrollKey.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box != null) {
        setState(() {
          scrollHeight = box.size.height;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Card(
          color: AppColors.appWhite,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 32),
              // scrollHeightが取得できたら、固定高さContainerで囲む
              child: Container(
                height: scrollHeight,
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  primary: false,
                  key: scrollKey,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),

        // 右上ブックマーク
        Positioned(
          top: -12,
          right: 16,
          child: IconButton(
            icon: Icon(
              widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              size: 40,
              color: widget.isBookmarked
                  ? AppColors.sacredGreen
                  : AppColors.textSecondary,
            ),
            onPressed: widget.onBookmarkTap,
          ),
        ),

        // 右下「完了」アイコン
        Positioned(
          bottom: 14,
          right: 18,
          child: IconButton(
            icon: Icon(
              Symbols.check_circle,
              fill: widget.completed
                  ? IconFill.filled.value
                  : IconFill.outlined.value,
              size: 36,
              color: widget.completed
                  ? AppColors.sacredGreen
                  : AppColors.textSecondary,
            ),
            onPressed: widget.onCompletedTap,
          ),
        ),
      ],
    );
  }
}
