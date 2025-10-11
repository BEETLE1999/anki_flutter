// features/flashcards/flashcard.dart
class Flashcard {
  final String id;
  final String deckId;
  final String front;
  final String back;

  Flashcard({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
  });

  Flashcard copyWith({
    String? id,
    String? deckId,
    String? front,
    String? back,
  }) {
    return Flashcard(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      front: front ?? this.front,
      back: back ?? this.back,
    );
  }
}
