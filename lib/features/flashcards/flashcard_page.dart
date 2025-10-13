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
  // ---- 状態 ------------------------------------------------------------------
  int index = 0;
  double _textScale = 1.0;
  late List<Flashcard> _cards;
  CardFilter filter = CardFilter.all;

  static const _kTextScaleKey = 'flashcard.textScale';
  SharedPreferences? _prefs;

  // PageView 用
  late PageController _pageController;
  bool _isAnimating = false; // 二重アニメ防止

  // デッキ別の再開ポイント保存キー（「すべて」フィルタ専用で使う）
  String get _resumeKey => 'flashcard.resume.${widget.deck.id}';

  // 「すべて」のときのみ進捗保存する
  bool get _isPersistentFilter => filter == CardFilter.all;

  // ---- ライフサイクル --------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _cards = List.of(widget.cards);
    _pageController = PageController(initialPage: index);
    _loadPrefs();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getDouble(_kTextScaleKey);
    setState(() {
      _prefs = p;
      if (saved != null) _textScale = saved.clamp(0.5, 1.3);
    });
    // 初回フレーム後に“続きから”を提示（「すべて」のときのみ、ボトムシート）
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _maybeOfferResumeViaSheet();
    });
  }

  // ---- データ／フィルタ -------------------------------------------------------
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

  // ---- コントローラ同期ヘルパ -------------------------------------------------
  void _syncControllerToIndex({bool animate = false}) {
    final cards = _filteredCards;
    if (cards.isEmpty) return;
    final to = _safeIndex;
    if (!_pageController.hasClients) return;

    if (animate) {
      if (_isAnimating) return;
      _isAnimating = true;
      _pageController
          .animateToPage(
            to,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() => _isAnimating = false);
    } else {
      _pageController.jumpToPage(to);
    }
  }

  // ---- ナビゲーション（アニメ含む） -------------------------------------------
  Future<void> _goTo(int target) async {
    final cards = _filteredCards;
    if (cards.isEmpty) return;
    final to = target.clamp(0, cards.length - 1);
    if (_isAnimating || to == index) return;

    _isAnimating = true;
    try {
      await _pageController.animateToPage(
        to,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      if (_isPersistentFilter) _saveResumePoint();
    } finally {
      _isAnimating = false;
    }
  }

  void _prev() {
    if (_safeIndex <= 0) return;
    _goTo(_safeIndex - 1);
  }

  void _next() {
    final total = _filteredCards.length;
    if (_safeIndex >= total - 1) return;
    _goTo(_safeIndex + 1);
  }

  // ---- トグル操作 ------------------------------------------------------------
  Future<void> _toggleBookmark(Flashcard card) async {
    final i = _cards.indexWhere((x) => x.id == card.id);
    if (i < 0) return;

    final newVal = !card.isBookmarked;
    setState(() {
      _cards[i] = card.copyWith(isBookmarked: newVal);
      index = _safeIndex; // フィルタで外れても安全
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncControllerToIndex(animate: false);
    });

    await widget.repo.updateCardFlagsAndDeckStats(
      deckId: widget.deck.id,
      cardId: card.id,
      isBookmarked: newVal,
    );

    if (_isPersistentFilter) _saveResumePoint();
  }

  Future<void> _toggleKnown(Flashcard card) async {
    final i = _cards.indexWhere((x) => x.id == card.id);
    if (i < 0) return;

    final newVal = !card.isKnown;
    setState(() {
      _cards[i] = card.copyWith(isKnown: newVal);
      index = _safeIndex;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncControllerToIndex(animate: false);
    });

    await widget.repo.updateCardFlagsAndDeckStats(
      deckId: widget.deck.id,
      cardId: card.id,
      isKnown: newVal,
    );

    if (_isPersistentFilter) _saveResumePoint();
  }

  // ---- ビルド -----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final cards = _filteredCards;
    final total = cards.length;

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
          onChanged: (f) async {
            // 同じタブを再タップしたら何もしない
            if (f == filter) return;
            setState(() {
              filter = f;
              index = 0; // 切替時は常に1枚目へ
            });
            // 表示を0ページへ即時同期（PageViewは無いが統一のため）
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _syncControllerToIndex(animate: false);
            });
            // 「すべて」に入った直後に再開案内（ボトムシート）
            if (_isPersistentFilter) {
              await _maybeOfferResumeViaSheet();
            }
          },
        ),
      );
    }

    final platform = Theme.of(context).platform;
    final physics = platform == TargetPlatform.iOS
        ? const BouncingScrollPhysics()
        : const ClampingScrollPhysics();

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
            // --- ページ本体 ---
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
                child: PageView.builder(
                  controller: _pageController,
                  physics: physics,
                  pageSnapping: true,
                  onPageChanged: (i) {
                    if (i != index) {
                      setState(() => index = i);
                      if (_isPersistentFilter) _saveResumePoint();
                    }
                  },
                  itemCount: total,
                  itemBuilder: (context, i) {
                    final visible = (i == index);
                    return TickerMode(
                      enabled: visible,
                      child: RepaintBoundary(
                        child: Center(
                          child: FlashcardSurface(
                            card: cards[i],
                            textScale: _textScale,
                            isBookmarked: cards[i].isBookmarked,
                            completed: cards[i].isKnown,
                            onBookmarkTap: () => _toggleBookmark(cards[i]),
                            onCompletedTap: () => _toggleKnown(cards[i]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // --- プログレス／コントロール ---
            ProgressBarWithControls(
              index: _safeIndex,
              total: total,
              onPrev: _prev,
              onNext: _next,
              onChanged: (i) => _goTo(i),
            ),
          ],
        ),
      ),

      // --- フィルタタブ ---
      bottomNavigationBar: FlashcardBottomNav(
        filter: filter,
        onChanged: (f) async {
          // 同じタブを再タップしたら何もしない
          if (f == filter) return;
          setState(() {
            filter = f;
            index = 0; // ★ 切替時は常に1枚目へ
          });
          // 再ビルド後に表示を0ページへ即時同期
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _syncControllerToIndex(animate: false);
          });

          // 「すべて」に切り替えたときだけ、ボトムシートで続き案内
          if (_isPersistentFilter) {
            await _maybeOfferResumeViaSheet();
          }
        },
      ),
    );
  }

  // ---- 設定ボトムシート ------------------------------------------------------
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
                          divisions: 8,
                          value: _textScale,
                          label: _textScale.toStringAsFixed(1),
                          onChanged: (v) {
                            setInner(() => _textScale = v);
                            setState(() {});
                          },
                          onChangeEnd: (v) async {
                            await _prefs?.setDouble(_kTextScaleKey, v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---- 再開ポイントの保存・読込（「すべて」限定） ------------------------------
  Future<void> _saveResumePoint() async {
    if (_prefs == null) return;
    if (!_isPersistentFilter) return;
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

  int? _computeResumeTargetIndex() {
    final saved = _loadResumePointSync();
    if (saved.cardId == null && saved.index == null) return null;

    final cards = _filteredCards;
    if (cards.isEmpty) return null;

    // cardId を優先して復元
    if (saved.cardId != null) {
      final i = cards.indexWhere((c) => c.id == saved.cardId);
      if (i >= 0) return i;
    }
    if (saved.index != null) {
      return saved.index!.clamp(0, cards.length - 1);
    }
    return null;
  }

  // 「続きから」案内（ボトムシート）
  Future<void> _offerResumeSheet(int target) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '前回の続きから再開しますか？',
                // style: Theme.of(context).textTheme.titleLarge,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text('前回位置： ${target + 1}/${_filteredCards.length}'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(), // 1枚目のまま
                      child: const Text('1枚目から'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _goTo(target);
                      },
                      child: const Text('続きから'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  // 初期表示／フィルタ切替直後に呼ぶ：ボトムシートで続き案内（「すべて」限定）
  Future<void> _maybeOfferResumeViaSheet() async {
    if (!_isPersistentFilter) return;
    final target = _computeResumeTargetIndex();
    if (target == null) return;
    if (target == _safeIndex) return; // すでにその位置なら不要（初期が1枚目でない場合など）

    // 一旦「常に1枚目へ」の仕様で index=0 にしているので、target != 0 のときのみ案内
    if (target != 0) {
      await _offerResumeSheet(target);
    }
  }
}
