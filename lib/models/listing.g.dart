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
      initialQuantity: fields[11] as int,
      sellerId: fields[12] as String,
      fssaiLicense: fields[6] as String?,
      preparedAt: fields[7] as DateTime?,
      expiryDate: fields[8] as DateTime?,
      category: fields[9] as FoodCategory,
      cookedFoodSource: fields[10] as CookedFoodSource?,
      imagePath: fields[13] as String?,
      measurementUnit: fields[14] as MeasurementUnit?,
      packSizes: (fields[15] as List?)?.cast<PackSize>(),
      isBulkFood: fields[16] == null ? false : fields[16] as bool,
      servesCount: fields[17] as int?,
      portionDescription: fields[18] as String?,
      isKitchenOpen: fields[19] == null ? false : fields[19] as bool,
      preparationTimeMinutes: fields[20] as int?,
      maxCapacity: fields[21] as int?,
      currentOrders: fields[22] == null ? 0 : fields[22] as int,
      clothingCategory: fields[23] as ClothingCategory?,
      description: fields[24] as String?,
      availableSizes: (fields[25] as List?)?.cast<String>(),
      availableColors: (fields[26] as List?)?.cast<String>(),
      sizeColorCombinations:
          (fields[27] as List?)?.cast<SizeColorCombination>(),
      colorImages: (fields[28] as Map?)?.cast<String, String>(),
      averageRating: fields[29] == null ? 0.0 : fields[29] as double,
      reviewCount: fields[30] == null ? 0 : fields[30] as int,
      isFeatured: fields[31] == null ? false : fields[31] as bool?,
      featuredPriority: fields[32] == null ? 0 : fields[32] as int?,
      categoryAttributes: (fields[33] as Map?)?.cast<String, String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Listing obj) {
    writer
      ..writeByte(34)
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
      ..write(obj.cookedFoodSource)
      ..writeByte(11)
      ..write(obj.initialQuantity)
      ..writeByte(12)
      ..write(obj.sellerId)
      ..writeByte(13)
      ..write(obj.imagePath)
      ..writeByte(14)
      ..write(obj.measurementUnit)
      ..writeByte(15)
      ..write(obj.packSizes)
      ..writeByte(16)
      ..write(obj.isBulkFood)
      ..writeByte(17)
      ..write(obj.servesCount)
      ..writeByte(18)
      ..write(obj.portionDescription)
      ..writeByte(19)
      ..write(obj.isKitchenOpen)
      ..writeByte(20)
      ..write(obj.preparationTimeMinutes)
      ..writeByte(21)
      ..write(obj.maxCapacity)
      ..writeByte(22)
      ..write(obj.currentOrders)
      ..writeByte(23)
      ..write(obj.clothingCategory)
      ..writeByte(24)
      ..write(obj.description)
      ..writeByte(25)
      ..write(obj.availableSizes)
      ..writeByte(26)
      ..write(obj.availableColors)
      ..writeByte(27)
      ..write(obj.sizeColorCombinations)
      ..writeByte(28)
      ..write(obj.colorImages)
      ..writeByte(29)
      ..write(obj.averageRating)
      ..writeByte(30)
      ..write(obj.reviewCount)
      ..writeByte(31)
      ..write(obj.isFeatured)
      ..writeByte(32)
      ..write(obj.featuredPriority)
      ..writeByte(33)
      ..write(obj.categoryAttributes);
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
