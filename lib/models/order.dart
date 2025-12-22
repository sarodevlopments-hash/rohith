import 'package:hive/hive.dart';

part 'order.g.dart';

@HiveType(typeId: 0)
class Order {
  @HiveField(0)
  final String foodName;

  @HiveField(1)
  final String sellerName;

  @HiveField(2)
  final int pricePaid;

  @HiveField(3)
  final int savedAmount;

  @HiveField(4)
  final DateTime purchasedAt;

  Order({
    required this.foodName,
    required this.sellerName,
    required this.pricePaid,
    required this.savedAmount,
    required this.purchasedAt,
  });
}
