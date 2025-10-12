// lib/features/flashcards/flashcard_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_enum.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local/hive_deck_repository.dart';
import '../decks/deck.dart';
import 'flashcard.dart';
import 'widgets/flashcard_bottom_nav.dart';
import 'widgets/flashcard_surface.dart';
import 'widgets/progress_bar_with_controls.dart';

class FlashcardPage extends StatefulWidget {
  const FlashcardPage({
    super.key,
    required this.deck,
    required this.cards,
    required this.repo,
  });

  final Deck deck;
  final List<Flashcard> cards;
  final HiveDeckRepository repo;

  @override
  State<FlashcardPage> createState() => _FlashcardPageState();
}

class _FlashcardPageState extends State<FlashcardPage> {
  int index = 0;
  double _textScale = 1.0;
  late List<Flashcard> _cards;
  CardFilter filter = CardFilter.all;
  late CarouselController _carouselController;
  static const _kTextScaleKey = 'flashcard.textScale';
  SharedPreferences? _prefs;

  // デッキ別の再開ポイント保存キー
  String get _resumeKey => 'flashcard.resume.${widget.deck.id}';

  @override
  void initState() {
    super.initState();
    _cards = List.of(widget.cards);
    _carouselController = CarouselController(initialItem: index);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getDouble(_kTextScaleKey);
    setState(() {
      _prefs = p;
      if (saved != null) _textScale = saved.clamp(0.5, 1.3);
    });
    // 初回フレーム後に“続きから”を提示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeOfferResume();
    });
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  List<Flashcard> get _filteredCards {
    switch (filter) {
      case CardFilter.unread:
        return _cards.where((c) => !c.isKnown).toList();
      case CardFilter.bookmarked:
        return _cards.where((c) => c.isBookmarked).toList();
      case CardFilter.all:
        return _cards;
    }
  }

  // フィルタ後の長さに合わせて index を安全化
  int get _safeIndex {
    final total = _filteredCards.length;
    if (total == 0) return 0;
    return index.clamp(0, total - 1);
  }

  void _prev() {
    final total = _filteredCards.length;
    if (_safeIndex > 0) {
      final nextIdx = (_safeIndex - 1).clamp(0, total - 1);
      setState(() => index = nextIdx);
      _carouselController.animateToItem(nextIdx);
      _saveResumePoint();
    }
  }

  void _next() {
    final total = _filteredCards.length;
    if (_safeIndex < total - 1) {
      final nextIdx = (_safeIndex + 1).clamp(0, total - 1);
      setState(() => index = nextIdx);
      _carouselController.animateToItem(nextIdx);
      _saveResumePoint();
    }
  }

  Future<void> _toggleBookmark(Flashcard card) async {
    final i = _cards.indexWhere((x) => x.id == card.id);
    if (i < 0) return;

    final newVal = !card.isBookmarked;
    setState(() {
      _cards[i] = card.copyWith(isBookmarked: newVal);
      index = _safeIndex; // フィルタで外れても安全
    });

    await widget.repo.updateCardFlagsAndDeckStats(
      deckId: widget.deck.id,
      cardId: card.id,
      isBookmarked: newVal,
    );
    _saveResumePoint();
  }

  Future<void> _toggleKnown(Flashcard card) async {
    final i = _cards.indexWhere((x) => x.id == card.id);
    if (i < 0) return;

    final newVal = !card.isKnown;
    setState(() {
      _cards[i] = card.copyWith(isKnown: newVal);
      index = _safeIndex;
    });

    await widget.repo.updateCardFlagsAndDeckStats(
      deckId: widget.deck.id,
      cardId: card.id,
      isKnown: newVal,
    );
    _saveResumePoint();
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
            IconButton(
              tooltip: '文字サイズ',
              onPressed: _openSettings,
              icon: const Icon(Icons.format_size),
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, thickness: 1, color: AppColors.border),
          ),
        ),
        body: Center(
          child: Text(switch (filter) {
            CardFilter.unread => '未完了のカードはありません',
            CardFilter.bookmarked => 'ブックマークしたカードはありません',
            _ => 'カードがありません',
          }),
        ),
        bottomNavigationBar: FlashcardBottomNav(
          filter: filter,
          onChanged: (f) => setState(() {
            filter = f;
            index = 0;
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
            tooltip: '文字サイズ',
            onPressed: _openSettings,
            icon: const Icon(Icons.format_size),
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
                    final isFromCarousel =
                        n.metrics.axis == Axis.horizontal && n.depth == 0;

                    if (isFromCarousel) {
                      final estimated = (n.metrics.pixels / itemExtent)
                          .round()
                          .clamp(0, total - 1);
                      if (estimated != index) {
                        setState(() => index = estimated);
                        _saveResumePoint();
                      }
                    }
                    return false; // 伝播は止めない
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
                            isBookmarked: c.isBookmarked,
                            completed: c.isKnown,
                            onBookmarkTap: () => _toggleBookmark(c),
                            onCompletedTap: () => _toggleKnown(c),
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
                _saveResumePoint();
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
            _carouselController = CarouselController(initialItem: 0);
          });
          _saveResumePoint();
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
                          min: 0.5,
                          max: 1.3,
                          divisions: 8, // 0.1刻み
                          value: _textScale,
                          label: _textScale.toStringAsFixed(1),
                          onChanged: (v) {
                            // ボトムシート側の即時プレビュー
                            setInner(() => _textScale = v);
                            // ページ全体にも反映
                            setState(() {});
                          },
                          onChangeEnd: (v) async {
                            // 永続化（デバウンス目的でここで保存）
                            await _prefs?.setDouble(_kTextScaleKey, v);
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

  // 現在位置を永続化（cardId 優先、index も保険で保存）
  Future<void> _saveResumePoint() async {
    if (_prefs == null) return;
    final cards = _filteredCards;
    if (cards.isEmpty) return;
    final current = cards[_safeIndex];
    final payload = jsonEncode({
      'cardId': current.id,
      'index': _safeIndex,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    await _prefs!.setString(_resumeKey, payload);
  }

  // 保存済みの cardId / index を読む（同期関数）
  ({String? cardId, int? index}) _loadResumePointSync() {
    final raw = _prefs?.getString(_resumeKey);
    if (raw == null) return (cardId: null, index: null);
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return (
        cardId: map['cardId'] as String?,
        index: (map['index'] as num?)?.toInt(),
      );
    } catch (_) {
      return (cardId: null, index: null);
    }
  }

  // SnackBarで“続きから”を提示し、押されたらジャンプ
  Future<void> _maybeOfferResume() async {
    final saved = _loadResumePointSync();
    if (saved.cardId == null && saved.index == null) return;

    int? target;
    final cards = _filteredCards;
    if (cards.isEmpty) return;

    if (saved.cardId != null) {
      final i = cards.indexWhere((c) => c.id == saved.cardId);
      if (i >= 0) target = i;
    }
    target ??= (saved.index != null)
        ? saved.index!.clamp(0, cards.length - 1)
        : null;

    if (target == null) return;
    // すでに同じ位置ならSnackBarを提示しない
    if (target == _safeIndex) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('前回の続きから再開しますか？'),
        action: SnackBarAction(
          label: '続きから',
          onPressed: () {
            setState(() => index = target!);
            _carouselController.animateToItem(target!);
          },
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }
}
