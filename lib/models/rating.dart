import 'package:hive/hive.dart';

part 'rating.g.dart';

@HiveType(typeId: 8)
class Rating extends HiveObject {
  @HiveField(0)
  final String listingId; // ID of the food item

  @HiveField(1)
  final String sellerId;

  @HiveField(2)
  final double foodRating; // Rating for the food item (1-5)

  @HiveField(3)
  final double sellerRating; // Rating for the seller (1-5)

  @HiveField(4)
  final String? review; // Optional review text

  @HiveField(5)
  final String buyerId;

  @HiveField(6)
  final DateTime ratedAt;

  Rating({
    required this.listingId,
    required this.sellerId,
    required this.foodRating,
    required this.sellerRating,
    this.review,
    required this.buyerId,
    required this.ratedAt,
  });
}

