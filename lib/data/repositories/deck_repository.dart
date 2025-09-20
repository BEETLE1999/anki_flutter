import '../../features/decks/deck.dart';
import '../../features/flashcards/flashcard.dart';

abstract class DeckRepository {
  Future<void> saveDeckWithCards(Deck deck, List<Flashcard> cards);
  Future<List<Deck>> fetchDecks();
  Future<List<Flashcard>> fetchCardsByDeckId(String deckId);
  Future<void> deleteDeck(String deckId); // 任意
}
