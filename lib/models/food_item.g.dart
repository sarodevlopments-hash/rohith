// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FoodItemAdapter extends TypeAdapter<FoodItem> {
  @override
  final int typeId = 1;

  @override
  FoodItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FoodItem(
      name: fields[0] as String,
      price: fields[1] as String,
      originalPrice: fields[2] as String,
      shop: fields[3] as String,
      sellerName: fields[4] as String,
      quantity: fields[5] as int,
      expiryTime: fields[6] as DateTime,
      soldCount: fields[7] as int,
      totalRevenue: fields[8] as int,
    );
  }

  @override
  void write(BinaryWriter writer, FoodItem obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.price)
      ..writeByte(2)
      ..write(obj.originalPrice)
      ..writeByte(3)
      ..write(obj.shop)
      ..writeByte(4)
      ..write(obj.sellerName)
      ..writeByte(5)
      ..write(obj.quantity)
      ..writeByte(6)
      ..write(obj.expiryTime)
      ..writeByte(7)
      ..write(obj.soldCount)
      ..writeByte(8)
      ..write(obj.totalRevenue);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
