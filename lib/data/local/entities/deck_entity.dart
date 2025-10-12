// lib/data/local/entities/deck_entity.dart
import 'package:hive/hive.dart';

part 'deck_entity.g.dart';

@HiveType(typeId: 1)
class DeckEntity extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  int cardCount;

  @HiveField(3)
  String description;

  @HiveField(4)
  DateTime updatedAt;

  @HiveField(5)
  int? sortIndex;

  DeckEntity({
    required this.id,
    required this.title,
    required this.cardCount,
    required this.description,
    required this.updatedAt,
    this.sortIndex,
  });
}
