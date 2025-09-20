// lib/data/local/mappers/deck_mapper.dart
import '../../../features/decks/deck.dart';
import '../entities/deck_entity.dart';

extension DeckEntityMapper on DeckEntity {
  Deck toModel() => Deck(
    id: id,
    title: title,
    cardCount: cardCount,
    description: description,
    updatedAt: updatedAt,
  );
}

extension DeckModelMapper on Deck {
  DeckEntity toEntity() => DeckEntity(
    id: id,
    title: title,
    cardCount: cardCount,
    description: description,
    updatedAt: updatedAt,
  );
}
