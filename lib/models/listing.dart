import 'package:hive/hive.dart';
import 'sell_type.dart';
import 'food_category.dart';
import 'cooked_food_source.dart';

part 'listing.g.dart';

@HiveType(typeId: 3)
class Listing extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String sellerName;

  @HiveField(2)
  final double price;

  @HiveField(3)
  final double? originalPrice;

  @HiveField(4)
  final int quantity;

  @HiveField(5)
  final SellType type;

  @HiveField(6)
  final String? fssaiLicense;

  @HiveField(7)
  final DateTime? preparedAt;

  @HiveField(8)
  final DateTime? expiryDate;

  @HiveField(9)
  final FoodCategory category;

  @HiveField(10)
  final CookedFoodSource? cookedFoodSource;

  Listing({
    required this.name,
    required this.sellerName,
    required this.price,
    this.originalPrice,
    required this.quantity,
    required this.type,
    this.fssaiLicense,
    this.preparedAt,
    this.expiryDate,
    required this.category,
    this.cookedFoodSource,
  });
}
