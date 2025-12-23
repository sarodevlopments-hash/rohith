// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OrderAdapter extends TypeAdapter<Order> {
  @override
  final int typeId = 0;

  @override
  Order read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Order(
      foodName: fields[0] as String,
      sellerName: fields[1] as String,
      pricePaid: fields[2] as double,
      savedAmount: fields[3] as double,
      purchasedAt: fields[4] as DateTime,
      listingId: fields[5] as String,
      quantity: fields[6] as int,
      originalPrice: fields[7] as double,
      discountedPrice: fields[8] as double,
      userId: fields.containsKey(9) ? fields[9] as String : 'legacy_user', // Backward compatibility
    );
  }

  @override
  void write(BinaryWriter writer, Order obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.foodName)
      ..writeByte(1)
      ..write(obj.sellerName)
      ..writeByte(2)
      ..write(obj.pricePaid)
      ..writeByte(3)
      ..write(obj.savedAmount)
      ..writeByte(4)
      ..write(obj.purchasedAt)
      ..writeByte(5)
      ..write(obj.listingId)
      ..writeByte(6)
      ..write(obj.quantity)
      ..writeByte(7)
      ..write(obj.originalPrice)
      ..writeByte(8)
      ..write(obj.discountedPrice)
      ..writeByte(9)
      ..write(obj.userId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
