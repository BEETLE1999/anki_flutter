// // lib/features/decks/remote_deck_repository.dart
// import 'dart:async';
// import 'package:cloud_firestore/cloud_firestore.dart';
//
// import '../../features/decks/deck.dart';
// import '../../features/flashcards/flashcard.dart';
//
// class ImportMeta {
//   ImportMeta({
//     required this.id,
//     required this.deckTitle,
//     this.description = '',
//     this.updatedAt,
//   });
//
//   final String id;
//   final String deckTitle;
//   final String description;
//   final DateTime? updatedAt;
// }
//
// class ImportCard {
//   ImportCard({
//     required this.id,
//     required this.front,
//     required this.back,
//     required this.order,
//   });
//
//   final String id;
//   final String front;
//   final String back;
//   final int order;
// }
//
// /// Firestore `imports/{importId}`（一時置き場）から取得 → アプリ用モデルへマップ → 削除まで担当
// class DeckRepository {
//   final _db = FirebaseFirestore.instance;
//
//   /// まとめて Import メタ＋カードを取得（内部利用）
//   Future<(ImportMeta, List<ImportCard>)> fetchImport(String importId) async {
//     final metaRef = _db.collection('imports').doc(importId);
//     final metaSnap = await metaRef.get();
//     if (!metaSnap.exists) {
//       throw Exception('Import not found: $importId');
//     }
//     final metaData = metaSnap.data()!;
//
//     final meta = ImportMeta(
//       id: metaSnap.id,
//       deckTitle: (metaData['deckTitle'] ?? '') as String,
//       description: (metaData['description'] ?? '') as String,
//       updatedAt: _toDateTime(metaData['updatedAt']),
//     );
//
//     final cardsSnap = await metaRef.collection('cards').orderBy('order').get();
//
//     final cards = cardsSnap.docs.map((d) {
//       final m = d.data();
//       return ImportCard(
//         id: d.id,
//         front: (m['front'] ?? '') as String,
//         back: (m['back'] ?? '') as String,
//         order: (m['order'] ?? 0) as int,
//       );
//     }).toList();
//
//     return (meta, cards);
//   }
//
//   /// DeckListPage 用：デッキ本体のみ（カード数を反映）
//   Future<Deck> fetchDeck(String deckId) async {
//     final (meta, cards) = await fetchImport(deckId);
//     return Deck(
//       id: meta.id,
//       title: meta.deckTitle,
//       description: meta.description,
//       cardCount: cards.length,
//       updatedAt: meta.updatedAt ?? DateTime.now(), // なければ現在時刻で補完
//     );
//   }
//
//   /// DeckListPage 用：カード一覧
//   Future<List<Flashcard>> fetchCards(String deckId) async {
//     final (_, importCards) = await fetchImport(deckId);
//     return importCards
//         .map(
//           (c) =>
//               Flashcard(id: c.id, deckId: deckId, front: c.front, back: c.back),
//         )
//         .toList();
//   }
//
//   /// 取り込み完了後に一時データを削除
//   Future<void> deleteDeck(String deckId) async {
//     final metaRef = _db.collection('imports').doc(deckId);
//     final cardsRef = metaRef.collection('cards');
//
//     final batch = _db.batch();
//
//     final cards = await cardsRef.get();
//     for (final doc in cards.docs) {
//       batch.delete(doc.reference);
//     }
//     batch.delete(metaRef);
//
//     await batch.commit();
//   }
//
//   // --- helpers ---
//   DateTime? _toDateTime(dynamic v) {
//     if (v == null) return null;
//     if (v is Timestamp) return v.toDate();
//     if (v is DateTime) return v;
//     return null;
//   }
// }
// lib/features/decks/remote_deck_repository.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/decks/deck.dart';
import '../../features/flashcards/flashcard.dart';

class ImportMeta {
  ImportMeta({
    required this.id,
    required this.deckTitle,
    this.description = '',
    this.updatedAt,
  });

  final String id;
  final String deckTitle;
  final String description;
  final DateTime? updatedAt;
}

