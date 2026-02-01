// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'size_color_combination.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SizeColorCombinationAdapter extends TypeAdapter<SizeColorCombination> {
  @override
  final int typeId = 19;

  @override
  SizeColorCombination read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SizeColorCombination(
      size: fields[0] as String,
      availableColors: (fields[1] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, SizeColorCombination obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.size)
      ..writeByte(1)
      ..write(obj.availableColors);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SizeColorCombinationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
