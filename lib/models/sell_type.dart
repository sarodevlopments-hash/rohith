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

  @HiveField(4)
  liveKitchen, // Live Kitchen - cook on demand, real-time ordering
}

extension SellTypeExtension on SellType {
  String get displayName {
    switch (this) {
      case SellType.cookedFood:
        return 'Cooked Food';
      case SellType.groceries:
        return 'Groceries';
      case SellType.vegetables:
        return 'Vegetables';
      case SellType.medicine:
        return 'Medicine';
      case SellType.liveKitchen:
        return 'Live Kitchen';
    }
  }

  String get description {
    switch (this) {
      case SellType.cookedFood:
        return 'Pre-cooked food items';
      case SellType.groceries:
        return 'Grocery items';
      case SellType.vegetables:
        return 'Fresh vegetables';
      case SellType.medicine:
        return 'Medical items';
      case SellType.liveKitchen:
        return 'Cook on demand - real-time orders';
    }
  }

  bool get isLiveKitchen => this == SellType.liveKitchen;

  /// Returns true if seller identity should be hidden for this sell type
  /// (Groceries and Vegetables should hide seller identity)
  bool get shouldHideSellerIdentity {
    return this == SellType.groceries || this == SellType.vegetables;
  }
}