class ImportCard {
  ImportCard({
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

/// Firestore `imports/{importId}`（一時置き場）
/// ・QRの“impc:CODE”や短縮コードも受け取りOKに
/// ・まず importId を解決してから取得/削除する
class DeckRepository {
  final _db = FirebaseFirestore.instance;

  // --- パブリックAPI ------------------------------------------------------

  /// DeckListPage 用：デッキ本体のみ（カード数を反映）
  Future<Deck> fetchDeck(String codeOrId) async {
    final deckId = await _resolveDeckId(codeOrId);
    final (meta, cards) = await _fetchImport(deckId);
    return Deck(
      id: meta.id,
      title: meta.deckTitle,
      description: meta.description,
      cardCount: cards.length,
      updatedAt: meta.updatedAt ?? DateTime.now(), // なければ現在時刻で補完
    );
  }

  /// DeckListPage 用：カード一覧
  Future<List<Flashcard>> fetchCards(String codeOrId) async {
    final deckId = await _resolveDeckId(codeOrId);
    final (_, importCards) = await _fetchImport(deckId);
    return importCards
        .map(
          (c) =>
              Flashcard(id: c.id, deckId: deckId, front: c.front, back: c.back),
        )
        .toList();
  }

  /// 取り込み完了後に一時データを削除（サーバ側の一時置き場を掃除）
  Future<void> deleteDeck(String codeOrId) async {
    final deckId = await _resolveDeckId(codeOrId);
    final metaRef = _db.collection('imports').doc(deckId);
    final cardsRef = metaRef.collection('cards');

    final batch = _db.batch();

    final cards = await cardsRef.get();
    for (final doc in cards.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(metaRef);

    await batch.commit();
  }

  // --- 内部: 入力の正規化 & importId 解決 ----------------------------------

  /// ユーザー入力/QR文字列を正規化（不可視文字除去、`impc:`/URL/JSON からID/コード抽出）
  String _normalize(String raw) {
    final text = raw.trim().replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');

    // impc:SHORTCODE / impc://SHORTCODE
    final mImpc = RegExp(
      r'^impc:(?://)?([A-Za-z0-9_-]{4,64})$',
    ).firstMatch(text);
    if (mImpc != null) return mImpc.group(1)!;

    // プレーン（短縮コードも許容）
    final plain = RegExp(r'^[A-Za-z0-9_-]{4,64}$');
    if (plain.hasMatch(text)) return text;

    // URL: https://.../import/<id> or ?id=...
    final uri = Uri.tryParse(text);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final segs = uri.pathSegments;
      final idx = segs.indexOf('import');
      if (idx >= 0 && idx + 1 < segs.length) {
        final cand = segs[idx + 1];
        if (plain.hasMatch(cand)) return cand;
      }
      final qp = uri.queryParameters['id'] ?? uri.queryParameters['deckId'];
      if (qp != null && plain.hasMatch(qp)) return qp;
    }

    // カスタムスキーム全般: scheme://...?id=xxx
    if (uri != null && uri.scheme.isNotEmpty) {
      final qp = uri.queryParameters['id'] ?? uri.queryParameters['deckId'];
      if (qp != null && plain.hasMatch(qp)) return qp;
    }

    // JSON埋め込み {"id":"xxxx"}
    final mJson = RegExp(
      r'"id"\s*:\s*"([A-Za-z0-9_-]{4,64})"',
    ).firstMatch(text);
    if (mJson != null) return mJson.group(1)!;

    // 見つからなければ生のまま返す（後段でNotFoundにする）
    return text;
  }

  /// 入力（短縮コード or importId）から **実際の importId** を取得
  /// 1) そのまま `imports/{id}` が存在すれば importId
  /// 2) ダメなら `import_codes/{code}` → フィールド importId を参照（短縮コード解決）
  // Future<String> _resolveDeckId(String codeOrId) async {
  //   final key = _normalize(codeOrId);
  //
  //   // 1) 直接 imports/{key} が存在するか？
  //   final direct = await _db.collection('imports').doc(key).get();
  //   if (direct.exists) return key;
  //
  //   // 2) 短縮コードの可能性: import/{key} に importId が入っている想定
  //   // final codeDoc = await _db.collection('import_codes').doc(key).get();
  //   final codeDoc = await _db.collection('imports').doc(key).get();
  //   if (codeDoc.exists) {
  //     final data = codeDoc.data()!;
  //     final importId = (data['importId'] ?? data['id'] ?? data['deckId']) as String?;
  //     if (importId != null && importId.isNotEmpty) return importId;
  //   }
  //
  //   // 必要なら別名コレクションも順番に試せる（例: 'imports_codes', 'shortcodes'）
  //   // final alt = await _db.collection('imports_codes').doc(key).get();
  //   // ...
  //
  //   throw Exception('Import not found (code/id: $key)');
  // }
  Future<String> _resolveDeckId(String codeOrId) async {
    final key = _normalize(codeOrId);

    // 1) 直接 imports/{key} があるならそれを importId とみなす
    try {
      final codeDoc = await _db.collection('codes').doc(key).get();
      if (codeDoc.exists) {
        final data = codeDoc.data(); // Map<String, dynamic>?
        // ★ フィールド名は docId（fallbackで importId / id / deckId も見る）
        final importId =
            (data?['docId'] ??
                    data?['importId'] ??
                    data?['id'] ??
                    data?['deckId'])
                as String?;

        // 期限チェック（あれば）
        final expiresAt = _toDateTime(data?['expiresAt']);
        if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
          throw Exception('このコードは期限切れです (expired at $expiresAt)');
        }

        if (importId != null && importId.isNotEmpty) {
          // 念のため imports/{importId} が本当にあるか確認
          final importSnap = await _db
              .collection('imports')
              .doc(importId)
              .get();
          if (!importSnap.exists) {
            throw Exception('imports/$importId が見つかりません');
          }
          return importId;
        }
        throw Exception('codes/$key に importId(docId) がありません');
      }
    } catch (e, st) {
      // 開発中はログ出すと原因が追いやすい
      // debugPrint('codes/$key read failed: $e\n$st');
      rethrow; // ここで握りつぶすより上に流す方がデバッグしやすい
    }
    throw Exception('Import not found (code/id: $key)');
  }

  // --- 内部: FirestoreからImportメタ+カード一括取得 ------------------------

  Future<(ImportMeta, List<ImportCard>)> _fetchImport(String importId) async {
    final metaRef = _db.collection('imports').doc(importId);
    final metaSnap = await metaRef.get();
    if (!metaSnap.exists) {
      throw Exception('Import not found: $importId');
    }
    final metaData = metaSnap.data()!;

    final meta = ImportMeta(
      id: metaSnap.id,
      deckTitle: (metaData['deckTitle'] ?? '') as String,
      description: (metaData['description'] ?? '') as String,
      updatedAt: _toDateTime(metaData['updatedAt']),
    );

    final cardsSnap = await metaRef.collection('cards').orderBy('order').get();
    final cards = cardsSnap.docs.map((d) {
      final m = d.data();
      return ImportCard(
        id: d.id,
        front: (m['front'] ?? '') as String,
        back: (m['back'] ?? '') as String,
        order: (m['order'] ?? 0) as int,
      );
    }).toList();

    return (meta, cards);
  }

  // --- helpers -------------------------------------------------------------

  DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}
