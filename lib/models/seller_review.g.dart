// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seller_review.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SellerReviewAdapter extends TypeAdapter<SellerReview> {
  @override
  final int typeId = 21;

  @override
  SellerReview read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SellerReview(
      id: fields[0] as String,
      sellerId: fields[1] as String,
      buyerId: fields[2] as String,
      orderId: fields[3] as String,
      rating: fields[4] as double,
      reviewText: fields[5] as String?,
      createdAt: fields[6] as DateTime,
      updatedAt: fields[7] as DateTime?,
      isApproved: fields[8] as bool,
      serviceRating: fields[9] as double?,
      deliveryRating: fields[10] as double?,
      packagingRating: fields[11] as double?,
      behaviorRating: fields[12] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, SellerReview obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sellerId)
      ..writeByte(2)
      ..write(obj.buyerId)
      ..writeByte(3)
      ..write(obj.orderId)
      ..writeByte(4)
      ..write(obj.rating)
      ..writeByte(5)
      ..write(obj.reviewText)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.isApproved)
      ..writeByte(9)
      ..write(obj.serviceRating)
      ..writeByte(10)
      ..write(obj.deliveryRating)
      ..writeByte(11)
      ..write(obj.packagingRating)
      ..writeByte(12)
      ..write(obj.behaviorRating);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SellerReviewAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
