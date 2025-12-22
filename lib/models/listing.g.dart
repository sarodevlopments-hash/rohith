// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'listing.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ListingAdapter extends TypeAdapter<Listing> {
  @override
  final int typeId = 3;

  @override
  Listing read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Listing(
      name: fields[0] as String,
      sellerName: fields[1] as String,
      price: fields[2] as double,
      originalPrice: fields[3] as double?,
      quantity: fields[4] as int,
      type: fields[5] as SellType,
      fssaiLicense: fields[6] as String?,
      preparedAt: fields[7] as DateTime?,
      expiryDate: fields[8] as DateTime?,
      category: fields[9] as FoodCategory,
      cookedFoodSource: fields[10] as CookedFoodSource?,
    );
  }

  @override
  void write(BinaryWriter writer, Listing obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.sellerName)
      ..writeByte(2)
      ..write(obj.price)
      ..writeByte(3)
      ..write(obj.originalPrice)
      ..writeByte(4)
      ..write(obj.quantity)
      ..writeByte(5)
      ..write(obj.type)
      ..writeByte(6)
      ..write(obj.fssaiLicense)
      ..writeByte(7)
      ..write(obj.preparedAt)
      ..writeByte(8)
      ..write(obj.expiryDate)
      ..writeByte(9)
      ..write(obj.category)
      ..writeByte(10)
      ..write(obj.cookedFoodSource);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
