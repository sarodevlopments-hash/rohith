import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_core/firebase_core.dart';
import 'package:hive/hive.dart';
import '../models/seller_review.dart';
import '../models/order.dart';
import 'seller_profile_service.dart';

/// Service to manage seller reviews
class SellerReviewService {
  // Use the correct database ID: 'reqfood' (not the default)
  static FirebaseFirestore get _db => FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'reqfood',
  );
  static const String _collection = 'sellerReviews';

  /// Get document reference for a review
  static DocumentReference<Map<String, dynamic>> doc(String reviewId) {
    return _db.collection(_collection).doc(reviewId);
  }

  /// Check if buyer can review a seller (has completed order and not already reviewed for this order)
  static Future<bool> canReviewSeller({
    required String buyerId,
    required String sellerId,
    required String orderId,
  }) async {
    try {
      // Check if review already exists for this order (with error handling for permission issues)
      try {
        final existingReview = await _db
            .collection(_collection)
            .where('buyerId', isEqualTo: buyerId)
            .where('sellerId', isEqualTo: sellerId)
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
          print('[SellerReviewService] Error checking existing reviews: $firestoreError');
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

        // Check if order is completed and buyer/seller match
        final isCompleted = localOrder.orderStatus == 'Completed';
        final buyerMatches = localOrder.userId == buyerId;
        final sellerMatches = localOrder.sellerId == sellerId;
        
        print('[SellerReviewService] Checking eligibility for order $orderId:');
        print('  - Status: ${localOrder.orderStatus} (Completed: $isCompleted)');
        print('  - Buyer ID: ${localOrder.userId} (Matches: $buyerMatches)');
        print('  - Seller ID: ${localOrder.sellerId} (Matches: $sellerMatches)');
        
        if (isCompleted && buyerMatches && sellerMatches) {
          print('[SellerReviewService] ✅ Eligible to review');
          return true;
        }
        print('[SellerReviewService] ❌ Not eligible to review');
        return false;
        } catch (e) {
          // Order not found in local storage - this is expected for cross-device scenarios
          // Don't fallback to Firestore due to permission issues, just return false
          // The order might not be synced yet or user might be on a different device
          print('[SellerReviewService] Order $orderId not found in local storage: $e');
          return false;
        }
    } catch (e) {
      // Silently handle errors - don't spam console with permission errors
      // Only log if it's not a permission error
      if (!e.toString().contains('permission-denied')) {
        print('[SellerReviewService] Error checking seller review eligibility: $e');
      }
      return false;
    }
  }

  /// Submit a seller review
  static Future<String> submitReview({
    required String sellerId,
    required String buyerId,
    required String orderId,
    required double rating,
    String? reviewText,
    double? serviceRating,
    double? deliveryRating,
    double? packagingRating,
    double? behaviorRating,
  }) async {
    try {
      // Validate rating
      if (rating < 1 || rating > 5) {
        throw Exception('Rating must be between 1 and 5');
      }

      // Validate category ratings if provided
      if (serviceRating != null && (serviceRating < 1 || serviceRating > 5)) {
        throw Exception('Service rating must be between 1 and 5');
      }
      if (deliveryRating != null && (deliveryRating < 1 || deliveryRating > 5)) {
        throw Exception('Delivery rating must be between 1 and 5');
      }
      if (packagingRating != null && (packagingRating < 1 || packagingRating > 5)) {
        throw Exception('Packaging rating must be between 1 and 5');
      }
      if (behaviorRating != null && (behaviorRating < 1 || behaviorRating > 5)) {
        throw Exception('Behavior rating must be between 1 and 5');
      }

      // Check if can review
      final canReview = await canReviewSeller(
        buyerId: buyerId,
        sellerId: sellerId,
        orderId: orderId,
      );

      if (!canReview) {
        throw Exception('You cannot review this seller. Make sure you have completed an order with them.');
      }

      // Create review
      final reviewId = _db.collection(_collection).doc().id;
      final review = SellerReview(
        id: reviewId,
        sellerId: sellerId,
        buyerId: buyerId,
        orderId: orderId,
        rating: rating,
        reviewText: reviewText?.trim().isEmpty == true ? null : reviewText?.trim(),
        createdAt: DateTime.now(),
        isApproved: true, // Auto-approve for now
        serviceRating: serviceRating,
        deliveryRating: deliveryRating,
        packagingRating: packagingRating,
        behaviorRating: behaviorRating,
      );

      // Save to Firestore
      final reviewData = review.toFirestore();
      print('[SellerReviewService] Saving review to Firestore:');
      print('  - Review ID: $reviewId');
      print('  - Seller ID: $sellerId');
      print('  - Buyer ID: $buyerId');
      print('  - Rating: $rating');
      print('  - Is Approved: ${review.isApproved}');
      
      await doc(reviewId).set(reviewData);
      print('[SellerReviewService] ✅ Review saved successfully to Firestore');

      // Update seller rating
      await _updateSellerRating(sellerId);

      // Save to Hive for offline access
      final box = await Hive.openBox<SellerReview>('sellerReviewsBox');
      await box.put(reviewId, review);

      return reviewId;
    } catch (e) {
      print('Error submitting seller review: $e');
      rethrow;
    }
  }

  /// Update a seller review (within 24 hours)
  static Future<void> updateReview({
    required String reviewId,
    double? rating,
    String? reviewText,
    double? serviceRating,
    double? deliveryRating,
    double? packagingRating,
    double? behaviorRating,
  }) async {
    try {
      final reviewDoc = await doc(reviewId).get();
      if (!reviewDoc.exists) {
        throw Exception('Review not found');
      }

      final review = SellerReview.fromFirestore(reviewDoc.data()!);
      if (!review.canEdit()) {
        throw Exception('Review can only be edited within 24 hours of creation');
      }

      // Update review
      final updatedReview = SellerReview(
        id: review.id,
        sellerId: review.sellerId,
        buyerId: review.buyerId,
        orderId: review.orderId,
        rating: rating ?? review.rating,
        reviewText: reviewText?.trim().isEmpty == true ? null : reviewText?.trim() ?? review.reviewText,
        createdAt: review.createdAt,
        updatedAt: DateTime.now(),
        isApproved: review.isApproved,
        serviceRating: serviceRating ?? review.serviceRating,
        deliveryRating: deliveryRating ?? review.deliveryRating,
        packagingRating: packagingRating ?? review.packagingRating,
        behaviorRating: behaviorRating ?? review.behaviorRating,
      );

      await doc(reviewId).set(updatedReview.toFirestore());

      // Update seller rating
      await _updateSellerRating(review.sellerId);

      // Update in Hive
      final box = await Hive.openBox<SellerReview>('sellerReviewsBox');
      await box.put(reviewId, updatedReview);
    } catch (e) {
      print('Error updating seller review: $e');
      rethrow;
    }
  }

  /// Get reviews for a seller
  static Future<List<SellerReview>> getSellerReviews({
    required String sellerId,
    int limit = 50,
    bool approvedOnly = true,
  }) async {
    print('[SellerReviewService] 🔍 Fetching reviews for seller: $sellerId');
    
    // Try simplest query first (no orderBy to avoid index requirements)
    try {
      Query<Map<String, dynamic>> query = _db
          .collection(_collection)
          .where('sellerId', isEqualTo: sellerId)
          .limit(limit * 2); // Fetch more to account for filtering

      print('[SellerReviewService] Executing query...');
      final snapshot = await query.get();
      print('[SellerReviewService] ✅ Query successful! Fetched ${snapshot.docs.length} documents');
      
      if (snapshot.docs.isEmpty) {
        print('[SellerReviewService] ⚠️ No documents found for sellerId: $sellerId');
        print('[SellerReviewService] Checking if collection exists...');
        
        // Test if collection is accessible at all
        try {
          final testQuery = _db.collection(_collection).limit(1);
          final testSnapshot = await testQuery.get();
          print('[SellerReviewService] Collection exists. Total documents in collection: ${testSnapshot.docs.length}');
          
          // Check what sellerIds exist
          if (testSnapshot.docs.isNotEmpty) {
            final sampleDoc = testSnapshot.docs.first.data();
            print('[SellerReviewService] Sample document sellerId: ${sampleDoc['sellerId']}');
          }
        } catch (testError) {
          print('[SellerReviewService] ❌ Error accessing collection: $testError');
        }
        
        return [];
      }
      
      var reviews = <SellerReview>[];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id; // Ensure ID is set
          print('[SellerReviewService] Processing document ${doc.id}: sellerId=${data['sellerId']}, rating=${data['rating']}, isApproved=${data['isApproved']}');
          final review = SellerReview.fromFirestore(data);
          reviews.add(review);
        } catch (e) {
          print('[SellerReviewService] ⚠️ Error parsing document ${doc.id}: $e');
        }
      }

      print('[SellerReviewService] Parsed ${reviews.length} reviews');

      // Filter by approved status if needed
      if (approvedOnly) {
        final beforeFilter = reviews.length;
        reviews = reviews.where((r) => r.isApproved).toList();
        print('[SellerReviewService] Filtered to ${reviews.length} approved reviews (from $beforeFilter total)');
      }

      // Sort by createdAt in memory (descending)
      reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Limit to requested amount
      final result = reviews.take(limit).toList();
      print('[SellerReviewService] ✅ Returning ${result.length} reviews');
      return result;
    } catch (e) {
      print('[SellerReviewService] ❌ Error fetching seller reviews: $e');
      print('[SellerReviewService] Error type: ${e.runtimeType}');
      if (e.toString().contains('permission-denied')) {
        print('[SellerReviewService] ⚠️ Permission denied! Check Firestore rules.');
      }
      if (e.toString().contains('index')) {
        print('[SellerReviewService] ⚠️ Index required! But we should not need one with this query.');
      }
      return [];
    }
  }

  /// Get stream of reviews for a seller (real-time updates)
  static Stream<QuerySnapshot<Map<String, dynamic>>> getSellerReviewsStream({
    required String sellerId,
    bool approvedOnly = true,
    int limit = 50,
  }) {
    // Use simpler query - filter approved in the UI layer
    Query<Map<String, dynamic>> query = _db
        .collection(_collection)
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .limit(limit * 2); // Fetch more to account for filtering

    return query.snapshots();
  }

  /// Get rating breakdown for a seller
  static Future<Map<int, int>> getRatingBreakdown(String sellerId) async {
    try {
      final reviews = await getSellerReviews(sellerId: sellerId);
      final breakdown = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

      for (final review in reviews) {
        final rating = review.rating.round();
        if (rating >= 1 && rating <= 5) {
          breakdown[rating] = (breakdown[rating] ?? 0) + 1;
        }
      }

      return breakdown;
    } catch (e) {
      print('Error getting seller rating breakdown: $e');
      return {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    }
  }

  /// Calculate and update seller average rating
  static Future<void> _updateSellerRating(String sellerId) async {
    try {
      final reviews = await getSellerReviews(sellerId: sellerId);
      if (reviews.isEmpty) {
        return;
      }

      final totalRating = reviews.fold<double>(0.0, (sum, review) => sum + review.rating);
      final averageRating = (totalRating / reviews.length).roundToDouble() / 10.0; // Round to 1 decimal
      final reviewCount = reviews.length;

      // Update in Firestore
      await _db
          .collection('userProfiles')
          .doc(sellerId)
          .collection('sellerProfile')
          .doc('profile')
          .update({
        'averageRating': averageRating,
        'reviewCount': reviewCount,
      });

      // Update in Hive if profile exists
      try {
        final profile = await SellerProfileService.getProfile(sellerId);
        if (profile != null) {
          // Note: Hive objects are immutable, so we'd need to create a new SellerProfile
          // For now, we'll rely on Firestore for rating updates
        }
      } catch (e) {
        // Hive update not critical
      }
    } catch (e) {
      print('Error updating seller rating: $e');
    }
  }
}

