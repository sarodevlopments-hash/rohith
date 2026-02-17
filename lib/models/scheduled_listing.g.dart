// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduled_listing.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScheduledListingAdapter extends TypeAdapter<ScheduledListing> {
  @override
  final int typeId = 17;

  @override
  ScheduledListing read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScheduledListing(
      scheduledId: fields[0] as String,
      listingData: fields[1] as Listing,
      scheduleType: fields[2] as ScheduleType,
      scheduleStartDate: fields[3] as DateTime,
      scheduleEndDate: fields[4] as DateTime?,
      dayOfWeek: fields[9] as int?,
      sellerId: fields[10] as String,
      lastPostedAt: fields[11] as DateTime?,
      isActive: fields[12] as bool,
      createdAt: fields[13] as DateTime,
      scheduleTimeHour: fields[5] as int?,
      scheduleTimeMinute: fields[6] as int?,
      scheduleCloseTimeHour: fields[7] as int?,
      scheduleCloseTimeMinute: fields[8] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ScheduledListing obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.scheduledId)
      ..writeByte(1)
      ..write(obj.listingData)
      ..writeByte(2)
      ..write(obj.scheduleType)
      ..writeByte(3)
      ..write(obj.scheduleStartDate)
      ..writeByte(4)
      ..write(obj.scheduleEndDate)
      ..writeByte(5)
      ..write(obj.scheduleTimeHour)
      ..writeByte(6)
      ..write(obj.scheduleTimeMinute)
      ..writeByte(7)
      ..write(obj.scheduleCloseTimeHour)
      ..writeByte(8)
      ..write(obj.scheduleCloseTimeMinute)
      ..writeByte(9)
      ..write(obj.dayOfWeek)
      ..writeByte(10)
      ..write(obj.sellerId)
      ..writeByte(11)
      ..write(obj.lastPostedAt)
      ..writeByte(12)
      ..write(obj.isActive)
      ..writeByte(13)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduledListingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
