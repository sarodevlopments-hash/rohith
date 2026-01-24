import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'listing.dart';
import 'schedule_type.dart';

part 'scheduled_listing.g.dart';

@HiveType(typeId: 17)
class ScheduledListing extends HiveObject {
  @HiveField(0)
  final String scheduledId; // Unique ID for this scheduled item

  @HiveField(1)
  final Listing listingData; // The listing data to be posted

  @HiveField(2)
  final ScheduleType scheduleType; // once, daily, weekly

  @HiveField(3)
  final DateTime scheduleStartDate; // When to start posting

  @HiveField(4)
  final DateTime? scheduleEndDate; // Optional end date

  @HiveField(5)
  final int scheduleTimeHour; // Hour of day to post (0-23)

  @HiveField(6)
  final int scheduleTimeMinute; // Minute of hour to post (0-59)

  @HiveField(7)
  final int? scheduleCloseTimeHour; // Hour of day to close (0-23), null means no auto-close

  @HiveField(8)
  final int? scheduleCloseTimeMinute; // Minute of hour to close (0-59)

  @HiveField(9)
  final int? dayOfWeek; // For weekly: 1=Monday, 7=Sunday (null for daily/once)

  @HiveField(10)
  final String sellerId; // Seller who created this schedule

  @HiveField(11)
  DateTime? lastPostedAt; // Last time this was posted (to avoid duplicates)

  @HiveField(12)
  bool isActive; // Whether schedule is active/paused

  @HiveField(13)
  final DateTime createdAt; // When this schedule was created

  // Primary constructor for creating new scheduled listings with TimeOfDay
  ScheduledListing({
    required this.scheduledId,
    required this.listingData,
    required this.scheduleType,
    required this.scheduleStartDate,
    this.scheduleEndDate,
    required TimeOfDay scheduleTime,
    TimeOfDay? scheduleCloseTime,
    this.dayOfWeek,
    required this.sellerId,
    this.lastPostedAt,
    this.isActive = true,
    required this.createdAt,
  }) : scheduleTimeHour = scheduleTime.hour,
       scheduleTimeMinute = scheduleTime.minute,
       scheduleCloseTimeHour = scheduleCloseTime?.hour,
       scheduleCloseTimeMinute = scheduleCloseTime?.minute;

  // Internal constructor for Hive deserialization (uses raw hour/minute values)
  ScheduledListing._internal({
    required this.scheduledId,
    required this.listingData,
    required this.scheduleType,
    required this.scheduleStartDate,
    this.scheduleEndDate,
    required this.scheduleTimeHour,
    required this.scheduleTimeMinute,
    this.scheduleCloseTimeHour,
    this.scheduleCloseTimeMinute,
    this.dayOfWeek,
    required this.sellerId,
    this.lastPostedAt,
    this.isActive = true,
    required this.createdAt,
  });

  // Getter for TimeOfDay
  TimeOfDay get scheduleTime => TimeOfDay(hour: scheduleTimeHour, minute: scheduleTimeMinute);
  
  // Getter for close time
  TimeOfDay? get scheduleCloseTime {
    if (scheduleCloseTimeHour == null || scheduleCloseTimeMinute == null) return null;
    return TimeOfDay(hour: scheduleCloseTimeHour!, minute: scheduleCloseTimeMinute!);
  }

  // Helper to check if this should be posted now
  bool shouldPostNow(DateTime now) {
    if (!isActive) return false;
    
    final nowTime = TimeOfDay.fromDateTime(now);
    final scheduleDateTime = DateTime(
      scheduleStartDate.year,
      scheduleStartDate.month,
      scheduleStartDate.day,
      scheduleTimeHour,
      scheduleTimeMinute,
    );

    switch (scheduleType) {
      case ScheduleType.once:
        // Post once at the scheduled date/time
        if (now.isBefore(scheduleDateTime)) return false;
        if (scheduleEndDate != null && now.isAfter(scheduleEndDate!)) return false;
        // Check if already posted today
        if (lastPostedAt != null && 
            lastPostedAt!.year == now.year &&
            lastPostedAt!.month == now.month &&
            lastPostedAt!.day == now.day) {
          return false;
        }
        return now.isAfter(scheduleDateTime.subtract(const Duration(minutes: 1))) &&
               now.isBefore(scheduleDateTime.add(const Duration(minutes: 1)));

      case ScheduleType.daily:
        // Post daily at the specified time
        if (now.isBefore(scheduleStartDate)) return false;
        if (scheduleEndDate != null && now.isAfter(scheduleEndDate!)) return false;
        // Check if already posted today
        if (lastPostedAt != null && 
            lastPostedAt!.year == now.year &&
            lastPostedAt!.month == now.month &&
            lastPostedAt!.day == now.day) {
          return false;
        }
        // Check if current time matches schedule time (within 1 minute window)
        return nowTime.hour == scheduleTimeHour &&
               nowTime.minute == scheduleTimeMinute;

      case ScheduleType.weekly:
        // Post weekly on specified day and time
        if (now.isBefore(scheduleStartDate)) return false;
        if (scheduleEndDate != null && now.isAfter(scheduleEndDate!)) return false;
        if (dayOfWeek == null) return false;
        
        // Check if today is the scheduled day (1=Monday, 7=Sunday)
        final currentDayOfWeek = now.weekday; // 1=Monday, 7=Sunday
        if (currentDayOfWeek != dayOfWeek) return false;
        
        // Check if already posted today
        if (lastPostedAt != null && 
            lastPostedAt!.year == now.year &&
            lastPostedAt!.month == now.month &&
            lastPostedAt!.day == now.day) {
          return false;
        }
        // Check if current time matches schedule time
        return nowTime.hour == scheduleTimeHour &&
               nowTime.minute == scheduleTimeMinute;
    }
  }

  // Get next posting time
  DateTime? getNextPostingTime(DateTime now) {
    if (!isActive) return null;
    if (scheduleEndDate != null && now.isAfter(scheduleEndDate!)) return null;

    final scheduleDateTime = DateTime(
      scheduleStartDate.year,
      scheduleStartDate.month,
      scheduleStartDate.day,
      scheduleTimeHour,
      scheduleTimeMinute,
    );

    switch (scheduleType) {
      case ScheduleType.once:
        if (now.isBefore(scheduleDateTime)) return scheduleDateTime;
        return null; // Already passed

      case ScheduleType.daily:
        var next = DateTime(now.year, now.month, now.day, scheduleTimeHour, scheduleTimeMinute);
        if (next.isBefore(now)) {
          next = next.add(const Duration(days: 1));
        }
        return next;

      case ScheduleType.weekly:
        if (dayOfWeek == null) return null;
        var next = DateTime(now.year, now.month, now.day, scheduleTimeHour, scheduleTimeMinute);
        final currentDayOfWeek = now.weekday;
        int daysToAdd = (dayOfWeek! - currentDayOfWeek) % 7;
        if (daysToAdd == 0 && next.isBefore(now)) {
          daysToAdd = 7; // Next week
        }
        next = next.add(Duration(days: daysToAdd));
        return next;
    }
  }
}
