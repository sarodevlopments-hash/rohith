// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seller_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SellerProfileAdapter extends TypeAdapter<SellerProfile> {
  @override
  final int typeId = 7;

  @override
  SellerProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SellerProfile(
      sellerName: fields[0] as String,
      fssaiLicense: fields[1] as String,
      cookedFoodSource: fields[2] as CookedFoodSource?,
      defaultFoodType: fields[3] as SellType?,
      sellerId: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SellerProfile obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.sellerName)
      ..writeByte(1)
      ..write(obj.fssaiLicense)
      ..writeByte(2)
      ..write(obj.cookedFoodSource)
      ..writeByte(3)
      ..write(obj.defaultFoodType)
      ..writeByte(4)
      ..write(obj.sellerId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SellerProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
