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

  // ---- Create/Upsert --------------------------------------------------------
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

    // 2) カード一括 put（キー＝"<deckId>:<cardId>"）
    if (cards.isNotEmpty) {
      final batch = <String, FlashcardEntity>{};
      for (final c in cards) {
        final ent = c.toEntity(); // ent.deckId は c.deckId を反映
        final localKey = '${c.deckId}:${c.id}'; // 衝突しない複合キー
        batch[localKey] = ent;
      }
      await cardBox.putAll(batch);
    }

    // 3) 集計して Deck に反映（一覧表示の高速化用）
    final total = cards.length;
    final known = cards.where((c) => c.isKnown).length; // ← 修正
    final bookmarks = cards.where((c) => c.isBookmarked).length; // ← 修正

    final updatedDeck = deck.copyWith(
      cardCount: total,
      knownCount: known,
      bookmarkCount: bookmarks,
      updatedAt: DateTime.now(), // 必要なら更新
    );

    // 4) デッキ upsert（キー＝deck.id）
    await deckBox.put(updatedDeck.id, updatedDeck.toEntity());
  }

  // ---- Read -----------------------------------------------------------------
  /// デッキ一覧（未設定は末尾に寄せ、同順位はタイトルで安定ソート）
  Future<List<Deck>> fetchDecksOrdered() async {
    final deckBox = await _openDeckBox();
    final list = deckBox.values.map((e) => e.toModel()).toList();

    list.sort((a, b) {
      final ai = a.sortIndex ?? 1 << 30;
      final bi = b.sortIndex ?? 1 << 30;
      if (ai != bi) return ai.compareTo(bi);
      return a.title.compareTo(b.title);
    });
    return list;
  }

  /// 既存互換：順序未考慮の生リスト
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

  // ---- Update (order) -------------------------------------------------------
  /// 並び順の保存：渡された順で 0..N の sortIndex を振り直して永続化
  Future<void> updateDeckOrder(List<Deck> decksInOrder) async {
    final deckBox = await _openDeckBox();
    for (var i = 0; i < decksInOrder.length; i++) {
      final d = decksInOrder[i];
      final updated = d.copyWith(sortIndex: i); // Deck に sortIndex 前提
      await deckBox.put(updated.id, updated.toEntity());
    }
  }

  // ---- Delete ---------------------------------------------------------------
  /// デッキ本体と関連カードを一括削除
  Future<void> deleteDeckAndCards(String deckId) async {
    final deckBox = await _openDeckBox();
    final cardBox = await _openCardBox();

    // デッキ削除
    await deckBox.delete(deckId);

    // 紐づくカード削除（valueの deckId で判定）
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

  /// 既存互換API：内部で deleteDeckAndCards を呼ぶ
  Future<void> deleteDeck(String deckId) => deleteDeckAndCards(deckId);

  // ---- Update (flags + deck stats) -----------------------------------------
  /// 単一カードの既知/ブクマフラグを更新し、Deck の集計値を差分更新
  Future<void> updateCardFlagsAndDeckStats({
    required String deckId,
    required String cardId,
    bool? isKnown,
    bool? isBookmarked,
  }) async {
    final cardBox = await _openCardBox();
    final deckBox = await _openDeckBox();

    final key = '$deckId:$cardId';
    final ent = cardBox.get(key);
    if (ent == null) return;

    final prevKnown = ent.isKnown;
    final prevBm = ent.isBookmarked;

    // 1) カード更新
    if (isKnown != null) ent.isKnown = isKnown;
    if (isBookmarked != null) ent.isBookmarked = isBookmarked;
    await cardBox.put(key, ent);

    // 2) デッキ差分集計
    final deckEnt = deckBox.get(deckId);
    if (deckEnt != null) {
      var knownDelta = 0;
      if (isKnown != null && isKnown != prevKnown) {
        knownDelta = isKnown ? 1 : -1;
      }
      var bookmarkDelta = 0;
      if (isBookmarked != null && isBookmarked != prevBm) {
        bookmarkDelta = isBookmarked ? 1 : -1;
      }
      deckEnt
        ..knownCount = deckEnt.knownCount + knownDelta
        ..bookmarkCount = deckEnt.bookmarkCount + bookmarkDelta
        ..updatedAt = DateTime.now();
      await deckBox.put(deckId, deckEnt);
    }
  }
}
