// lib/features/decks/remote_deck_repository.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/decks/deck.dart';
import '../../features/flashcards/flashcard.dart';

/// 親メタ（imports_active/{uid}）
class ActiveImportMeta {
  ActiveImportMeta({
    required this.uid,
    required this.deckTitle,
    this.description = '',
    this.cardCount = 0,
    this.expiresAt,
    this.claimed = false,
    this.nonce,
    this.updatedAt,
  });

  final String uid;
  final String deckTitle;
  final String description;
  final int cardCount;
  final DateTime? expiresAt;
  final bool claimed;
  final String? nonce;
  final DateTime? updatedAt;
}

/// 子カード（imports_active/{uid}/cards/{cardId}）
class ActiveImportCard {
  ActiveImportCard({
    required this.id,
    required this.front,
    required this.back,
    required this.order,
  });

  final String id;
  final String front;
  final String back;
  final int order;
}

/// 新仕様：`imports_active/{uid}` から読み取り
/// - QRは `impi:{uid}` または `impi:{uid}:{nonce}`
/// - 期限・claimed・nonce を検証してから取り込む
class DeckRepository {
  final _db = FirebaseFirestore.instance;

  // ===== Public API ==========================================================

  /// DeckListPage 用：デッキ本体のみ
  /// - [uid] と任意の [nonce] を渡す
  /// - 期限/claimed/nonce を検証してから Deck を返す
  Future<Deck> fetchActiveDeck({required String uid, String? nonce}) async {
    final (meta, cards) = await _fetchActive(uid: uid, nonce: nonce);
    return Deck(
      id: meta.uid,
      title: meta.deckTitle,
      description: meta.description,
      cardCount: cards.length,
      updatedAt: meta.updatedAt ?? DateTime.now(),
    );
  }

  /// DeckListPage 用：カード一覧
  Future<List<Flashcard>> fetchActiveCards({
    required String uid,
    String? nonce,
  }) async {
    final (meta, cards) = await _fetchActive(uid: uid, nonce: nonce);
    return cards
        .map(
          (c) => Flashcard(
            id: c.id,
            deckId: meta.uid,
            front: c.front,
            back: c.back,
          ),
        )
        .toList();
  }

  /// 取り込み完了印：claimed=true にする（推奨）
  Future<void> claimActiveImport({required String uid}) async {
    final ref = _db.collection('imports_active').doc(uid);
    await ref.update({
      'claimed': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 便利関数：QR文字列（`impi:{uid}` / `impi:{uid}:{nonce}`）から取り込む
  Future<(Deck, List<Flashcard>)> fetchFromQr(String qrText) async {
    final p = parseImportQr(qrText);
    if (p == null) {
      throw Exception('QRの形式が正しくありません（impi:{uid}[:{nonce}]）');
    }
    final deck = await fetchActiveDeck(uid: p.$1, nonce: p.$2);
    final cards = await fetchActiveCards(uid: p.$1, nonce: p.$2);
    return (deck, cards);
  }

  // ===== Internal ============================================================

  /// imports_active/{uid} のメタと cards を取得し、期限/claimed/nonce を検証
  Future<(ActiveImportMeta, List<ActiveImportCard>)> _fetchActive({
    required String uid,
    String? nonce,
  }) async {
    final parentRef = _db.collection('imports_active').doc(uid);
    final parentSnap = await parentRef.get();
    if (!parentSnap.exists) {
      throw Exception('imports_active/$uid が見つかりません');
    }
    final m = parentSnap.data()!;

    final meta = ActiveImportMeta(
      uid: parentSnap.id,
      deckTitle: (m['deckTitle'] ?? '') as String,
      description: (m['description'] ?? '') as String,
      cardCount: (m['cardCount'] ?? 0) as int,
      expiresAt: _toDateTime(m['expiresAt']),
      claimed: (m['claimed'] ?? false) as bool,
      nonce: (m['nonce'] as String?)?.trim().isEmpty == true
          ? null
          : (m['nonce'] as String?),
      updatedAt: _toDateTime(m['updatedAt']),
    );

    // 1) 期限
    if (meta.expiresAt != null && DateTime.now().isAfter(meta.expiresAt!)) {
      throw Exception('このQRは期限切れです（${meta.expiresAt}）');
    }
    // 2) claimed
    if (meta.claimed == true) {
      throw Exception('このQRは既に使用済みです');
    }
    // 3) nonce（アプリ側がnonceを持っている場合のみ検証）
    if (nonce != null && nonce.isNotEmpty) {
      if (meta.nonce == null || meta.nonce != nonce) {
        throw Exception('このQRは無効です（nonce不一致）');
      }
    }

    // 子カード取得（orderでソート）
    final cardsSnap = await parentRef
        .collection('cards')
        .orderBy('order')
        .get();
    final cards = cardsSnap.docs.map((d) {
      final c = d.data();
      return ActiveImportCard(
        id: d.id,
        front: (c['front'] ?? '') as String,
        back: (c['back'] ?? '') as String,
        order: (c['order'] ?? 0) as int,
      );
    }).toList();

    // メタのcardCountと実数がズレていても致命ではないため例外にはしない

    return (meta, cards);
  }

  // ===== Helpers =============================================================

  /// `impi:{uid}` または `impi:{uid}:{nonce}` を (uid, nonce?) に分解
  (String, String?)? parseImportQr(String raw) {
    final text = raw.trim().replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    if (!text.startsWith('impi:')) return null;
    final parts = text.split(':'); // ["impi", "uid", "nonce?"]
    if (parts.length < 2) return null;
    final uid = parts[1].trim();
    if (uid.isEmpty) return null;
    final nonce = parts.length >= 3 ? parts[2].trim() : null;
    return (uid, (nonce?.isEmpty ?? true) ? null : nonce);
  }

  DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}
