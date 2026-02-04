// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'buyer_address.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BuyerAddressAdapter extends TypeAdapter<BuyerAddress> {
  @override
  final int typeId = 10;

  @override
  BuyerAddress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BuyerAddress(
      id: fields[0] as String,
      label: fields[1] as String,
      fullAddress: fields[2] as String,
      street: fields[3] as String?,
      city: fields[4] as String?,
      state: fields[5] as String?,
      pincode: fields[6] as String?,
      latitude: fields[7] as double?,
      longitude: fields[8] as double?,
      isDefault: fields[9] as bool,
      createdAt: fields[10] as DateTime,
      updatedAt: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, BuyerAddress obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.label)
      ..writeByte(2)
      ..write(obj.fullAddress)
      ..writeByte(3)
      ..write(obj.street)
      ..writeByte(4)
      ..write(obj.city)
      ..writeByte(5)
      ..write(obj.state)
      ..writeByte(6)
      ..write(obj.pincode)
      ..writeByte(7)
      ..write(obj.latitude)
      ..writeByte(8)
      ..write(obj.longitude)
      ..writeByte(9)
      ..write(obj.isDefault)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BuyerAddressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
