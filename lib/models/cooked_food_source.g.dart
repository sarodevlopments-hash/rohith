// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cooked_food_source.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CookedFoodSourceAdapter extends TypeAdapter<CookedFoodSource> {
  @override
  final int typeId = 5;

  @override
  CookedFoodSource read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CookedFoodSource.home;
      case 1:
        return CookedFoodSource.restaurant;
      case 2:
        return CookedFoodSource.event;
      default:
        return CookedFoodSource.home;
    }
  }

  @override
  void write(BinaryWriter writer, CookedFoodSource obj) {
    switch (obj) {
      case CookedFoodSource.home:
        writer.writeByte(0);
        break;
      case CookedFoodSource.restaurant:
        writer.writeByte(1);
        break;
      case CookedFoodSource.event:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CookedFoodSourceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
