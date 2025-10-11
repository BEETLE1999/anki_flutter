// lib/features/decks/deck.dart
class Deck {
  final String id;
  final String title;
  final String description;
  final int cardCount;
  final DateTime updatedAt;

  const Deck({
    required this.id,
    required this.title,
    required this.description,
    required this.cardCount,
    required this.updatedAt,
  });

  Deck copyWith({
    String? id,
    String? title,
    String? description,
    int? cardCount,
    DateTime? updatedAt,
  }) {
    return Deck(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      cardCount: cardCount ?? this.cardCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
