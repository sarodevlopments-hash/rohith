// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clothing_category.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ClothingCategoryAdapter extends TypeAdapter<ClothingCategory> {
  @override
  final int typeId = 18;

  @override
  ClothingCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ClothingCategory.men;
      case 1:
        return ClothingCategory.women;
      case 2:
        return ClothingCategory.baby;
      case 3:
        return ClothingCategory.boy;
      case 4:
        return ClothingCategory.girl;
      case 5:
        return ClothingCategory.unisex;
      default:
        return ClothingCategory.men;
    }
  }

  @override
  void write(BinaryWriter writer, ClothingCategory obj) {
    switch (obj) {
      case ClothingCategory.men:
        writer.writeByte(0);
        break;
      case ClothingCategory.women:
        writer.writeByte(1);
        break;
      case ClothingCategory.baby:
        writer.writeByte(2);
        break;
      case ClothingCategory.boy:
        writer.writeByte(3);
        break;
      case ClothingCategory.girl:
        writer.writeByte(4);
        break;
      case ClothingCategory.unisex:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClothingCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
