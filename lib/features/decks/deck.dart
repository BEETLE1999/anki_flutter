// lib/features/decks/deck.dart
class Deck {
  final String id;
  final String title;
  final String description;
  final int cardCount;
  final DateTime updatedAt;
  final int? sortIndex;
  final int knownCount;
  final int bookmarkCount;

  const Deck({
    required this.id,
    required this.title,
    required this.description,
    required this.cardCount,
    required this.updatedAt,
    this.sortIndex,
    this.knownCount = 0,
    this.bookmarkCount = 0,
  });

  double get progressRate =>
      cardCount == 0 ? 0 : (knownCount / cardCount * 100);

  Deck copyWith({
    String? id,
    String? title,
    String? description,
    int? cardCount,
    DateTime? updatedAt,
    int? sortIndex,
    int? knownCount,
    int? bookmarkCount,
  }) {
    return Deck(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      cardCount: cardCount ?? this.cardCount,
      updatedAt: updatedAt ?? this.updatedAt,
      sortIndex: sortIndex ?? this.sortIndex,
      knownCount: knownCount ?? this.knownCount,
      bookmarkCount: bookmarkCount ?? this.bookmarkCount,
    );
  }
}
