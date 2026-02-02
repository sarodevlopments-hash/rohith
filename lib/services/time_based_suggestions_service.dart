import 'package:hive/hive.dart';
import '../models/listing.dart';
import '../models/sell_type.dart';

enum TimeOfDayCategory {
  morning,    // 6 AM - 11 AM
  afternoon,  // 11 AM - 4 PM
  evening,    // 4 PM - 8 PM
  night,      // 8 PM - 6 AM
}

class TimeBasedSuggestionsService {
  /// Get current time of day category
  static TimeOfDayCategory getCurrentTimeCategory() {
    final hour = DateTime.now().hour;
    
    if (hour >= 6 && hour < 11) {
      return TimeOfDayCategory.morning;
    } else if (hour >= 11 && hour < 16) {
      return TimeOfDayCategory.afternoon;
    } else if (hour >= 16 && hour < 20) {
      return TimeOfDayCategory.evening;
    } else {
      return TimeOfDayCategory.night;
    }
  }

  /// Get section title based on time of day
  static String getSectionTitle(TimeOfDayCategory category) {
    switch (category) {
      case TimeOfDayCategory.morning:
        return 'Breakfast Picks';
      case TimeOfDayCategory.afternoon:
        return 'Lunch Specials';
      case TimeOfDayCategory.evening:
        return 'Snacks & Beverages';
      case TimeOfDayCategory.night:
        return 'Dinner Favorites';
    }
  }

  /// Get section subtitle based on time of day
  static String getSectionSubtitle(TimeOfDayCategory category) {
    switch (category) {
      case TimeOfDayCategory.morning:
        return 'Start your day right';
      case TimeOfDayCategory.afternoon:
        return 'Perfect for lunch';
      case TimeOfDayCategory.evening:
        return 'Evening treats';
      case TimeOfDayCategory.night:
        return 'Dinner time favorites';
    }
  }

  /// Get emoji for time-based section
  static String getSectionEmoji(TimeOfDayCategory category) {
    switch (category) {
      case TimeOfDayCategory.morning:
        return '🌅';
      case TimeOfDayCategory.afternoon:
        return '☀️';
      case TimeOfDayCategory.evening:
        return '🌆';
      case TimeOfDayCategory.night:
        return '🌙';
    }
  }

  /// Get recommended listings for current time of day
  static List<Listing> getTimeBasedListings(TimeOfDayCategory category) {
    try {
      if (!Hive.isBoxOpen('listingBox')) {
        return [];
      }
      
      final listingBox = Hive.box<Listing>('listingBox');
      final allListings = listingBox.values
          .where((listing) => 
              listing.quantity > 0 || 
              (listing.isLiveKitchen && listing.isLiveKitchenAvailable))
          .toList();

    // Filter and prioritize based on time category
    List<Listing> filtered = [];
    
    switch (category) {
      case TimeOfDayCategory.morning:
        // Prioritize: cookedFood, liveKitchen (breakfast items)
        filtered = allListings
            .where((l) => l.type == SellType.cookedFood || l.type == SellType.liveKitchen)
            .toList();
        break;
      case TimeOfDayCategory.afternoon:
        // Prioritize: cookedFood, liveKitchen (lunch items)
        filtered = allListings
            .where((l) => l.type == SellType.cookedFood || l.type == SellType.liveKitchen)
            .toList();
        break;
      case TimeOfDayCategory.evening:
        // Prioritize: cookedFood, liveKitchen, groceries (snacks)
        filtered = allListings
            .where((l) => 
                l.type == SellType.cookedFood || 
                l.type == SellType.liveKitchen ||
                l.type == SellType.groceries)
            .toList();
        break;
      case TimeOfDayCategory.night:
        // Prioritize: cookedFood, liveKitchen (dinner items)
        filtered = allListings
            .where((l) => l.type == SellType.cookedFood || l.type == SellType.liveKitchen)
            .toList();
        break;
    }

    // Sort by discount (items with discounts first) and take top 10
    filtered.sort((a, b) {
      final discountA = a.originalPrice != null
          ? ((a.originalPrice! - a.price) / a.originalPrice!) * 100
          : 0;
      final discountB = b.originalPrice != null
          ? ((b.originalPrice! - b.price) / b.originalPrice!) * 100
          : 0;
      return discountB.compareTo(discountA);
    });

    return filtered.take(10).toList();
    } catch (e) {
      // Return empty list on any error
      return [];
    }
  }
}

