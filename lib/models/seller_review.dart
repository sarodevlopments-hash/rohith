import 'package:hive/hive.dart';

part 'seller_review.g.dart';

@HiveType(typeId: 21)
class SellerReview extends HiveObject {
  @HiveField(0)
  final String id; // Unique review ID

  @HiveField(1)
  final String sellerId;

  @HiveField(2)
  final String buyerId;

  @HiveField(3)
  final String orderId; // Order ID this review is for

  @HiveField(4)
  final double rating; // 1-5 stars (overall)

  @HiveField(5)
  final String? reviewText; // Optional review comment

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final DateTime? updatedAt; // For edits

  @HiveField(8)
  final bool isApproved; // Admin moderation

  // Optional category ratings
  @HiveField(9)
  final double? serviceRating; // Overall service rating

  @HiveField(10)
  final double? deliveryRating; // Delivery experience rating

  @HiveField(11)
  final double? packagingRating; // Packaging quality rating

  @HiveField(12)
  final double? behaviorRating; // Seller behavior rating

  SellerReview({
    required this.id,
    required this.sellerId,
    required this.buyerId,
    required this.orderId,
    required this.rating,
    this.reviewText,
    required this.createdAt,
    this.updatedAt,
    this.isApproved = true, // Auto-approve by default
    this.serviceRating,
    this.deliveryRating,
    this.packagingRating,
    this.behaviorRating,
  });

  // Check if review can be edited (within 24 hours)
  bool canEdit() {
    final now = DateTime.now();
    final hoursSinceCreation = now.difference(createdAt).inHours;
    return hoursSinceCreation < 24;
  }

  // Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'sellerId': sellerId,
      'buyerId': buyerId,
      'orderId': orderId,
      'rating': rating,
      'reviewText': reviewText,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isApproved': isApproved,
      'serviceRating': serviceRating,
      'deliveryRating': deliveryRating,
      'packagingRating': packagingRating,
      'behaviorRating': behaviorRating,
    };
  }

  // Create from Firestore map
  factory SellerReview.fromFirestore(Map<String, dynamic> data) {
    return SellerReview(
      id: data['id'] as String,
      sellerId: data['sellerId'] as String,
      buyerId: data['buyerId'] as String,
      orderId: data['orderId'] as String,
      rating: (data['rating'] as num).toDouble(),
      reviewText: data['reviewText'] as String?,
      createdAt: DateTime.parse(data['createdAt'] as String),
      updatedAt: data['updatedAt'] != null
          ? DateTime.parse(data['updatedAt'] as String)
          : null,
      isApproved: data['isApproved'] as bool? ?? true,
      serviceRating: data['serviceRating'] != null
          ? (data['serviceRating'] as num).toDouble()
          : null,
      deliveryRating: data['deliveryRating'] != null
          ? (data['deliveryRating'] as num).toDouble()
          : null,
      packagingRating: data['packagingRating'] != null
          ? (data['packagingRating'] as num).toDouble()
          : null,
      behaviorRating: data['behaviorRating'] != null
          ? (data['behaviorRating'] as num).toDouble()
          : null,
    );
  }
}

