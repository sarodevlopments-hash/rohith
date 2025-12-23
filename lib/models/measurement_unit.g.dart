// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'measurement_unit.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MeasurementUnitAdapter extends TypeAdapter<MeasurementUnit> {
  @override
  final int typeId = 6;

  @override
  MeasurementUnit read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MeasurementUnit.kilograms;
      case 1:
        return MeasurementUnit.grams;
      case 2:
        return MeasurementUnit.liters;
      case 3:
        return MeasurementUnit.pieces;
      default:
        return MeasurementUnit.kilograms;
    }
  }

  @override
  void write(BinaryWriter writer, MeasurementUnit obj) {
    switch (obj) {
      case MeasurementUnit.kilograms:
        writer.writeByte(0);
        break;
      case MeasurementUnit.grams:
        writer.writeByte(1);
        break;
      case MeasurementUnit.liters:
        writer.writeByte(2);
        break;
      case MeasurementUnit.pieces:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeasurementUnitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
