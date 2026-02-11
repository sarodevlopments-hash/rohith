import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Date range enum for filtering metrics
enum DateRange {
  today,
  last7Days,
  last30Days,
  custom,
}

/// Service to fetch aggregated metrics for Owner Dashboard
/// Uses Firestore queries optimized for performance
class AdminMetricsService {
  static FirebaseFirestore get _db => FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'reqfood',
  );

  /// Helper to safely convert Firestore document data to Map<String, dynamic>
  /// Handles LinkedMap<dynamic, dynamic> from web platform
  static Map<String, dynamic> _safeDataMap(dynamic data) {
    if (data == null) return {};
    
    try {
      // Handle LinkedMap<dynamic, dynamic> from web
      if (data is Map) {
        // Convert all keys to String and values appropriately
        return Map<String, dynamic>.fromEntries(
          data.entries.map((e) {
            final key = e.key.toString();
            var value = e.value;
            // Recursively convert nested maps
            if (value is Map) {
              value = _safeDataMap(value);
            }
            return MapEntry(key, value);
          }),
        );
      }
    } catch (e) {
      print('Error converting Firestore data: $e');
    }
    
    return {};
  }

  /// Get date range boundaries
  static Map<String, DateTime> _getDateRange(DateRange range, {DateTime? start, DateTime? end}) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    
    switch (range) {
      case DateRange.today:
        return {'start': todayStart, 'end': now};
      case DateRange.last7Days:
        return {'start': todayStart.subtract(const Duration(days: 7)), 'end': now};
      case DateRange.last30Days:
        return {'start': todayStart.subtract(const Duration(days: 30)), 'end': now};
      case DateRange.custom:
        return {'start': start ?? todayStart, 'end': end ?? now};
    }
  }

  /// KPI Metrics Model
  static Future<Map<String, dynamic>> getKPIMetrics({
    DateRange dateRange = DateRange.last30Days,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    final dates = _getDateRange(dateRange, start: customStart, end: customEnd);
    final startDate = dates['start']!;
    final endDate = dates['end']!;

    // Get previous period for comparison
    final periodDuration = endDate.difference(startDate);
    final prevStartDate = startDate.subtract(periodDuration);
    final prevEndDate = startDate;

    try {
      // Fetch all users
      final usersSnapshot = await _db.collection('userProfiles').get();
      final totalUsers = usersSnapshot.docs.length;
      print('DEBUG: Found $totalUsers users in userProfiles collection');

      // Fetch all orders (try with date filter first, if empty, fetch all)
      QuerySnapshot ordersSnapshot;
      try {
        ordersSnapshot = await _db.collection('orders')
            .where('purchasedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .where('purchasedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
            .get();
      } catch (e) {
        print('DEBUG: Date-filtered query failed, trying without date filter: $e');
        // If date query fails, try fetching all orders
        ordersSnapshot = await _db.collection('orders').get();
      }
      print('DEBUG: Found ${ordersSnapshot.docs.length} orders in date range');

      final prevOrdersSnapshot = await _db.collection('orders')
          .where('purchasedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(prevStartDate))
          .where('purchasedAt', isLessThan: Timestamp.fromDate(prevEndDate))
          .get();

      // Fetch today's orders
      final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      QuerySnapshot todayOrdersSnapshot;
      try {
        todayOrdersSnapshot = await _db.collection('orders')
            .where('purchasedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .get();
      } catch (e) {
        print('DEBUG: Today orders query failed: $e');
        todayOrdersSnapshot = await _db.collection('orders').get();
      }
      print('DEBUG: Found ${todayOrdersSnapshot.docs.length} orders today');

      // Fetch all listings to identify sellers
      final listingsSnapshot = await _db.collection('listings').get();
      print('DEBUG: Found ${listingsSnapshot.docs.length} listings');
      final sellerIds = listingsSnapshot.docs
          .map((doc) => _safeDataMap(doc.data())['sellerId'] as String?)
          .where((id) => id != null)
          .toSet()
          .toList();
      print('DEBUG: Found ${sellerIds.length} unique sellers');

      // Calculate metrics
      double totalRevenue = 0;
      double prevRevenue = 0;
      int totalOrders = ordersSnapshot.docs.length;
      int prevOrders = prevOrdersSnapshot.docs.length;
      int ordersToday = todayOrdersSnapshot.docs.length;
      int cancelledOrders = 0;
      int activeUsersToday = 0;

      final todayUserIds = <String>{};

      for (var doc in ordersSnapshot.docs) {
        final data = _safeDataMap(doc.data());
        final status = data['orderStatus'] as String? ?? '';
        final pricePaid = (data['pricePaid'] as num?)?.toDouble() ?? 0.0;
        totalRevenue += pricePaid;
        
        if (status.toLowerCase().contains('cancel')) {
          cancelledOrders++;
        }

        final userId = data['userId'] as String?;
        if (userId != null) {
          final purchasedAt = (data['purchasedAt'] as Timestamp?)?.toDate();
          if (purchasedAt != null && purchasedAt.isAfter(todayStart)) {
            todayUserIds.add(userId);
          }
        }
      }

      for (var doc in prevOrdersSnapshot.docs) {
        final data = _safeDataMap(doc.data());
        final pricePaid = (data['pricePaid'] as num?)?.toDouble() ?? 0.0;
        prevRevenue += pricePaid;
      }

      activeUsersToday = todayUserIds.length;

      // Get buyers count (users who have placed orders)
      final buyerIds = ordersSnapshot.docs
          .map((doc) => _safeDataMap(doc.data())['userId'] as String?)
          .where((id) => id != null)
          .toSet();

      // Calculate percentage changes
      final revenueChange = prevRevenue > 0 
          ? ((totalRevenue - prevRevenue) / prevRevenue * 100)
          : (totalRevenue > 0 ? 100.0 : 0.0);
      
      final ordersChange = prevOrders > 0
          ? ((totalOrders - prevOrders) / prevOrders * 100)
          : (totalOrders > 0 ? 100.0 : 0.0);

      final result = {
        'totalUsers': totalUsers,
        'totalSellers': sellerIds.length,
        'totalBuyers': buyerIds.length,
        'activeUsersToday': activeUsersToday,
        'totalOrders': totalOrders,
        'totalRevenue': totalRevenue,
        'ordersToday': ordersToday,
        'cancelledOrders': cancelledOrders,
        'revenueChange': revenueChange,
        'ordersChange': ordersChange,
      };
      print('DEBUG: KPI Metrics result: $result');
      return result;
    } catch (e, stackTrace) {
      print('Error fetching KPI metrics: $e');
      print('Stack trace: $stackTrace');
      return {
        'totalUsers': 0,
        'totalSellers': 0,
        'totalBuyers': 0,
        'activeUsersToday': 0,
        'totalOrders': 0,
        'totalRevenue': 0.0,
        'ordersToday': 0,
        'cancelledOrders': 0,
        'revenueChange': 0.0,
        'ordersChange': 0.0,
      };
    }
  }

  /// Get new users per day
  static Future<List<Map<String, dynamic>>> getNewUsersPerDay({
    DateRange dateRange = DateRange.last30Days,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    final dates = _getDateRange(dateRange, start: customStart, end: customEnd);
    final startDate = dates['start']!;
    final endDate = dates['end']!;

    try {
      // Try with createdAt field first, if that fails, fetch all users
      QuerySnapshot usersSnapshot;
      try {
        usersSnapshot = await _db.collection('userProfiles')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
            .get();
      } catch (e) {
        print('DEBUG: createdAt query failed, fetching all users: $e');
        // If createdAt field doesn't exist, fetch all users and filter manually
        final allUsers = await _db.collection('userProfiles').get();
        usersSnapshot = allUsers;
      }

      final Map<String, int> dailyCounts = {};
      
      for (var doc in usersSnapshot.docs) {
        final data = _safeDataMap(doc.data());
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null) {
          final dateKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
          dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
        }
      }

      // Fill in missing dates with 0
      final List<Map<String, dynamic>> result = [];
      var currentDate = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      
      while (currentDate.isBefore(end) || currentDate.isAtSameMomentAs(end)) {
        final dateKey = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
        result.add({
          'date': dateKey,
          'count': dailyCounts[dateKey] ?? 0,
        });
        currentDate = currentDate.add(const Duration(days: 1));
      }

      return result;
    } catch (e) {
      print('Error fetching new users per day: $e');
      return [];
    }
  }

  /// Get orders per day
  static Future<List<Map<String, dynamic>>> getOrdersPerDay({
    DateRange dateRange = DateRange.last30Days,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    final dates = _getDateRange(dateRange, start: customStart, end: customEnd);
    final startDate = dates['start']!;
    final endDate = dates['end']!;

    try {
      QuerySnapshot ordersSnapshot;
      try {
        ordersSnapshot = await _db.collection('orders')
            .where('purchasedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .where('purchasedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
            .get();
      } catch (e) {
        print('DEBUG: Orders per day date query failed, fetching all: $e');
        ordersSnapshot = await _db.collection('orders').get();
      }

      final Map<String, int> dailyCounts = {};
      
      for (var doc in ordersSnapshot.docs) {
        final data = _safeDataMap(doc.data());
        final purchasedAt = (data['purchasedAt'] as Timestamp?)?.toDate();
        if (purchasedAt != null) {
          final dateKey = '${purchasedAt.year}-${purchasedAt.month.toString().padLeft(2, '0')}-${purchasedAt.day.toString().padLeft(2, '0')}';
          dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
        }
      }

      // Fill in missing dates with 0
      final List<Map<String, dynamic>> result = [];
      var currentDate = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      
      while (currentDate.isBefore(end) || currentDate.isAtSameMomentAs(end)) {
        final dateKey = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
        result.add({
          'date': dateKey,
          'count': dailyCounts[dateKey] ?? 0,
        });
        currentDate = currentDate.add(const Duration(days: 1));
      }

      return result;
    } catch (e) {
      print('Error fetching orders per day: $e');
      return [];
    }
  }

  /// Get revenue per day
  static Future<List<Map<String, dynamic>>> getRevenuePerDay({
    DateRange dateRange = DateRange.last30Days,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    final dates = _getDateRange(dateRange, start: customStart, end: customEnd);
    final startDate = dates['start']!;
    final endDate = dates['end']!;

    try {
      QuerySnapshot ordersSnapshot;
      try {
        ordersSnapshot = await _db.collection('orders')
            .where('purchasedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .where('purchasedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
            .get();
      } catch (e) {
        print('DEBUG: Revenue per day date query failed, fetching all: $e');
        ordersSnapshot = await _db.collection('orders').get();
      }

      final Map<String, double> dailyRevenue = {};
      
      for (var doc in ordersSnapshot.docs) {
        final data = _safeDataMap(doc.data());
        final purchasedAt = (data['purchasedAt'] as Timestamp?)?.toDate();
        final pricePaid = (data['pricePaid'] as num?)?.toDouble() ?? 0.0;
        
        if (purchasedAt != null) {
          final dateKey = '${purchasedAt.year}-${purchasedAt.month.toString().padLeft(2, '0')}-${purchasedAt.day.toString().padLeft(2, '0')}';
          dailyRevenue[dateKey] = (dailyRevenue[dateKey] ?? 0.0) + pricePaid;
        }
      }

      // Fill in missing dates with 0
      final List<Map<String, dynamic>> result = [];
      var currentDate = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      
      while (currentDate.isBefore(end) || currentDate.isAtSameMomentAs(end)) {
        final dateKey = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
        result.add({
          'date': dateKey,
          'revenue': dailyRevenue[dateKey] ?? 0.0,
        });
        currentDate = currentDate.add(const Duration(days: 1));
      }

      return result;
    } catch (e) {
      print('Error fetching revenue per day: $e');
      return [];
    }
  }

  /// Get seller insights
  static Future<Map<String, dynamic>> getSellerInsights() async {
    try {
      final listingsSnapshot = await _db.collection('listings').get();
      final ordersSnapshot = await _db.collection('orders').get();
      
      final Map<String, Map<String, dynamic>> sellerStats = {};
      final Set<String> activeSellersLast7Days = {};
      final Set<String> inactiveSellers = {};
      final Set<String> allSellerIds = {};

      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

      // Process listings
      for (var doc in listingsSnapshot.docs) {
        final data = _safeDataMap(doc.data());
        final sellerId = data['sellerId'] as String?;
        if (sellerId != null) {
          allSellerIds.add(sellerId);
          sellerStats[sellerId] = {
            'sellerId': sellerId,
            'sellerName': data['sellerName'] as String? ?? 'Unknown',
            'totalItems': 0,
            'totalOrders': 0,
            'revenue': 0.0,
            'status': 'inactive',
            'sellerType': 'Regular', // Default
          };
        }
      }

      // Count items per seller
      for (var doc in listingsSnapshot.docs) {
        final data = _safeDataMap(doc.data());
        final sellerId = data['sellerId'] as String?;
        if (sellerId != null && sellerStats.containsKey(sellerId)) {
          sellerStats[sellerId]!['totalItems'] = (sellerStats[sellerId]!['totalItems'] as int) + 1;
        }
      }

      // Process orders
      for (var doc in ordersSnapshot.docs) {
        final data = _safeDataMap(doc.data());
        final sellerId = data['sellerId'] as String?;
        final purchasedAt = (data['purchasedAt'] as Timestamp?)?.toDate();
        final pricePaid = (data['pricePaid'] as num?)?.toDouble() ?? 0.0;

        if (sellerId != null && sellerStats.containsKey(sellerId)) {
          sellerStats[sellerId]!['totalOrders'] = (sellerStats[sellerId]!['totalOrders'] as int) + 1;
          sellerStats[sellerId]!['revenue'] = (sellerStats[sellerId]!['revenue'] as double) + pricePaid;
          
          if (purchasedAt != null && purchasedAt.isAfter(sevenDaysAgo)) {
            activeSellersLast7Days.add(sellerId);
            sellerStats[sellerId]!['status'] = 'active';
          }
        }
      }

      // Identify inactive sellers
      inactiveSellers.addAll(allSellerIds.where((id) => !activeSellersLast7Days.contains(id)));

      final sellerList = sellerStats.values.toList();
      sellerList.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));

      return {
        'activeSellers': activeSellersLast7Days.length,
        'inactiveSellers': inactiveSellers.length,
        'newSellersPending': 0, // Would need approval system
        'regularSellers': sellerList.length,
        'casualSellers': 0, // Would need to define criteria
        'farmersCount': 0, // Would need seller type field
        'sellerList': sellerList,
      };
    } catch (e) {
      print('Error fetching seller insights: $e');
      return {
        'activeSellers': 0,
        'inactiveSellers': 0,
        'newSellersPending': 0,
        'regularSellers': 0,
        'casualSellers': 0,
        'farmersCount': 0,
        'sellerList': [],
      };
    }
  }

  /// Get buyer insights
  static Future<Map<String, dynamic>> getBuyerInsights() async {
    try {
      final ordersSnapshot = await _db.collection('orders').get();
      final usersSnapshot = await _db.collection('userProfiles').get();
      
      final Map<String, int> buyerOrderCounts = {};
      final Set<String> repeatBuyers = {};
      final Set<String> buyersWithOrders = {};
      final Set<String> newBuyersToday = {};
      final Set<String> buyersWithNoOrders = {};

      final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

      // Process orders
      for (var doc in ordersSnapshot.docs) {
        final data = _safeDataMap(doc.data());
        final userId = data['userId'] as String?;
        final purchasedAt = (data['purchasedAt'] as Timestamp?)?.toDate();
        
        if (userId != null) {
          buyersWithOrders.add(userId);
          buyerOrderCounts[userId] = (buyerOrderCounts[userId] ?? 0) + 1;
          
          if (buyerOrderCounts[userId]! > 1) {
            repeatBuyers.add(userId);
          }
          
          if (purchasedAt != null && purchasedAt.isAfter(todayStart)) {
            newBuyersToday.add(userId);
          }
        }
      }

      // Find buyers with no orders
      for (var doc in usersSnapshot.docs) {
        final userId = doc.id;
        if (!buyersWithOrders.contains(userId)) {
          buyersWithNoOrders.add(userId);
        }
      }

      final totalBuyers = buyersWithOrders.length;
      final avgOrdersPerBuyer = totalBuyers > 0 
          ? ordersSnapshot.docs.length / totalBuyers 
          : 0.0;

      return {
        'repeatBuyers': repeatBuyers.length,
        'avgOrdersPerBuyer': avgOrdersPerBuyer,
        'newBuyersToday': newBuyersToday.length,
        'buyersWithNoOrders': buyersWithNoOrders.length,
        'totalBuyers': totalBuyers,
        'newBuyers': buyersWithOrders.length - repeatBuyers.length,
      };
    } catch (e) {
      print('Error fetching buyer insights: $e');
      return {
        'repeatBuyers': 0,
        'avgOrdersPerBuyer': 0.0,
        'newBuyersToday': 0,
        'buyersWithNoOrders': 0,
        'totalBuyers': 0,
        'newBuyers': 0,
      };
    }
  }

  /// Get product & category performance
  static Future<Map<String, dynamic>> getProductPerformance() async {
    try {
      final listingsSnapshot = await _db.collection('listings').get();
      final ordersSnapshot = await _db.collection('orders').get();
      
      final Map<String, Map<String, dynamic>> productStats = {};
      final Map<String, int> categoryCounts = {};
      final Map<int, int> hourCounts = {}; // Orders by hour

      // Process listings
      for (var doc in listingsSnapshot.docs) {
        final data = _safeDataMap(doc.data());
        final listingId = doc.id;
        final category = data['category'] as String? ?? 'Unknown';
        final type = data['type'] as String? ?? 'Unknown';
        
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
        
        productStats[listingId] = {
          'listingId': listingId,
          'name': data['name'] as String? ?? 'Unknown',
          'category': category,
          'type': type,
          'unitsSold': 0,
          'revenue': 0.0,
          'sellerName': data['sellerName'] as String? ?? 'Unknown',
        };
      }

      // Process orders
      for (var doc in ordersSnapshot.docs) {
        final data = _safeDataMap(doc.data());
        final listingId = data['listingId'] as String?;
        final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
        final pricePaid = (data['pricePaid'] as num?)?.toDouble() ?? 0.0;
        final purchasedAt = (data['purchasedAt'] as Timestamp?)?.toDate();
        
        if (listingId != null && productStats.containsKey(listingId)) {
          productStats[listingId]!['unitsSold'] = (productStats[listingId]!['unitsSold'] as int) + quantity;
          productStats[listingId]!['revenue'] = (productStats[listingId]!['revenue'] as double) + pricePaid;
        }

        // Track ordering hours
        if (purchasedAt != null) {
          final hour = purchasedAt.hour;
          hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
        }
      }

      // Get top products
      final productList = productStats.values.toList();
      productList.sort((a, b) => (b['unitsSold'] as int).compareTo(a['unitsSold'] as int));
      final topProducts = productList.take(10).toList();

      // Get peak ordering time
      int peakHour = 0;
      int maxOrders = 0;
      for (var entry in hourCounts.entries) {
        if (entry.value > maxOrders) {
          maxOrders = entry.value;
          peakHour = entry.key;
        }
      }

      String peakTime;
      if (peakHour >= 6 && peakHour < 12) {
        peakTime = 'Morning';
      } else if (peakHour >= 12 && peakHour < 18) {
        peakTime = 'Afternoon';
      } else {
        peakTime = 'Evening';
      }

      return {
        'topCategories': categoryCounts,
        'topProducts': topProducts,
        'peakOrderingTime': peakTime,
        'peakHour': peakHour,
        'allProducts': productList,
      };
    } catch (e) {
      print('Error fetching product performance: $e');
      return {
        'topCategories': {},
        'topProducts': [],
        'peakOrderingTime': 'Unknown',
        'peakHour': 0,
        'allProducts': [],
      };
    }
  }

  /// Get platform health & alerts
  static Future<Map<String, dynamic>> getPlatformHealth() async {
    try {
      final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final ordersSnapshot = await _db.collection('orders')
          .where('purchasedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .get();

      int failedPayments = 0;
      int cancelledOrders = 0;
      final Map<String, int> sellerCancellationCounts = {};
      final Set<String> reportedProducts = {};
      final Set<String> outOfStockProducts = {};

      for (var doc in ordersSnapshot.docs) {
        final data = _safeDataMap(doc.data());
        final status = data['orderStatus'] as String? ?? '';
        final sellerId = data['sellerId'] as String?;
        
        if (status.toLowerCase().contains('payment') && status.toLowerCase().contains('pending')) {
          failedPayments++;
        }
        
        if (status.toLowerCase().contains('cancel')) {
          cancelledOrders++;
          if (sellerId != null) {
            sellerCancellationCounts[sellerId] = (sellerCancellationCounts[sellerId] ?? 0) + 1;
          }
        }
      }

      // Check out of stock (would need inventory tracking)
      final listingsSnapshot = await _db.collection('listings').get();
      for (var doc in listingsSnapshot.docs) {
        final data = _safeDataMap(doc.data());
        final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
        if (quantity <= 0) {
          outOfStockProducts.add(doc.id);
        }
      }

      // Find sellers with high cancellation rate
      final highCancellationSellers = sellerCancellationCounts.entries
          .where((e) => e.value >= 3) // 3+ cancellations today
          .map((e) => e.key)
          .toList();

      return {
        'failedPaymentsToday': failedPayments,
        'highCancellationSellers': highCancellationSellers.length,
        'reportedProducts': reportedProducts.length,
        'outOfStockAlerts': outOfStockProducts.length,
        'cancelledOrdersToday': cancelledOrders,
      };
    } catch (e) {
      print('Error fetching platform health: $e');
      return {
        'failedPaymentsToday': 0,
        'highCancellationSellers': 0,
        'reportedProducts': 0,
        'outOfStockAlerts': 0,
        'cancelledOrdersToday': 0,
      };
    }
  }
}

