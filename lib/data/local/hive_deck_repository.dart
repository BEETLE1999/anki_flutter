// lib/data/local/hive_deck_repository.dart
import 'package:hive/hive.dart';

import '../../features/decks/deck.dart';
import '../../features/flashcards/flashcard.dart';
import 'entities/deck_entity.dart';
import 'entities/flashcard_entity.dart';
import 'hive_init.dart';

// 拡張メソッド（toEntity / toModel）
import 'mappers/deck_mapper.dart';
import 'mappers/flashcard_mapper.dart';

class HiveDeckRepository {
  // ---- Box open helpers -----------------------------------------------------
  Future<Box<DeckEntity>> _openDeckBox() async {
    if (!Hive.isBoxOpen(HiveBoxes.decks)) {
      return Hive.openBox<DeckEntity>(HiveBoxes.decks);
    }
    return Hive.box<DeckEntity>(HiveBoxes.decks);
  }

  Future<Box<FlashcardEntity>> _openCardBox() async {
    if (!Hive.isBoxOpen(HiveBoxes.cards)) {
      return Hive.openBox<FlashcardEntity>(HiveBoxes.cards);
    }
    return Hive.box<FlashcardEntity>(HiveBoxes.cards);
  }

  // ---- API ------------------------------------------------------------------
  Future<void> saveDeckWithCards(Deck deck, List<Flashcard> cards) async {
    final deckBox = await _openDeckBox();
    final cardBox = await _openCardBox();

    // 1) 既存カードを同デッキIDで一掃（keyに依存しない）
    final keysToDelete = cardBox
        .toMap()
        .entries
        .where((e) => e.value.deckId == deck.id)
        .map((e) => e.key)
        .toList();
    if (keysToDelete.isNotEmpty) {
      await cardBox.deleteAll(keysToDelete);
    }

    // 2) デッキ upsert（キー＝deck.id）
    await deckBox.put(deck.id, deck.toEntity());

    // 3) カード一括 put（キー＝"<deckId>:<cardId>" に変更）
    if (cards.isNotEmpty) {
      final batch = <String, FlashcardEntity>{};
      for (final c in cards) {
        final ent = c.toEntity(); // ent.deckId は c.deckId を反映
        final localKey = '${c.deckId}:${c.id}'; // ← 衝突しない複合キー
        batch[localKey] = ent;
      }
      await cardBox.putAll(batch);
    }
  }

  Future<List<Deck>> fetchDecks() async {
    final deckBox = await _openDeckBox();
    return deckBox.values.map((e) => e.toModel()).toList();
  }

  Future<List<Flashcard>> fetchCardsByDeckId(String deckId) async {
    final cardBox = await _openCardBox();
    return cardBox.values
        .where((e) => e.deckId == deckId)
        .map((e) => e.toModel())
        .toList();
  }

  Future<void> deleteDeck(String deckId) async {
    final deckBox = await _openDeckBox();
    final cardBox = await _openCardBox();

    // 1) デッキ削除（キー＝deckIdで保持しているため、探索不要）
    await deckBox.delete(deckId);

    // 2) 紐づくカード削除（keyに依存しない）
    final keysToDelete = cardBox
        .toMap()
        .entries
        .where((e) => e.value.deckId == deckId)
        .map((e) => e.key)
        .toList();
    if (keysToDelete.isNotEmpty) {
      await cardBox.deleteAll(keysToDelete);
    }
  }
}
