// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sell_type.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SellTypeAdapter extends TypeAdapter<SellType> {
  @override
  final int typeId = 4;

  @override
  SellType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SellType.cookedFood;
      case 1:
        return SellType.groceries;
      case 2:
        return SellType.vegetables;
      case 3:
        return SellType.medicine;
      default:
        return SellType.cookedFood;
    }
  }

  @override
  void write(BinaryWriter writer, SellType obj) {
    switch (obj) {
      case SellType.cookedFood:
        writer.writeByte(0);
        break;
      case SellType.groceries:
        writer.writeByte(1);
        break;
      case SellType.vegetables:
        writer.writeByte(2);
        break;
      case SellType.medicine:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SellTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
