import 'package:hive/hive.dart';

part 'food_item.g.dart';

@HiveType(typeId: 1)
class FoodItem extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String price;

  @HiveField(2)
  String originalPrice;

  @HiveField(3)
  String shop;

  @HiveField(4)
  String sellerName;

  @HiveField(5)
  int quantity;

  @HiveField(6)
  DateTime expiryTime;

  @HiveField(7)
  int soldCount;

  @HiveField(8)
  int totalRevenue;

  FoodItem({
    required this.name,
    required this.price,
    required this.originalPrice,
    required this.shop,
    required this.sellerName,
    required this.quantity,
    required this.expiryTime,
    this.soldCount = 0,
    this.totalRevenue = 0,
  });
}
