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

/// Firestore `imports/{importId}`（一時置き場）から取得 → アプリ用モデルへマップ → 削除まで担当
class DeckRepository {
  final _db = FirebaseFirestore.instance;

  /// まとめて Import メタ＋カードを取得（内部利用）
  Future<(ImportMeta, List<ImportCard>)> fetchImport(String importId) async {
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

  /// DeckListPage 用：デッキ本体のみ（カード数を反映）
  Future<Deck> fetchDeck(String deckId) async {
    final (meta, cards) = await fetchImport(deckId);
    return Deck(
      id: meta.id,
      title: meta.deckTitle,
      description: meta.description,
      cardCount: cards.length,
      updatedAt: meta.updatedAt ?? DateTime.now(), // なければ現在時刻で補完
    );
  }

  /// DeckListPage 用：カード一覧
  Future<List<Flashcard>> fetchCards(String deckId) async {
    final (_, importCards) = await fetchImport(deckId);
    return importCards
        .map(
          (c) =>
              Flashcard(id: c.id, deckId: deckId, front: c.front, back: c.back),
        )
        .toList();
  }

  /// 取り込み完了後に一時データを削除
  Future<void> deleteDeck(String deckId) async {
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

  // --- helpers ---
  DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}
