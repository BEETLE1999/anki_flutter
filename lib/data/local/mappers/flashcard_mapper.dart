import '../../../features/flashcards/flashcard.dart';
import '../entities/flashcard_entity.dart';

extension FlashcardEntityMapper on FlashcardEntity {
  Flashcard toModel() => Flashcard(
    id: id,
    front: front,
    back: back,
    deckId: deckId,
  );
}

extension FlashcardModelMapper on Flashcard {
  FlashcardEntity toEntity() => FlashcardEntity(
    id: id,
    deckId: deckId,
    front: front,
    back: back,
  );
}
