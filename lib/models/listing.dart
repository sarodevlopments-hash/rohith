import 'package:hive/hive.dart';
import 'sell_type.dart';
import 'food_category.dart';
import 'cooked_food_source.dart';
import 'measurement_unit.dart';

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
  int quantity;

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

  @HiveField(11)
  final int initialQuantity;

  @HiveField(12)
  String sellerId;

  @HiveField(13)
  final String? imagePath; // Path to product image

  @HiveField(14)
  final MeasurementUnit? measurementUnit; // For groceries/vegetables

  Listing({
    required this.name,
    required this.sellerName,
    required this.price,
    this.originalPrice,
    required this.quantity,
    required this.type,
    required this.initialQuantity,
    required this.sellerId,
    this.fssaiLicense,
    this.preparedAt,
    this.expiryDate,
    required this.category,
    this.cookedFoodSource,
    this.imagePath,
    this.measurementUnit,
  });
}
