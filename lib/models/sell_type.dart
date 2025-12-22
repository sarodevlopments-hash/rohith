import 'package:hive/hive.dart';

part 'sell_type.g.dart';

@HiveType(typeId: 4)
enum SellType {
  @HiveField(0)
  cookedFood,

  @HiveField(1)
  groceries,

  @HiveField(2)
  vegetables,

  @HiveField(3)
  medicine,
}
