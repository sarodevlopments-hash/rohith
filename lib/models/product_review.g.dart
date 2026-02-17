// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_review.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductReviewAdapter extends TypeAdapter<ProductReview> {
  @override
  final int typeId = 20;

  @override
  ProductReview read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductReview(
      id: fields[0] as String,
      productId: fields[1] as String,
      sellerId: fields[2] as String,
      buyerId: fields[3] as String,
      orderId: fields[4] as String,
      rating: fields[5] as double,
      reviewText: fields[6] as String?,
      imageUrl: fields[7] as String?,
      createdAt: fields[8] as DateTime,
      updatedAt: fields[9] as DateTime?,
      isApproved: fields[10] as bool,
      helpfulCount: fields[11] as int,
      helpfulVoters: (fields[12] as List).cast<String>(),
      sellerReply: fields[13] as String?,
      sellerRepliedAt: fields[14] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ProductReview obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.productId)
      ..writeByte(2)
      ..write(obj.sellerId)
      ..writeByte(3)
      ..write(obj.buyerId)
      ..writeByte(4)
      ..write(obj.orderId)
      ..writeByte(5)
      ..write(obj.rating)
      ..writeByte(6)
      ..write(obj.reviewText)
      ..writeByte(7)
      ..write(obj.imageUrl)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt)
      ..writeByte(10)
      ..write(obj.isApproved)
      ..writeByte(11)
      ..write(obj.helpfulCount)
      ..writeByte(12)
      ..write(obj.helpfulVoters)
      ..writeByte(13)
      ..write(obj.sellerReply)
      ..writeByte(14)
      ..write(obj.sellerRepliedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductReviewAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
