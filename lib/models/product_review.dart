import 'package:hive/hive.dart';

part 'product_review.g.dart';

@HiveType(typeId: 20)
class ProductReview extends HiveObject {
  @HiveField(0)
  final String id; // Unique review ID

  @HiveField(1)
  final String productId; // Listing ID

  @HiveField(2)
  final String sellerId;

  @HiveField(3)
  final String buyerId;

  @HiveField(4)
  final String orderId; // Order ID this review is for

  @HiveField(5)
  final double rating; // 1-5 stars

  @HiveField(6)
  final String? reviewText; // Optional review text

  @HiveField(7)
  final String? imageUrl; // Optional review image

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  final DateTime? updatedAt; // For edits

  @HiveField(10)
  final bool isApproved; // Admin moderation

  @HiveField(11)
  final int helpfulCount; // Number of helpful votes

  @HiveField(12)
  final List<String> helpfulVoters; // User IDs who marked as helpful

  @HiveField(13)
  final String? sellerReply; // Seller's reply to review

  @HiveField(14)
  final DateTime? sellerRepliedAt; // When seller replied

  ProductReview({
    required this.id,
    required this.productId,
    required this.sellerId,
    required this.buyerId,
    required this.orderId,
    required this.rating,
    this.reviewText,
    this.imageUrl,
    required this.createdAt,
    this.updatedAt,
    this.isApproved = true, // Auto-approve by default, can be changed
    this.helpfulCount = 0,
    this.helpfulVoters = const [],
    this.sellerReply,
    this.sellerRepliedAt,
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
      'productId': productId,
      'sellerId': sellerId,
      'buyerId': buyerId,
      'orderId': orderId,
      'rating': rating,
      'reviewText': reviewText,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isApproved': isApproved,
      'helpfulCount': helpfulCount,
      'helpfulVoters': helpfulVoters,
      'sellerReply': sellerReply,
      'sellerRepliedAt': sellerRepliedAt?.toIso8601String(),
    };
  }

  // Create from Firestore map
  factory ProductReview.fromFirestore(Map<String, dynamic> data) {
    return ProductReview(
      id: data['id'] as String,
      productId: data['productId'] as String,
      sellerId: data['sellerId'] as String,
      buyerId: data['buyerId'] as String,
      orderId: data['orderId'] as String,
      rating: (data['rating'] as num).toDouble(),
      reviewText: data['reviewText'] as String?,
      imageUrl: data['imageUrl'] as String?,
      createdAt: DateTime.parse(data['createdAt'] as String),
      updatedAt: data['updatedAt'] != null
          ? DateTime.parse(data['updatedAt'] as String)
          : null,
      isApproved: data['isApproved'] as bool? ?? true,
      helpfulCount: data['helpfulCount'] as int? ?? 0,
      helpfulVoters: List<String>.from(data['helpfulVoters'] as List? ?? []),
      sellerReply: data['sellerReply'] as String?,
      sellerRepliedAt: data['sellerRepliedAt'] != null
          ? DateTime.parse(data['sellerRepliedAt'] as String)
          : null,
    );
  }
}

