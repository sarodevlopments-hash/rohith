// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rating.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RatingAdapter extends TypeAdapter<Rating> {
  @override
  final int typeId = 8;

  @override
  Rating read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Rating(
      listingId: fields[0] as String,
      sellerId: fields[1] as String,
      foodRating: fields[2] as double,
      sellerRating: fields[3] as double,
      review: fields[4] as String?,
      buyerId: fields[5] as String,
      ratedAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Rating obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.listingId)
      ..writeByte(1)
      ..write(obj.sellerId)
      ..writeByte(2)
      ..write(obj.foodRating)
      ..writeByte(3)
      ..write(obj.sellerRating)
      ..writeByte(4)
      ..write(obj.review)
      ..writeByte(5)
      ..write(obj.buyerId)
      ..writeByte(6)
      ..write(obj.ratedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RatingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
