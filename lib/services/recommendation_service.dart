import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/listing.dart';
import '../models/order.dart';
import '../models/sell_type.dart';
import 'recently_viewed_service.dart';
import 'most_bought_service.dart';

class RecommendationService {
  /// Get personalized recommendations for the current user
  /// Based on: past orders, browsing history, frequently viewed categories
  static Future<List<String>> getRecommendedListingIds({int limit = 10}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    try {
      if (!Hive.isBoxOpen('listingBox') || !Hive.isBoxOpen('ordersBox')) {
        return [];
      }
      
      final listingBox = Hive.box<Listing>('listingBox');
      final ordersBox = Hive.box<Order>('ordersBox');
    
    // 1. Get user's past orders to understand preferences
    final userOrders = ordersBox.values
        .where((order) => 
            order.userId == currentUser.uid &&
            order.orderStatus != 'Cancelled' &&
            order.orderStatus != 'RejectedBySeller')
        .toList();

    // 2. Get frequently ordered categories
    final categoryFrequency = <SellType, int>{};
    for (var order in userOrders) {
      try {
        final listingId = int.tryParse(order.listingId);
        if (listingId != null) {
          final listing = listingBox.get(listingId);
          if (listing != null) {
            categoryFrequency[listing.type] = 
                (categoryFrequency[listing.type] ?? 0) + order.quantity;
          }
        }
      } catch (e) {
        // Skip invalid listings
      }
    }

    // 3. Get recently viewed items
    final recentlyViewedIds = await RecentlyViewedService.getRecentlyViewedIds();
    
    // 4. Get most bought items (user-specific)
    final mostBoughtIds = MostBoughtService.getMostBoughtListingIds(limit: 5);

    // 5. Score and rank listings
    final Map<String, double> listingScores = {};
    
    // Score based on category preference
    final topCategories = categoryFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final allListings = listingBox.values.toList();
    for (var listing in allListings) {
      if (listing.quantity <= 0 && !(listing.isLiveKitchen && listing.isLiveKitchenAvailable)) {
        continue;
      }
      
      double score = 0.0;
      final listingId = listing.key.toString();
      
      // Category preference score (higher for preferred categories)
      if (topCategories.isNotEmpty) {
        final categoryRank = topCategories.indexWhere((e) => e.key == listing.type);
        if (categoryRank >= 0) {
          score += (topCategories.length - categoryRank) * 2.0;
        }
      }
      
      // Recently viewed boost
      if (recentlyViewedIds.contains(listingId)) {
        final index = recentlyViewedIds.indexOf(listingId);
        score += (recentlyViewedIds.length - index) * 1.5;
      }
      
      // Most bought boost
      if (mostBoughtIds.contains(listingId)) {
        final index = mostBoughtIds.indexOf(listingId);
        score += (mostBoughtIds.length - index) * 1.0;
      }
      
      // Discount boost (items with discounts get slight boost)
      if (listing.originalPrice != null && listing.originalPrice! > listing.price) {
        score += 0.5;
      }
      
      if (score > 0) {
        listingScores[listingId] = score;
      }
    }

    // Sort by score and return top items
    final sorted = listingScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) => e.key).toList();
    } catch (e) {
      // Return empty list on any error
      return [];
    }
  }
}

