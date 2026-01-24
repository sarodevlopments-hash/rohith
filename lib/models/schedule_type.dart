import 'package:hive/hive.dart';

part 'schedule_type.g.dart';

@HiveType(typeId: 16)
enum ScheduleType {
  @HiveField(0)
  once, // Post once at specified time

  @HiveField(1)
  daily, // Post every day at specified time

  @HiveField(2)
  weekly, // Post weekly on specified day and time
}

