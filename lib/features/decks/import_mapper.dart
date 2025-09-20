// // lib/features/decks/import_mapper.dart
// import '../flashcards/flashcard.dart';
// import 'deck.dart';
// import 'imports_service.dart';
//
// ({Deck deck, List<Flashcard> cards}) mapImportToDeck(
//   ImportMeta meta,
//   List<ImportCard> items,
// ) {
//   final deck = Deck(
//     id: meta.id,
//     title: meta.deckTitle,
//     description: meta.description,
//     cardCount: items.length,
//     updatedAt: DateTime.now(),
//   );
//   final cards = items
//       .map(
//         (c) => Flashcard(
//           id: '${meta.id}-${c.order}',
//           deckId: meta.id, // ★ 追加
//           front: c.front,
//           back: c.back,
//         ),
//       )
//       .toList();
//
//   return (deck: deck, cards: cards);
// }
