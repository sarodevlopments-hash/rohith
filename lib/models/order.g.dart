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
      userId: fields[9] as String,
      sellerId: fields[15] as String,
      orderStatus: fields[10] as String,
      orderId: fields[11] as String?,
      paymentCompletedAt: fields[12] as DateTime?,
      sellerRespondedAt: fields[13] as DateTime?,
      paymentMethod: fields[14] as String?,
      selectedPackQuantity: fields[16] as double?,
      selectedPackPrice: fields[17] as double?,
      selectedPackLabel: fields[18] as String?,
      isLiveKitchenOrder: fields[19] as bool?,
      preparationTimeMinutes: fields[20] as int?,
      statusChangedAt: fields[21] as DateTime?,
      selectedSize: fields[22] as String?,
      selectedColor: fields[23] as String?,
      pickupOtp: fields[24] as String?,
      otpStatus: fields[25] as String?,
      otpVerifiedAt: fields[26] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Order obj) {
    writer
      ..writeByte(27)
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
      ..write(obj.userId)
      ..writeByte(10)
      ..write(obj.orderStatus)
      ..writeByte(11)
      ..write(obj.orderId)
      ..writeByte(12)
      ..write(obj.paymentCompletedAt)
      ..writeByte(13)
      ..write(obj.sellerRespondedAt)
      ..writeByte(14)
      ..write(obj.paymentMethod)
      ..writeByte(15)
      ..write(obj.sellerId)
      ..writeByte(16)
      ..write(obj.selectedPackQuantity)
      ..writeByte(17)
      ..write(obj.selectedPackPrice)
      ..writeByte(18)
      ..write(obj.selectedPackLabel)
      ..writeByte(19)
      ..write(obj.isLiveKitchenOrder)
      ..writeByte(20)
      ..write(obj.preparationTimeMinutes)
      ..writeByte(21)
      ..write(obj.statusChangedAt)
      ..writeByte(22)
      ..write(obj.selectedSize)
      ..writeByte(23)
      ..write(obj.selectedColor)
      ..writeByte(24)
      ..write(obj.pickupOtp)
      ..writeByte(25)
      ..write(obj.otpStatus)
      ..writeByte(26)
      ..write(obj.otpVerifiedAt);
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
