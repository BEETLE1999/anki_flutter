// lib/features/decks/deck_list_page.dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/local/hive_deck_repository.dart';
import '../../data/remote/remote_deck_repository.dart';
import '../flashcards/flashcard.dart';
import '../flashcards/flashcard_page.dart';
import 'deck.dart';
import 'widgets/deck_tile.dart';
import 'widgets/empty_view.dart';
import 'widgets/error_view.dart';
import 'widgets/list_loading.dart';

class DeckListPage extends StatefulWidget {
  const DeckListPage({super.key});

  @override
  State<DeckListPage> createState() => _DeckListPageState();
}

class _DeckListPageState extends State<DeckListPage> {
  late Future<List<Deck>> _future;
  final _localRepo = HiveDeckRepository();
  final _remoteRepo = DeckRepository();

  // 画面状態（ダミーの認証情報。実装時はFirebase Auth等で置き換え）
  bool _signedIn = false;
  String? _userEmail = 't3n.gathering@gmail.com';

  @override
  void initState() {
    super.initState();
    // ログイン状態に応じて非同期データソースを切り替え
    _future = _signedIn
        ? _localRepo.fetchDecks()
        : Future.value(const <Deck>[]);
  }

  Future<void> _reload() async {
    final next = _localRepo.fetchDecks();
    setState(() => _future = next);
    await next;
  }

  Future<void> _promptImportId() async {
    final controller = TextEditingController();
    final importId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import ID を入力'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '例: AbCDefGhijklMNopQRsT',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (importId == null || importId.isEmpty) return;
    await _importAndOpen(importId);
  }

  Future<void> _importAndOpen(String deckId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final deck = await _remoteRepo.fetchDeck(deckId);
      final cards = await _remoteRepo.fetchCards(deckId);
      await _localRepo.saveDeckWithCards(deck, cards);
      await _remoteRepo.deleteDeck(deckId);

      setState(() {
        _future = _localRepo.fetchDecks();
      });

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('取り込みに失敗: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('単語帳', style: TextStyle(fontSize: 28)),
        actions: [
          // アカウントボタン（ログイン中はダイアログ、未ログインはログイン実行）
          if (_signedIn)
            IconButton(
              tooltip: 'アカウント',
              onPressed: _showAccountDialog,
              icon: const Icon(Icons.account_circle_outlined),
            ),
          // ログイン中のみ取り込みボタン
          if (_signedIn)
            IconButton(
              tooltip: 'Import ID から取り込み',
              onPressed: _promptImportId,
              icon: const Icon(Icons.download),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppColors.border),
        ),
      ),
      body: _signedIn ? _signedInBody() : _signedOutBody(),
    );
  }

  /// ログイン中の一覧表示
  Widget _signedInBody() {
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<Deck>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListLoading();
          }
          if (snapshot.hasError) {
            return ErrorView(message: '読み込みに失敗しました', onRetry: _reload);
          }
          final decks = snapshot.data ?? const <Deck>[];
          if (decks.isEmpty) {
            return const EmptyView();
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: decks.length,
            itemBuilder: (context, i) {
              final deck = decks[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DeckTile(deck: deck, onTap: () => _openDeck(deck)),
              );
            },
          );
        },
      ),
    );
  }

  /// 未ログイン時のプレースホルダー
  Widget _signedOutBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 64,
              color: AppColors.sacredGreen,
            ),
            const SizedBox(height: 12),
            const Text('ログインすると単語帳を表示できます', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('ログイン'),
              onPressed: _login,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDeck(Deck deck) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final cards = await _fetchCardsFor(deck);

      if (!mounted) return;
      Navigator.of(context).pop();

      await Navigator.of(
        context,
      ).push(slideFromRight(FlashcardPage(deck: deck, cards: cards)));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('カードの読み込みに失敗: $e')));
    }
  }

  Future<List<Flashcard>> _fetchCardsFor(Deck deck) async {
    return _localRepo.fetchCardsByDeckId(deck.id);
  }

  Route<T> slideFromRight<T>(Widget page, {Curve curve = Curves.easeOutCubic}) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  // ダミーのログイン・ログアウト（本実装に差し替え）
  Future<void> _login() async {
    setState(() {
      _signedIn = true;
      _userEmail = 't3n.gathering@gmail.com'; // 実装時は認証結果で設定
      _future = _localRepo.fetchDecks(); // ログイン後に一覧ロード
    });
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('ログイン（未実装）')));
  }

  Future<void> _logout() async {
    setState(() {
      _signedIn = false;
      _userEmail = null;
      _future = Future.value(const <Deck>[]); // ログアウト後は空に
    });
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('ログアウト（未実装）')));
  }

  // アカウントダイアログ（メール表示＋ログアウト）
  Future<void> _showAccountDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('アカウント'),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.account_circle_outlined,
                size: 56,
                color: AppColors.sacredGreen,
              ),
              const SizedBox(height: 12),
              Text(_userEmail ?? '(メール未取得)'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '閉じる',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text(
                'ログアウト',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // 先に閉じる
                _logout(); // 既存の処理呼び出し
              },
            ),
          ],
        );
      },
    );
  }
}
