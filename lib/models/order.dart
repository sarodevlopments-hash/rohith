import 'package:hive/hive.dart';

part 'order.g.dart';

@HiveType(typeId: 0)
class Order extends HiveObject {
  @HiveField(0)
  final String foodName;

  @HiveField(1)
  final String sellerName;

  @HiveField(2)
  final double pricePaid;

  @HiveField(3)
  final double savedAmount;

  @HiveField(4)
  final DateTime purchasedAt;

  @HiveField(5)
  final String listingId; // Reference to the listing

  @HiveField(6)
  final int quantity; // Quantity purchased

  @HiveField(7)
  final double originalPrice; // Original price per unit

  @HiveField(8)
  final double discountedPrice; // Discounted price per unit

  @HiveField(9)
  final String userId; // Buyer's user ID

  Order({
    required this.foodName,
    required this.sellerName,
    required this.pricePaid,
    required this.savedAmount,
    required this.purchasedAt,
    required this.listingId,
    required this.quantity,
    required this.originalPrice,
    required this.discountedPrice,
    required this.userId,
  });
}
