// lib/features/decks/deck_list_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/purchase/purchase_service.dart';
import '../../data/local/hive_deck_repository.dart';
import '../../data/remote/remote_deck_repository.dart';
import '../../shared/widgets/ad_banner.dart';
import '../flashcards/flashcard.dart';
import '../flashcards/flashcard_page.dart';
import 'deck.dart';
import 'scan_import_page.dart';
import 'widgets/deck_tile.dart';
import 'widgets/empty_view.dart';
import 'widgets/error_view.dart';
import 'widgets/list_loading.dart';
import 'widgets/scan_intro_dialog.dart';
// import 'package:cloud_functions/cloud_functions.dart';

/// 設定メニューの項目
enum SettingsAction {
  import,
  purchasePro,
  // // TODO
  // GCFtest,
}

/// 仮バナーの高さ
const double _kAdBannerHeight = 60;

/// 広告表示有無：Proならfalseに
bool _adsEnabled = false;

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

  final _auth = AuthService();
  User? _user;
  late final Stream<User?> _authStream;

  // 課金
  late final PurchaseService _purchase;

  bool _loading = true;
  String? _error;
  List<Deck> _decks = [];

  @override
  void initState() {
    super.initState();

    // 課金サービスの監視（init自体はmain()で実行済み想定）
    _purchase = PurchaseService.instance;
    _purchase.addListener(_onPurchaseChanged);

    // v7 AuthService 側で initialize 済みにしてあるのでここは監視だけでOK
    _authStream = _auth.authStateChanges;
    _authStream.listen((u) {
      if (!mounted) return;
      setState(() => _user = u);
    });
    // 任意：未ログインなら匿名で入れておくとUXがよい
    _auth.signInAnonymouslyIfNeeded();

    _load();
  }

  @override
  void dispose() {
    _purchase.removeListener(_onPurchaseChanged);
    super.dispose();
  }

  void _onPurchaseChanged() {
    if (!mounted) return;
    setState(() {
      // UI再描画だけでOK（isProは_build内で参照）
    });
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
      final localCards = remoteCards
          .map((c) => c.copyWith(deckId: localDeckId))
          .toList();

      // 4) 保存（集計もsave内で反映）
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
      messenger.showSnackBar(SnackBar(content: Text('取り込みに失敗: $e')));
    } finally {
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
    final isPro = _purchase.isPro;
    _adsEnabled = !isPro;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('単語帳一覧', style: TextStyle(fontSize: 28)),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              tooltip: '設定とツール',
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppColors.border),
        ),
      ),
      endDrawer: _SettingsDrawer(
        user: _user,
        isPro: isPro,
        // isPro: false,
        onSelected: (a) => _onSelect(context, a),
      ),
      bottomNavigationBar: _adsEnabled
          ? AdBannerPlaceholder(
              onTap: () => ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('（仮）広告がタップされました'))),
            )
          : null,
      body: _buildBody(),
    );
  }

  void _onSelect(BuildContext context, SettingsAction action) async {
    Navigator.of(context).pop(); // endDrawer を閉じる
    switch (action) {
      case SettingsAction.import:
        _scanAndImport(context);
        break;
      case SettingsAction.purchasePro:
        await _handlePurchasePro();
        break;
      //   // TODO テスト疎通OK
      // case SettingsAction.GCFtest:
      //   await _handleRestore();
      //   final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast1');
      //   final result = await functions.httpsCallable('hello').call();
      //   print(result.data);
      //   break;
    }
  }

  Future<void> _handlePurchasePro() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await _purchase.buyPro();
      // 付与はストリーム経由で反映。必要ならトーストを追加。
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('購入エラー: $e')));
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Widget _buildBody() {
    if (_loading) return const ListLoading();
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _reload);
    }
    if (_decks.isEmpty) return const EmptyView();

    return RefreshIndicator(
      onRefresh: _reload,
      child: ReorderableListView.builder(
        padding: EdgeInsets.only(
          bottom: 24 + (_adsEnabled ? _kAdBannerHeight : 0),
        ),
        buildDefaultDragHandles: false,
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
                      title: const Text('削除しますか？'),
                      content: Text('「${deck.title}」を端末から削除します。'),
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
      await Navigator.of(context).push(
        slideFromRight(
          FlashcardPage(
            deck: deck,
            cards: cards,
            repo: _localRepo, // ← 追加
          ),
        ),
      );
      await _reload();
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

class _SettingsDrawer extends StatelessWidget {
  const _SettingsDrawer({
    required this.onSelected,
    required this.user,
    required this.isPro,
  });

  final void Function(SettingsAction) onSelected;
  final User? user;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    // 実装では 残回数 は Firestore/RemoteConfig から取得する想定
    final int remainingImports = 8;

    final isSignedIn = user != null && !(user!.isAnonymous);
    final photoUrl = user?.photoURL;
    final displayName =
        user?.displayName ??
        (isSignedIn ? 'Googleユーザー' : (isPro ? 'ログインしてください' : 'ゲスト'));
    final email = user?.email ?? (isSignedIn ? '' : '未ログイン');

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          children: [
            // ヘッダー（プラン状態）
            ListTile(
              leading: Icon(isPro ? Icons.workspace_premium : Icons.lock),
              title: Text(isPro ? 'Proプラン' : '無料プラン'),
              subtitle: Text(
                isPro ? '有効期限：2026年10月22日' : '今月のインポート残り：$remainingImports/10回',
              ),
            ),
            const Divider(),
            // 操作メニュー
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('単語帳インポート'),
              subtitle: const Text('QR/カメラで単語帳をインポート'),
              onTap: () => onSelected(SettingsAction.import),
            ),
            if (!isPro) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.shopping_bag),
                title: const Text('Proプランを購入'),
                subtitle: const Text('インポート上限解除＆広告非表示'),
                onTap: () => onSelected(SettingsAction.purchasePro),
              ),
            ],
            const SizedBox(height: 16),
            // // TODO テスト　↓
            // const Divider(),
            // ListTile(
            //   leading: Icon(Icons.access_time),
            //   title: Text('GCFテスト'),
            //   onTap: () => onSelected(SettingsAction.GCFtest),
            // ),
            // // TODO テスト　↑
          ],
        ),
      ),
    );
  }
}
