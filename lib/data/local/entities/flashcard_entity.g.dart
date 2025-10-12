// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flashcard_entity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FlashcardEntityAdapter extends TypeAdapter<FlashcardEntity> {
  @override
  final int typeId = 2;

  @override
  FlashcardEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FlashcardEntity(
      id: fields[0] as String,
      deckId: fields[1] as String,
      front: fields[2] as String,
      back: fields[3] as String,
      isKnown: fields[4] as bool,
      isBookmarked: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, FlashcardEntity obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.deckId)
      ..writeByte(2)
      ..write(obj.front)
      ..writeByte(3)
      ..write(obj.back)
      ..writeByte(4)
      ..write(obj.isKnown)
      ..writeByte(5)
      ..write(obj.isBookmarked);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlashcardEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
