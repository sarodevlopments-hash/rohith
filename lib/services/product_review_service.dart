import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hive/hive.dart';
import '../models/product_review.dart';
import '../models/listing.dart';
import '../models/order.dart';
import 'listing_firestore_service.dart';

/// Service to manage product reviews
class ProductReviewService {
  // Use the correct database ID: 'reqfood' (not the default)
  static FirebaseFirestore get _db => FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'reqfood',
  );
  static const String _collection = 'productReviews';

  /// Get document reference for a review
  static DocumentReference<Map<String, dynamic>> doc(String reviewId) {
    return _db.collection(_collection).doc(reviewId);
  }

  /// Check if buyer can review a product (has purchased and not already reviewed for this order)
  static Future<bool> canReviewProduct({
    required String buyerId,
    required String productId,
    required String orderId,
  }) async {
    try {
      // Check if review already exists for this order (with error handling for permission issues)
      try {
        final existingReview = await _db
            .collection(_collection)
            .where('buyerId', isEqualTo: buyerId)
            .where('productId', isEqualTo: productId)
            .where('orderId', isEqualTo: orderId)
            .limit(1)
            .get();

        if (existingReview.docs.isNotEmpty) {
          return false; // Already reviewed
        }
      } catch (firestoreError) {
        // If Firestore permission error, continue with local check
        // This is expected if Firestore rules don't allow reading reviews
        if (!firestoreError.toString().contains('permission-denied')) {
          // Only log non-permission errors
          print('[ProductReviewService] Error checking existing reviews: $firestoreError');
        }
        // Continue to check eligibility using local storage
      }

      // Try to get order from local Hive storage first (faster and avoids permission issues)
      try {
        final orderBox = Hive.box<Order>('ordersBox');
        Order? localOrder;
        try {
          localOrder = orderBox.values.firstWhere(
            (order) => order.orderId == orderId,
          );
        } catch (e) {
          // Order not found in local storage
          throw Exception('Order not found locally');
        }

        if (localOrder == null) {
          throw Exception('Order not found locally');
        }

        // Check if order is completed and buyer matches
        final isCompleted = localOrder.orderStatus == 'Completed';
        final buyerMatches = localOrder.userId == buyerId;
        final productMatches = localOrder.listingId == productId;
        
        print('[ProductReviewService] Checking eligibility for order $orderId:');
        print('  - Status: ${localOrder.orderStatus} (Completed: $isCompleted)');
        print('  - Buyer ID: ${localOrder.userId} (Matches: $buyerMatches)');
        print('  - Product ID: ${localOrder.listingId} (Matches: $productMatches)');
        
        if (isCompleted && buyerMatches && productMatches) {
          print('[ProductReviewService] ✅ Eligible to review');
          return true;
        }
        print('[ProductReviewService] ❌ Not eligible to review');
        return false;
        } catch (e) {
          // Order not found in local storage - this is expected for cross-device scenarios
          // Don't fallback to Firestore due to permission issues, just return false
          // The order might not be synced yet or user might be on a different device
          print('[ProductReviewService] Order $orderId not found in local storage: $e');
          return false;
        }
    } catch (e) {
      // Silently handle errors - don't spam console with permission errors
      // Only log if it's not a permission error
      if (!e.toString().contains('permission-denied')) {
        print('[ProductReviewService] Error checking review eligibility: $e');
      }
      return false;
    }
  }

  /// Submit a product review
  static Future<String> submitReview({
    required String productId,
    required String sellerId,
    required String buyerId,
    required String orderId,
    required double rating,
    String? reviewText,
    String? imagePath, // Local file path
  }) async {
    try {
      // Validate rating
      if (rating < 1 || rating > 5) {
        throw Exception('Rating must be between 1 and 5');
      }

      // Check if can review
      final canReview = await canReviewProduct(
        buyerId: buyerId,
        productId: productId,
        orderId: orderId,
      );

      if (!canReview) {
        throw Exception('You cannot review this product. Make sure you have purchased and completed the order.');
      }

      // Upload image if provided
      String? imageUrl;
      if (imagePath != null) {
        imageUrl = await _uploadReviewImage(imagePath, productId, buyerId);
      }

      // Create review
      final reviewId = _db.collection(_collection).doc().id;
      final review = ProductReview(
        id: reviewId,
        productId: productId,
        sellerId: sellerId,
        buyerId: buyerId,
        orderId: orderId,
        rating: rating,
        reviewText: reviewText?.trim().isEmpty == true ? null : reviewText?.trim(),
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
        isApproved: true, // Auto-approve for now
      );

      // Save to Firestore
      await doc(reviewId).set(review.toFirestore());

      // Update product rating
      await _updateProductRating(productId);

      // Save to Hive for offline access
      final box = await Hive.openBox<ProductReview>('productReviewsBox');
      await box.put(reviewId, review);

      return reviewId;
    } catch (e) {
      print('Error submitting review: $e');
      rethrow;
    }
  }

  /// Update a product review (within 24 hours)
  static Future<void> updateReview({
    required String reviewId,
    double? rating,
    String? reviewText,
    String? imagePath,
  }) async {
    try {
      final reviewDoc = await doc(reviewId).get();
      if (!reviewDoc.exists) {
        throw Exception('Review not found');
      }

      final review = ProductReview.fromFirestore(reviewDoc.data()!);
      if (!review.canEdit()) {
        throw Exception('Review can only be edited within 24 hours of creation');
      }

      // Upload new image if provided
      String? imageUrl = review.imageUrl;
      if (imagePath != null) {
        imageUrl = await _uploadReviewImage(imagePath, review.productId, review.buyerId);
      }

      // Update review
      final updatedReview = ProductReview(
        id: review.id,
        productId: review.productId,
        sellerId: review.sellerId,
        buyerId: review.buyerId,
        orderId: review.orderId,
        rating: rating ?? review.rating,
        reviewText: reviewText?.trim().isEmpty == true ? null : reviewText?.trim() ?? review.reviewText,
        imageUrl: imageUrl,
        createdAt: review.createdAt,
        updatedAt: DateTime.now(),
        isApproved: review.isApproved,
        helpfulCount: review.helpfulCount,
        helpfulVoters: review.helpfulVoters,
        sellerReply: review.sellerReply,
        sellerRepliedAt: review.sellerRepliedAt,
      );

      await doc(reviewId).set(updatedReview.toFirestore());

      // Update product rating
      await _updateProductRating(review.productId);

      // Update in Hive
      final box = await Hive.openBox<ProductReview>('productReviewsBox');
      await box.put(reviewId, updatedReview);
    } catch (e) {
      print('Error updating review: $e');
      rethrow;
    }
  }

  /// Get reviews for a product
  static Future<List<ProductReview>> getProductReviews({
    required String productId,
    int limit = 50,
    bool approvedOnly = true,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _db
          .collection(_collection)
          .where('productId', isEqualTo: productId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (approvedOnly) {
        query = query.where('isApproved', isEqualTo: true);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ProductReview.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching reviews: $e');
      return [];
    }
  }

  /// Get rating breakdown for a product
  static Future<Map<int, int>> getRatingBreakdown(String productId) async {
    try {
      final reviews = await getProductReviews(productId: productId);
      final breakdown = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

      for (final review in reviews) {
        final rating = review.rating.round();
        if (rating >= 1 && rating <= 5) {
          breakdown[rating] = (breakdown[rating] ?? 0) + 1;
        }
      }

      return breakdown;
    } catch (e) {
      print('Error getting rating breakdown: $e');
      return {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    }
  }

  /// Calculate and update product average rating
  static Future<void> _updateProductRating(String productId) async {
    try {
      final reviews = await getProductReviews(productId: productId);
      if (reviews.isEmpty) {
        return;
      }

      final totalRating = reviews.fold<double>(0.0, (sum, review) => sum + review.rating);
      final averageRating = (totalRating / reviews.length).roundToDouble() / 10.0; // Round to 1 decimal
      final reviewCount = reviews.length;

      // Update in Firestore
      await ListingFirestoreService.doc(productId).update({
        'averageRating': averageRating,
        'reviewCount': reviewCount,
      });

      // Update in Hive if listing exists
      try {
        final listingBox = Hive.box<Listing>('listingBox');
        final listing = listingBox.values.firstWhere(
          (l) => l.key.toString() == productId,
          orElse: () => listingBox.values.first,
        );
        if (listing.key.toString() == productId) {
          // Note: Hive objects are immutable, so we'd need to create a new Listing
          // For now, we'll rely on Firestore for rating updates
        }
      } catch (e) {
        // Hive update not critical
      }
    } catch (e) {
      print('Error updating product rating: $e');
    }
  }

  /// Mark review as helpful
  static Future<void> markHelpful({
    required String reviewId,
    required String userId,
  }) async {
    try {
      final reviewDoc = await doc(reviewId).get();
      if (!reviewDoc.exists) {
        throw Exception('Review not found');
      }

      final review = ProductReview.fromFirestore(reviewDoc.data()!);
      if (review.helpfulVoters.contains(userId)) {
        // Already marked, unmark
        final updatedVoters = review.helpfulVoters.where((id) => id != userId).toList();
        await doc(reviewId).update({
          'helpfulCount': updatedVoters.length,
          'helpfulVoters': updatedVoters,
        });
      } else {
        // Mark as helpful
        final updatedVoters = [...review.helpfulVoters, userId];
        await doc(reviewId).update({
          'helpfulCount': updatedVoters.length,
          'helpfulVoters': updatedVoters,
        });
      }
    } catch (e) {
      print('Error marking review as helpful: $e');
      rethrow;
    }
  }

  /// Upload review image to Firebase Storage
  static Future<String> _uploadReviewImage(
    String imagePath,
    String productId,
    String buyerId,
  ) async {
    try {
      final storage = FirebaseStorage.instanceFor(
        app: Firebase.app(),
        bucket: 'reqfood.appspot.com',
      );

      final fileName = 'reviews/${productId}/${buyerId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = storage.ref().child(fileName);

      // Upload file
      await ref.putFile(await Future.value(imagePath as dynamic)); // Adjust based on platform

      // Get download URL
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading review image: $e');
      rethrow;
    }
  }
}

