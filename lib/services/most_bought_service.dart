import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order.dart';

class MostBoughtService {
  /// Get most bought items based on order frequency
  /// Returns a list of listing IDs sorted by purchase count (descending)
  static List<String> getMostBoughtListingIds({int limit = 10}) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    final ordersBox = Hive.box<Order>('ordersBox');
    final Map<String, int> purchaseCounts = {};

    // Count purchases per listing
    for (var order in ordersBox.values) {
      if (order.userId == currentUser.uid && 
          order.orderStatus != 'Cancelled' &&
          order.orderStatus != 'RejectedBySeller') {
        final listingId = order.listingId;
        purchaseCounts[listingId] = (purchaseCounts[listingId] ?? 0) + order.quantity;
      }
    }

    // Sort by count (descending) and return top items
    final sorted = purchaseCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) => e.key).toList();
  }

  /// Get most bought items across all users (for "Popular Near You")
  static List<String> getPopularListingIds({int limit = 10}) {
    final ordersBox = Hive.box<Order>('ordersBox');
    final Map<String, int> purchaseCounts = {};

    // Count purchases per listing across all users
    for (var order in ordersBox.values) {
      if (order.orderStatus != 'Cancelled' &&
          order.orderStatus != 'RejectedBySeller') {
        final listingId = order.listingId;
        purchaseCounts[listingId] = (purchaseCounts[listingId] ?? 0) + order.quantity;
      }
    }

    // Sort by count (descending) and return top items
    final sorted = purchaseCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) => e.key).toList();
  }
}

