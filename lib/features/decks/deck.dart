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
}
