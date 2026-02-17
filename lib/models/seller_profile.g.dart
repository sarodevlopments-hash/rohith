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
      phoneNumber: fields[5] as String,
      pickupLocation: fields[6] as String,
      groceryType: fields[7] as String?,
      sellerType: fields[8] as String?,
      groceryOnboardingCompleted: fields[9] as bool,
      groceryDocuments: (fields[10] as Map?)?.cast<String, String>(),
      averageRating: fields[11] == null ? 0.0 : fields[11] as double,
      reviewCount: fields[12] == null ? 0 : fields[12] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SellerProfile obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.sellerName)
      ..writeByte(1)
      ..write(obj.fssaiLicense)
      ..writeByte(2)
      ..write(obj.cookedFoodSource)
      ..writeByte(3)
      ..write(obj.defaultFoodType)
      ..writeByte(4)
      ..write(obj.sellerId)
      ..writeByte(5)
      ..write(obj.phoneNumber)
      ..writeByte(6)
      ..write(obj.pickupLocation)
      ..writeByte(7)
      ..write(obj.groceryType)
      ..writeByte(8)
      ..write(obj.sellerType)
      ..writeByte(9)
      ..write(obj.groceryOnboardingCompleted)
      ..writeByte(10)
      ..write(obj.groceryDocuments)
      ..writeByte(11)
      ..write(obj.averageRating)
      ..writeByte(12)
      ..write(obj.reviewCount);
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
