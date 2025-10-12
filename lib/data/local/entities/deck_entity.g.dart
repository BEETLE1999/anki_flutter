// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deck_entity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DeckEntityAdapter extends TypeAdapter<DeckEntity> {
  @override
  final int typeId = 1;

  @override
  DeckEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DeckEntity(
      id: fields[0] as String,
      title: fields[1] as String,
      cardCount: fields[2] as int,
      description: fields[3] as String,
      updatedAt: fields[4] as DateTime,
      sortIndex: fields[5] as int?,
      knownCount: fields[6] as int,
      bookmarkCount: fields[7] as int,
    );
  }

  @override
  void write(BinaryWriter writer, DeckEntity obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.cardCount)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.updatedAt)
      ..writeByte(5)
      ..write(obj.sortIndex)
      ..writeByte(6)
      ..write(obj.knownCount)
      ..writeByte(7)
      ..write(obj.bookmarkCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeckEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
