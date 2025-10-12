// features/flashcards/flashcard.dart
class Flashcard {
  final String id;
  final String deckId;
  final String front;
  final String back;
  final bool isKnown;
  final bool isBookmarked;

  Flashcard({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    this.isKnown = false,
    this.isBookmarked = false,
  });

  Flashcard copyWith({
    String? id,
    String? deckId,
    String? front,
    String? back,
    bool? isKnown,
    bool? isBookmarked,
  }) {
    return Flashcard(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      front: front ?? this.front,
      back: back ?? this.back,
      isKnown: isKnown ?? this.isKnown,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }
}
