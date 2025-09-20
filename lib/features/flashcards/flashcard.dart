// features/flashcards/flashcard.dart
class Flashcard {
  final String id;
  final String deckId; // ← 新しく追加
  final String front;
  final String back;

  Flashcard({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
  });
}
