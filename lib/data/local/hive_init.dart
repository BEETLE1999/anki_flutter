// import 'package:hive_flutter/hive_flutter.dart';
// import 'entities/deck_entity.dart';
// import 'entities/flashcard_entity.dart';
//
// class HiveBoxes {
//   static const decks = 'decks';
//   static const cards = 'cards';
// }
//
// Future<void> initHive() async {
//   await Hive.initFlutter();
//   if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(DeckEntityAdapter());
//   if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(FlashcardEntityAdapter());
//   await Future.wait([
//     Hive.openBox<DeckEntity>(HiveBoxes.decks),
//     Hive.openBox<FlashcardEntity>(HiveBoxes.cards),
//   ]);
// }
// lib/data/local/hive_init.dart
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'entities/deck_entity.dart';
import 'entities/flashcard_entity.dart';

class HiveBoxes {
  static const decks = 'decks';
  static const cards = 'cards';
}

Future<void> initHive() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // ★ アダプタ登録（typeIdの重複登録を避けるためガード）
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(DeckEntityAdapter()); // ← DeckEntity の typeId と一致
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(
      FlashcardEntityAdapter(),
    ); // ← FlashcardEntity の typeId と一致
  }

  // ★ 型付きで open（ここ重要。型なし open と混在させない）
  await Hive.openBox<DeckEntity>(HiveBoxes.decks);
  await Hive.openBox<FlashcardEntity>(HiveBoxes.cards);
}
