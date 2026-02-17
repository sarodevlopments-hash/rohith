// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pack_size.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PackSizeAdapter extends TypeAdapter<PackSize> {
  @override
  final int typeId = 15;

  @override
  PackSize read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PackSize(
      quantity: fields[0] as double,
      price: fields[1] as double,
      label: fields[2] as String?,
      stock: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, PackSize obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.quantity)
      ..writeByte(1)
      ..write(obj.price)
      ..writeByte(2)
      ..write(obj.label)
      ..writeByte(3)
      ..write(obj.stock);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PackSizeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
