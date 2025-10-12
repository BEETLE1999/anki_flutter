import 'package:hive/hive.dart';
import '../../../features/flashcards/flashcard.dart';

part 'flashcard_entity.g.dart';

@HiveType(typeId: 2)
class FlashcardEntity extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String deckId;

  @HiveField(2)
  String front;

  @HiveField(3)
  String back;

  @HiveField(4)
  bool isKnown;

  @HiveField(5)
  bool isBookmarked;

  FlashcardEntity({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    this.isKnown = false,
    this.isBookmarked = false,
  });

  // モデル → エンティティ
  factory FlashcardEntity.fromModel(Flashcard c) => FlashcardEntity(
    id: c.id,
    deckId: c.deckId,
    front: c.front,
    back: c.back,
    isKnown: c.isKnown,
    isBookmarked: c.isBookmarked,
  );

  // エンティティ → モデル
  Flashcard toModel() => Flashcard(
    id: id,
    deckId: deckId,
    front: front,
    back: back,
    isKnown: isKnown,
    isBookmarked: isBookmarked,
  );
}
