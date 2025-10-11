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

// 追加: QR結果を正規化するキー
class ImportKey {
  final String uid;
  final String? nonce; // ない場合も許容
  const ImportKey(this.uid, this.nonce);
}

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
    _future = _localRepo.fetchDecks();
  }

  Future<void> _reload() async {
    final next = _localRepo.fetchDecks();
    setState(() => _future = next);
    await next;
  }

  Future<void> _importAndOpen(ImportKey key) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1) リモート取得（imports_active/{uid}）
      final remoteDeck = await _remoteRepo.fetchActiveDeck(
        uid: key.uid,
        nonce: key.nonce,
      );
      final remoteCards = await _remoteRepo.fetchActiveCards(
        uid: key.uid,
        nonce: key.nonce,
      );

      // 2) ローカル専用の新IDを採番（nonceがあれば優先利用して可読性UP）
      final localDeckId = _makeLocalDeckId(srcUid: key.uid, nonce: key.nonce);

      // 3) deck.id / card.deckId をローカルIDへ差し替え
      final localDeck = remoteDeck.copyWith(id: localDeckId);
      final localCards = remoteCards
          .map((c) => c.copyWith(deckId: localDeckId))
          .toList();

      // 4) ローカル保存（同じ deckId が存在しないので “一掃→上書き”は別デッキに影響しない）
      await _localRepo.saveDeckWithCards(localDeck, localCards);

      // 5) リモートは “受け取り済み”に（削除せず claimed=true 推奨）
      await _remoteRepo.claimActiveImport(uid: key.uid);

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

  /// ローカル専用のデッキIDを作る（例: 'dk_<uid>_<nonce>' or 'dk_<base36time>_<rand>'）
  String _makeLocalDeckId({required String srcUid, String? nonce}) {
    // nonceがあるならそれを使うと“1回の発行＝1つのID”になって可読性が高い
    if (nonce != null && nonce.isNotEmpty) {
      return 'dk_${srcUid}_$nonce';
    }
    // nonceが無い場合は衝突しない短い一意IDを作る
    final t = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final r = (DateTime.now().microsecondsSinceEpoch % 0xFFFF)
        .toRadixString(36)
        .padLeft(4, '0');
    return 'dk_$t$r';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('単語帳一覧', style: TextStyle(fontSize: 28)),
        actions: [
          IconButton(
            tooltip: 'インポート',
            onPressed: () => _scanAndImport(context),
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
  Future<void> _scanAndImport(BuildContext context) async {
    // 1) 説明ダイアログ
    final proceed = await ScanIntroDialog.show(context);
    if (proceed != true) return;
    if (!context.mounted) return;

    // 2) カメラ起動（従来どおり文字列を返すと想定）
    final qrText = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const ScanImportPage()));
    if (qrText == null || qrText.isEmpty) return;

    // 3) QR文字列を解析（impi:{uid}[:{nonce}]）
    final key = _parseImportQr(qrText);
    if (key == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('QRの形式が正しくありません')));
      return;
    }

    // 4) 取り込み
    await _importAndOpen(key);
  }

  // 追加: impi:{uid}[:{nonce}] の形式に対応する簡易パーサ
  ImportKey? _parseImportQr(String qrText) {
    // 許容: "impi:uid", "impi:uid:nonce"
    if (!qrText.startsWith('impi:')) return null;
    final parts = qrText.split(':'); // ["impi", "uid", "nonce?"]
    if (parts.length < 2) return null;
    final uid = parts[1].trim();
    if (uid.isEmpty) return null;
    final nonce = parts.length >= 3 ? parts[2].trim() : null;
    return ImportKey(uid, (nonce?.isEmpty ?? true) ? null : nonce);
  }
}
