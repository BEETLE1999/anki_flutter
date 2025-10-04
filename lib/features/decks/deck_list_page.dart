// lib/features/decks/deck_list_page.dart

import 'package:anki_flutter/features/decks/scan_import_page.dart';
import 'package:anki_flutter/features/decks/widgets/scan_intro_dialog.dart';
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

  @override
  void initState() {
    super.initState();
    // いつでもローカルを表示
    _future = _localRepo.fetchDecks();
  }

  Future<void> _reload() async {
    final next = _localRepo.fetchDecks();
    setState(() => _future = next);
    await next;
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('取り込みに失敗: $e')));
      }
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('単語帳', style: TextStyle(fontSize: 28)),
        actions: [
          IconButton(
            tooltip: 'インポート',
            onPressed: () => _scanAndImport(context),
            // icon: const Icon(Icons.qr_code_scanner),
            icon: const Icon(Icons.download),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppColors.border),
        ),
      ),
      body: _body(),
    );
  }

  Widget _body() {
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

  /// スキャン → import
  // Future<void> _scanAndImport() async {
  //   final importId = await Navigator.of(
  //     context,
  //   ).push<String>(MaterialPageRoute(builder: (_) => const ScanImportPage()));
  //   if (importId == null || importId.isEmpty) return;
  //
  //   await _importAndOpen(importId);
  // }
  Future<void> _scanAndImport(BuildContext context) async {
    // ダイアログを表示
    final proceed = await ScanIntroDialog.show(context);
    if (proceed != true) return;
    if (!context.mounted) return;
    // カメラ起動
    final importId = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const ScanImportPage()));
    if (importId == null || importId.isEmpty) return;
    await _importAndOpen(importId);
  }
}
