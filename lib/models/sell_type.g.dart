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
        return SellType.clothingAndApparel;
      case 4:
        return SellType.liveKitchen;
      case 5:
        return SellType.electronics;
      case 6:
        return SellType.electricals;
      case 7:
        return SellType.hardware;
      case 8:
        return SellType.automobiles;
      case 9:
        return SellType.others;
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
      case SellType.clothingAndApparel:
        writer.writeByte(3);
        break;
      case SellType.liveKitchen:
        writer.writeByte(4);
        break;
      case SellType.electronics:
        writer.writeByte(5);
        break;
      case SellType.electricals:
        writer.writeByte(6);
        break;
      case SellType.hardware:
        writer.writeByte(7);
        break;
      case SellType.automobiles:
        writer.writeByte(8);
        break;
      case SellType.others:
        writer.writeByte(9);
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
