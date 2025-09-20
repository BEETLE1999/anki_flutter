// lib/features/decks/remote_deck_repository.dart
import 'dart:async';

import '../../features/decks/deck.dart';

/// 後で Firestore 実装に差し替える想定のリポジトリ
class DeckRepository {
  /// 疑似ネットワーク遅延を入れて雰囲気出す（後で削除OK）
  Future<List<Deck>> fetchDecks() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return [
      Deck(
        id: 'ja-en-basic',
        title: '英単語 基本300',
        description: '中学レベルの基本英単語',
        cardCount: 300,
        updatedAt: DateTime(2025, 9, 10, 12, 30),
      ),
      Deck(
        id: 'it-terms',
        title: 'IT用語 100',
        description: 'プログラマー向け用語集',
        cardCount: 100,
        updatedAt: DateTime(2025, 9, 12, 9, 0),
      ),
      Deck(
        id: 'toeic-600',
        title: 'TOEIC 600対策',
        description: 'Part5中心の重要語',
        cardCount: 180,
        updatedAt: DateTime(2025, 9, 12, 8, 20),
      ),
    ];
  }
}
