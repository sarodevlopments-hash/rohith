// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule_type.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScheduleTypeAdapter extends TypeAdapter<ScheduleType> {
  @override
  final int typeId = 16;

  @override
  ScheduleType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ScheduleType.once;
      case 1:
        return ScheduleType.daily;
      case 2:
        return ScheduleType.weekly;
      default:
        return ScheduleType.once;
    }
  }

  @override
  void write(BinaryWriter writer, ScheduleType obj) {
    switch (obj) {
      case ScheduleType.once:
        writer.writeByte(0);
        break;
      case ScheduleType.daily:
        writer.writeByte(1);
        break;
      case ScheduleType.weekly:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
