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
  final _localRepo = HiveDeckRepository();
  final _remoteRepo = DeckRepository();

  bool _loading = true;
  String? _error;
  List<Deck> _decks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 並び順つきで取得
      _decks = await _localRepo.fetchDecksOrdered();
    } catch (e) {
      _error = '読み込みに失敗しました: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reload() async {
    await _load();
  }

  Future<void> _importAndOpen(ImportKey key) async {
    // asyncギャップ越しにcontextを使わないため事前キャプチャ
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1) リモート取得
      final remoteDeck = await _remoteRepo.fetchActiveDeck(
        uid: key.uid,
        nonce: key.nonce,
      );
      final remoteCards = await _remoteRepo.fetchActiveCards(
        uid: key.uid,
        nonce: key.nonce,
      );

      // 2) ローカル専用の新ID
      final localDeckId = _makeLocalDeckId(srcUid: key.uid, nonce: key.nonce);

      // 3) ID差し替え
      final localDeck = remoteDeck.copyWith(id: localDeckId);
      final localCards = remoteCards.map((c) => c.copyWith(deckId: localDeckId)).toList();

      // 4) 保存
      await _localRepo.saveDeckWithCards(localDeck, localCards);

      // インポート直後に先頭へ移動して永続化
      final decks = await _localRepo.fetchDecksOrdered();
      final newIdx = decks.indexWhere((d) => d.id == localDeckId);
      if (newIdx != -1 && newIdx != 0) {
        final item = decks.removeAt(newIdx);
        decks.insert(0, item);
        await _localRepo.updateDeckOrder(decks);
      }

      // 5) 受け取り済みに
      await _remoteRepo.claimActiveImport(uid: key.uid);

      // 6) UI更新
      await _reload();
    } catch (e) {
      // context を跨がずに messenger を使用
      messenger.showSnackBar(SnackBar(content: Text('取り込みに失敗: $e')));
    } finally {
      // 事前にキャプチャした navigator で閉じる
      navigator.pop();
    }
  }

  String _makeLocalDeckId({required String srcUid, String? nonce}) {
    if (nonce != null && nonce.isNotEmpty) {
      return 'dk_${srcUid}_$nonce';
    }
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const ListLoading();
    if (_error != null) return ErrorView(message: _error!, onRetry: _reload);
    if (_decks.isEmpty) return const EmptyView();

    return RefreshIndicator(
      onRefresh: _reload,
      child: ReorderableListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        buildDefaultDragHandles: false, // 自前ハンドル
        itemCount: _decks.length,
        onReorder: (oldIndex, newIndex) async {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1; // Flutterの仕様
            final item = _decks.removeAt(oldIndex);
            _decks.insert(newIndex, item);
          });
          try {
            await _localRepo.updateDeckOrder(_decks);
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('順序の保存に失敗: $e')));
            _reload(); // 巻き戻し
          }
        },
        itemBuilder: (context, index) {
          final deck = _decks[index];

          return Dismissible(
            key: ValueKey('deck-${deck.id}'),
            direction: DismissDirection.endToStart,
            background: const SizedBox.shrink(),
            secondaryBackground: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              color: Theme.of(context).colorScheme.error,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (_) async {
              return await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      // clipBehavior: Clip.antiAlias, // ← 角丸に中身をキッチリ合わせる
                      title: const Text('削除しますか？'),
                      content: Text('「${deck.title}」のカードも含めて端末から削除します。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('キャンセル'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onError,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('削除'),
                        ),
                      ],
                    ),
                  ) ??
                  false;
            },
            onDismissed: (_) async {
              final id = deck.id;
              final removedIndex = _decks.indexWhere((d) => d.id == id);
              if (removedIndex == -1) return;
              final removed = _decks[removedIndex];
              final messenger = ScaffoldMessenger.of(context);
              setState(() => _decks.removeAt(removedIndex));
              try {
                await _localRepo.deleteDeckAndCards(id);
                await _localRepo.updateDeckOrder(_decks);
                messenger.showSnackBar(const SnackBar(content: Text('削除しました')));
              } catch (e) {
                setState(() => _decks.insert(removedIndex, removed));
                messenger.showSnackBar(SnackBar(content: Text('削除に失敗: $e')));
              }
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: ReorderableDelayedDragStartListener(
                  index: index,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 先頭アイコンは削除
                      Expanded(
                        child: DeckTile(
                          deck: deck,
                          onTap: () => _openDeck(deck),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final qrText = await navigator.push<String>(
      MaterialPageRoute(builder: (_) => const ScanImportPage()),
    );
    if (qrText == null || qrText.isEmpty) return;

    // 3) QR文字列を解析（impi:{uid}[:{nonce}]）
    final key = _parseImportQr(qrText);
    if (key == null) {
      messenger.showSnackBar(const SnackBar(content: Text('QRの形式が正しくありません')));
      return;
    }

    // 4) 取り込み
    await _importAndOpen(key);
  }

  // 追加: impi:{uid}[:{nonce}] の形式に対応する簡易パーサ
  ImportKey? _parseImportQr(String qrText) {
    if (!qrText.startsWith('impi:')) return null;
    final parts = qrText.split(':'); // ["impi", "uid", "nonce?"]
    if (parts.length < 2) return null;
    final uid = parts[1].trim();
    if (uid.isEmpty) return null;
    final nonce = parts.length >= 3 ? parts[2].trim() : null;
    return ImportKey(uid, (nonce?.isEmpty ?? true) ? null : nonce);
  }
}
