// lib/features/decks/deck_list_page.dart
import 'package:flutter/material.dart';

import '../../data/local/hive_deck_repository.dart';
import '../../data/remote/remote_deck_repository.dart';
import '../flashcards/flashcard.dart';
import '../flashcards/flashcard_page.dart';
import 'deck.dart';
import 'widgets/deck_tile.dart';

class DeckListPage extends StatefulWidget {
  const DeckListPage({super.key});

  @override
  State<DeckListPage> createState() => _DeckListPageState();
}

class _DeckListPageState extends State<DeckListPage> {
  final _repo = HiveDeckRepository(); // 一覧表示もローカルから
  late Future<List<Deck>> _future;
  final _localRepo = HiveDeckRepository(); // ★ ローカル保存用を追加
  final _remoteRepo = DeckRepository(); // ★ ローカル保存用を追加

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchDecks();
  }

  Future<void> _reload() async {
    final next = _repo.fetchDecks();
    setState(() => _future = next);
    await next;
  }

  // 取り込みダイアログを出す
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
      // 1) Firestore から Deck と Cards を直接取得
      final deck = await _remoteRepo.fetchDeck(deckId);
      final cards = await _remoteRepo.fetchCards(deckId);

      // 2) ローカル保存
      await _localRepo.saveDeckWithCards(deck, cards);

      // 3) Firestoreから削除（仕様どおり）
      await _remoteRepo.deleteDeck(deckId);

      // 4) 一覧更新
      setState(() {
        _future = _localRepo.fetchDecks();
      });

      if (!mounted) return;
      Navigator.of(context).pop();

    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('取り込みに失敗: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('暗記帳'),
      // ),
      appBar: AppBar(
        title: const Text('暗記帳'),
        actions: [
          IconButton(
            tooltip: 'Import ID から取り込み',
            onPressed: _promptImportId,
            icon: const Icon(Icons.download),
          ),
        ],
      ),
      body: RefreshIndicator(
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
                return DeckTile(
                  deck: deck,
                  onTap: () => _openDeck(deck), // ← ここだけにする
                );
              },
            );
          },
        ),
      ),
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: () {
      //     // TODO: 新規デッキ作成（後で実装：インポート or 手入力）
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       const SnackBar(content: Text('新規作成（後で実装）')),
      //     );
      //   },
      //   icon: const Icon(Icons.add),
      //   label: const Text('新規'),
      // ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _promptImportId,
        icon: const Icon(Icons.download),
        label: const Text('取り込み'),
      ),
    );
  }

  Future<void> _openDeck(Deck deck) async {
    // ローディング表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // TODO: 実装に合わせて置き換え
      // 例) final cards = await FlashcardRepository().fetchByDeckId(deck.id);
      final cards = await _fetchCardsFor(deck);

      if (!mounted) return;
      Navigator.of(context).pop(); // ローディングを閉じる

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FlashcardPage(deck: deck, cards: cards),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // ローディングを閉じる
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('カードの読み込みに失敗: $e')));
    }
  }

  Future<List<Flashcard>> _fetchCardsFor(Deck deck) async {
    return _localRepo.fetchCardsByDeckId(deck.id);
  }
}

class ListLoading extends StatelessWidget {
  const ListLoading({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: 6,
      itemBuilder: (context, i) => const _Shimmer(),
    );
  }
}

class _Shimmer extends StatelessWidget {
  const _Shimmer();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Container(height: 76),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 80),
        Center(child: Text('デッキがありません')),
      ],
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Text(message)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('再読み込み'),
            ),
          ],
        ),
      ],
    );
  }
}
