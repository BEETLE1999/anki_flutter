// lib/features/flashcards/flashcard_page.dart
import 'package:flutter/material.dart';

import '../../core/constants/app_enum.dart';
import '../../core/theme/app_colors.dart';
import '../decks/deck.dart';
import 'flashcard.dart';
import 'widgets/flashcard_bottom_nav.dart';
import 'widgets/flashcard_surface.dart';
import 'widgets/progress_bar_with_controls.dart';

class FlashcardPage extends StatefulWidget {
  const FlashcardPage({super.key, required this.deck, required this.cards});

  final Deck deck;
  final List<Flashcard> cards;

  @override
  State<FlashcardPage> createState() => _FlashcardPageState();
}

class _FlashcardPageState extends State<FlashcardPage> {
  int index = 0;
  int known = 0;
  int unknown = 0;
  double _textScale = 1.0;

  // 既読・ブックマーク管理（card.id を想定）
  final Set<String> readIds = {};
  final Set<String> bookmarkIds = {};

  CardFilter filter = CardFilter.all;

  // Carousel 用コントローラ（初期表示位置を index に合わせる）
  late CarouselController _carouselController;

  @override
  void initState() {
    super.initState();
    _carouselController = CarouselController(initialItem: index);
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  List<Flashcard> get _filteredCards {
    switch (filter) {
      case CardFilter.unread:
        return widget.cards.where((c) => !readIds.contains(c.id)).toList();
      case CardFilter.bookmarked:
        return widget.cards.where((c) => bookmarkIds.contains(c.id)).toList();
      case CardFilter.all:
      default:
        return widget.cards;
    }
  }

  // フィルタ後の長さに合わせて index を安全化
  int get _safeIndex {
    final total = _filteredCards.length;
    if (total == 0) return 0;
    return index.clamp(0, total - 1);
  }

  Flashcard? get _currentOrNull {
    final cards = _filteredCards;
    if (cards.isEmpty) return null;
    return cards[_safeIndex];
  }

  void _prev() {
    final total = _filteredCards.length;
    if (_safeIndex > 0) {
      final nextIdx = (_safeIndex - 1).clamp(0, total - 1);
      setState(() => index = nextIdx);
      _carouselController.animateToItem(nextIdx);
    }
  }

  void _next() {
    final total = _filteredCards.length;
    if (_safeIndex < total - 1) {
      final nextIdx = (_safeIndex + 1).clamp(0, total - 1);
      setState(() => index = nextIdx);
      _carouselController.animateToItem(nextIdx);
    }
  }

  void _toggleBookmark(String cardId) {
    setState(() {
      if (bookmarkIds.contains(cardId)) {
        bookmarkIds.remove(cardId);
      } else {
        bookmarkIds.add(cardId);
      }
      // フィルタで外れた場合も index は _safeIndex が守ってくれる
      index = _safeIndex;
    });
  }

  void _toggleCompleted(String cardId) {
    setState(() {
      if (readIds.contains(cardId)) {
        readIds.remove(cardId);
      } else {
        readIds.add(cardId);
      }
      // 既読トグルで未読フィルタから外れる可能性があるので安全化
      index = _safeIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cards = _filteredCards;
    final total = cards.length;
    final viewportWidth = MediaQuery.of(context).size.width;
    final itemExtent = viewportWidth * 0.92;

    // フィルタ後カードが 0 の時のプレースホルダ
    if (cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.deck.title, style: const TextStyle(fontSize: 24)),
          centerTitle: true,
          actions: [
            // 空リスト時でも設定は開ける
            IconButton(
              tooltip: '設定',
              onPressed: _openSettings,
              icon: const Icon(Icons.settings),
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, thickness: 1, color: AppColors.border),
          ),
        ),
        body: Center(
          child: Text(switch (filter) {
            CardFilter.unread => '未読のカードはありません',
            CardFilter.bookmarked => 'ブックマークしたカードはありません',
            _ => 'カードがありません',
          }),
        ),
        bottomNavigationBar: FlashcardBottomNav(
          filter: filter,
          onChanged: (f) => setState(() {
            filter = f;
            index = 0;
            // 表示先頭へ
            _carouselController = CarouselController(initialItem: 0);
          }),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deck.title, style: const TextStyle(fontSize: 24)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '設定',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppColors.border),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(width: 1, color: AppColors.border)),
        ),
        child: Column(
          children: [
            // --- カルーセル本体 ---
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
                // Scroll 通知から “現在インデックス” を推定して同期
                child: NotificationListener<ScrollEndNotification>(
                  onNotification: (n) {
                    final metrics = n.metrics;
                    // itemExtent ベースで最寄りのインデックスに丸める
                    final estimated = (metrics.pixels / itemExtent)
                        .round()
                        .clamp(0, total - 1);
                    if (estimated != index) {
                      setState(() => index = estimated);
                    }
                    return false;
                  },
                  child: CarouselView(
                    controller: _carouselController,
                    itemExtent: itemExtent,
                    shrinkExtent: itemExtent,
                    itemSnapping: true,
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    enableSplash: false,
                    children: [
                      for (final c in cards)
                        Center(
                          child: FlashcardSurface(
                            card: c,
                            textScale: _textScale,
                            isBookmarked: bookmarkIds.contains(c.id),
                            completed: readIds.contains(c.id),
                            onBookmarkTap: () => _toggleBookmark(c.id),
                            onCompletedTap: () => _toggleCompleted(c.id),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            ProgressBarWithControls(
              index: _safeIndex,
              total: total,
              onPrev: _prev,
              onNext: _next,
              onChanged: (i) {
                final to = i.clamp(0, total - 1);
                setState(() => index = to);
                _carouselController.animateToItem(to);
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: FlashcardBottomNav(
        filter: filter,
        onChanged: (f) {
          setState(() {
            filter = f;
            index = 0; // タブ切替時は先頭に戻す
            // 先頭から表示（新しい initialItem で作り直すのが確実）
            _carouselController = CarouselController(initialItem: 0);
          });
        },
      ),
    );
  }

  // 設定ボトムシート
  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setInner) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('表示設定', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('カード文字サイズ'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Slider(
                          min: 0.6,
                          max: 1.4,
                          divisions: 8, // 0.1刻み
                          value: _textScale,
                          label: _textScale.toStringAsFixed(1),
                          onChanged: (v) {
                            // ボトムシート側の即時プレビュー
                            setInner(() => _textScale = v);
                            // ページ全体にも反映
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
