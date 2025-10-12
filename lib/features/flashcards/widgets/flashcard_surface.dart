// lib/features/flashcards/widgets/flashcard_surface.dart

import 'package:flutter/material.dart';

import '../flashcard.dart';
import 'card_face.dart';
import 'flip_card.dart';

class FlashcardSurface extends StatelessWidget {
  const FlashcardSurface({
    super.key,
    required this.card,
    this.textScale = 1.0,
    required this.isBookmarked,
    required this.completed,
    this.onBookmarkTap,
    this.onCompletedTap,
  });

  final Flashcard card;
  final double textScale;

  // 追加プロパティ
  final bool isBookmarked;
  final bool completed;
  final VoidCallback? onBookmarkTap;
  final VoidCallback? onCompletedTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);

    // 既存の TextScaler に UI の textScale を乗算して合成
    final base = mq.textScaler; // 端末 or アプリの元スケール
    final factor = base.scale(1.0); // 実スケール係数
    final combined = TextScaler.linear(factor * textScale);

    return MediaQuery(
      data: mq.copyWith(textScaler: combined),
      child: FlipCard(
        front: CardFace(
          key: const ValueKey('front'),
          isBookmarked: isBookmarked,
          onBookmarkTap: onBookmarkTap,
          completed: completed,
          onCompletedTap: onCompletedTap,
          child: Text(
            card.front,
            textAlign: TextAlign.left,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        back: CardFace(
          key: const ValueKey('back'),
          isBookmarked: isBookmarked,
          onBookmarkTap: onBookmarkTap,
          completed: completed,
          onCompletedTap: onCompletedTap,
          child: Text(
            card.back,
            textAlign: TextAlign.left,
            style: theme.textTheme.headlineSmall,
          ),
        ),
      ),
    );
  }
}
