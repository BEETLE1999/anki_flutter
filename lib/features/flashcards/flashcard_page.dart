// lib/features/flashcards/flashcard_page.dart
import 'package:flutter/material.dart';
import '../decks/deck.dart';
import 'flashcard.dart';
import 'widgets/flip_card.dart';

class FlashcardPage extends StatefulWidget {
  const FlashcardPage({
    super.key,
    required this.deck,
    required this.cards,
  });

  final Deck deck;
  final List<Flashcard> cards;

  @override
  State<FlashcardPage> createState() => _FlashcardPageState();
}

class _FlashcardPageState extends State<FlashcardPage> {
  int index = 0;
  int known = 0;
  int unknown = 0;
  // スワイプ判定用
  static const _swipeThreshold = 90.0;

  void _next({required bool markKnown}) {
    setState(() {
      if (markKnown) {
        known++;
      } else {
        unknown++;
      }
      if (index < widget.cards.length - 1) {
        index++;
      } else {
        _showResult();
      }
    });
  }

  void _showResult() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final total = widget.cards.length;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24 + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flag_circle, size: 48),
              const SizedBox(height: 8),
              Text('学習完了', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('合計 $total 枚 / 既知 $known / 要復習 $unknown'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          index = 0;
                          known = 0;
                          unknown = 0;
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('もう一度'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check),
                      label: const Text('閉じる'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.cards[index];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deck.title),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('${index + 1}/${widget.cards.length}'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            children: [
              // 進捗バー
              LinearProgressIndicator(
                value: (index + 1) / widget.cards.length,
                minHeight: 6,
              ),
              const SizedBox(height: 16),

              // カード（タップで反転、スワイプで既知/未知）
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Dismissible(
                      key: ValueKey(card.id),
                      direction: DismissDirection.horizontal,
                      dismissThresholds: const {
                        DismissDirection.startToEnd: 0.2,
                        DismissDirection.endToStart: 0.2,
                      },
                      onUpdate: (details) {
                        // しきい値超え時に軽くバイブ等（必要なら）
                      },
                      onDismissed: (direction) {
                        final isKnown =
                            direction == DismissDirection.startToEnd;
                        _next(markKnown: isKnown);
                      },
                      background: _SwipeBg(
                        icon: Icons.thumb_up_alt,
                        alignLeft: true,
                        label: 'わかった',
                      ),
                      secondaryBackground: const _SwipeBg(
                        icon: Icons.replay_circle_filled,
                        alignLeft: false,
                        label: '要復習',
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.92,
                            maxHeight: constraints.maxHeight * 0.8,
                          ),
                          child: _FlashcardSurface(
                            front: card.front,
                            back: card.back,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ボタン操作（左右スワイプと同じ）
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _next(markKnown: false),
                      icon: const Icon(Icons.replay),
                      label: const Text('要復習'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _next(markKnown: true),
                      icon: const Icon(Icons.thumb_up),
                      label: const Text('わかった'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlashcardSurface extends StatelessWidget {
  const _FlashcardSurface({required this.front, required this.back});

  final String front;
  final String back;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FlipCard(
      front: _CardFace(
        key: const ValueKey('front'),
        child: Text(
          front,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
      ),
      back: _CardFace(
        key: const ValueKey('back'),
        child: Text(
          back,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: child),
      ),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  const _SwipeBg({
    required this.icon,
    required this.alignLeft,
    required this.label,
  });

  final IconData icon;
  final bool alignLeft;
  final String label;

  @override
  Widget build(BuildContext context) {
    final align =
    alignLeft ? Alignment.centerLeft : Alignment.centerRight;
    final pad = alignLeft
        ? const EdgeInsets.only(left: 20)
        : const EdgeInsets.only(right: 20);

    return Container(
      alignment: align,
      padding: pad,
      color: alignLeft
          ? Colors.green.withOpacity(0.15)
          : Colors.orange.withOpacity(0.15),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!alignLeft) Text(label),
          const SizedBox(width: 8),
          Icon(icon),
          if (alignLeft) ...[
            const SizedBox(width: 8),
            Text(label),
          ],
        ],
      ),
    );
  }
}
