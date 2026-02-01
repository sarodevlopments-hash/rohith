import 'package:hive/hive.dart';
import '../models/listing.dart';

/// Service to provide product name suggestions for autocomplete functionality.
/// Priority order: Seller's previous items > Popular items > Static fallback list
class ProductSuggestionService {
  static Box<Listing> get _listingBox => Hive.box<Listing>('listingBox');

  /// Static fallback product names organized by category
  static const Map<String, List<String>> _staticSuggestions = {
    'food': [
      'Burger',
      'Chicken Burger',
      'Veg Burger',
      'Cheese Burger',
      'Pizza',
      'Veg Pizza',
      'Chicken Pizza',
      'Margherita Pizza',
      'Biryani',
      'Chicken Biryani',
      'Mutton Biryani',
      'Veg Biryani',
      'Fried Rice',
      'Egg Fried Rice',
      'Chicken Fried Rice',
      'Veg Fried Rice',
      'Noodles',
      'Hakka Noodles',
      'Chow Mein',
      'Pasta',
      'White Sauce Pasta',
      'Red Sauce Pasta',
      'Sandwich',
      'Grilled Sandwich',
      'Club Sandwich',
      'Wrap',
      'Chicken Wrap',
      'Paneer Wrap',
      'Dosa',
      'Masala Dosa',
      'Plain Dosa',
      'Idli',
      'Idli Sambar',
      'Vada',
      'Medu Vada',
      'Samosa',
      'Pav Bhaji',
      'Chole Bhature',
      'Paratha',
      'Aloo Paratha',
      'Paneer Paratha',
      'Thali',
      'Veg Thali',
      'Non-Veg Thali',
      'Dal',
      'Dal Makhani',
      'Dal Tadka',
      'Paneer',
      'Paneer Butter Masala',
      'Shahi Paneer',
      'Kadai Paneer',
      'Palak Paneer',
      'Chicken',
      'Butter Chicken',
      'Chicken Curry',
      'Tandoori Chicken',
      'Chicken 65',
      'Roti',
      'Naan',
      'Butter Naan',
      'Garlic Naan',
      'Kulcha',
      'Pulao',
      'Jeera Rice',
      'Raita',
      'Salad',
      'Soup',
      'Tomato Soup',
      'Sweet Corn Soup',
      'Manchurian',
      'Gobi Manchurian',
      'Chicken Manchurian',
      'Momos',
      'Veg Momos',
      'Chicken Momos',
      'Spring Roll',
      'Cake',
      'Pastry',
      'Brownie',
      'Ice Cream',
      'Milkshake',
      'Lassi',
      'Juice',
      'Coffee',
      'Tea',
      'Chai',
    ],
    'groceries': [
      'Rice',
      'Basmati Rice',
      'Brown Rice',
      'Wheat',
      'Wheat Flour',
      'Atta',
      'Maida',
      'Besan',
      'Dal',
      'Toor Dal',
      'Moong Dal',
      'Chana Dal',
      'Urad Dal',
      'Masoor Dal',
      'Sugar',
      'Salt',
      'Oil',
      'Sunflower Oil',
      'Mustard Oil',
      'Coconut Oil',
      'Olive Oil',
      'Ghee',
      'Butter',
      'Milk',
      'Curd',
      'Paneer',
      'Cheese',
      'Eggs',
      'Bread',
      'Biscuits',
      'Tea',
      'Coffee',
      'Spices',
      'Turmeric',
      'Red Chilli',
      'Coriander',
      'Cumin',
      'Garam Masala',
      'Pickle',
      'Jam',
      'Honey',
      'Noodles',
      'Pasta',
      'Oats',
      'Cornflakes',
      'Poha',
      'Upma',
      'Vermicelli',
    ],
    'vegetables': [
      'Potato',
      'Onion',
      'Tomato',
      'Carrot',
      'Cabbage',
      'Cauliflower',
      'Brinjal',
      'Lady Finger',
      'Spinach',
      'Methi',
      'Coriander Leaves',
      'Mint',
      'Green Chilli',
      'Ginger',
      'Garlic',
      'Cucumber',
      'Bottle Gourd',
      'Bitter Gourd',
      'Ridge Gourd',
      'Capsicum',
      'Beans',
      'Peas',
      'Corn',
      'Mushroom',
      'Beetroot',
      'Radish',
      'Lemon',
      'Coconut',
    ],
    'clothing': [
      'T-Shirt',
      'Shirt',
      'Jeans',
      'Trousers',
      'Dress',
      'Skirt',
      'Jacket',
      'Sweater',
      'Hoodie',
      'Shorts',
      'Pants',
      'Blazer',
      'Coat',
      'Sweatshirt',
      'Leggings',
      'Socks',
      'Underwear',
      'Bra',
      'Pyjamas',
      'Nightwear',
      'Saree',
      'Kurta',
      'Salwar',
      'Dupatta',
      'Lehenga',
      'Sherwani',
      'Dhoti',
      'Lungi',
      'Tie',
      'Belt',
      'Cap',
      'Hat',
      'Scarf',
      'Gloves',
      'Muffler',
      'Sunglasses',
      'Watch',
      'Wallet',
      'Bag',
      'Backpack',
    ],
    'other': [
      'Soap',
      'Shampoo',
      'Toothpaste',
      'Toothbrush',
      'Face Wash',
      'Body Lotion',
      'Hand Sanitizer',
      'Tissue Paper',
      'Detergent',
      'Dish Wash',
      'Floor Cleaner',
      'Air Freshener',
      'Candle',
      'Matchbox',
      'Battery',
      'Light Bulb',
      'Newspaper',
      'Notebook',
      'Pen',
      'Pencil',
    ],
  };

  /// Get product name suggestions based on the query
  /// Priority: Seller's items > Popular items > Static list
  static List<String> getSuggestions(String query, {String? sellerId, String? category}) {
    if (query.length < 2) return [];

    final queryLower = query.toLowerCase().trim();
    final suggestions = <String>{}; // Using Set to avoid duplicates
    
    // 1. First priority: Seller's previous product names
    if (sellerId != null) {
      final sellerProducts = _getSellerProductNames(sellerId);
      for (final name in sellerProducts) {
        if (name.toLowerCase().contains(queryLower)) {
          suggestions.add(name);
        }
      }
    }

    // 2. Second priority: Popular items across platform
    final popularProducts = _getPopularProductNames();
    for (final name in popularProducts) {
      if (name.toLowerCase().contains(queryLower)) {
        suggestions.add(name);
      }
    }

    // 3. Third priority: Static fallback list
    final staticProducts = _getStaticSuggestions(category);
    for (final name in staticProducts) {
      if (name.toLowerCase().contains(queryLower)) {
        suggestions.add(name);
      }
    }

    // Sort suggestions - exact prefix matches first, then alphabetically
    final sortedSuggestions = suggestions.toList();
    sortedSuggestions.sort((a, b) {
      final aStartsWith = a.toLowerCase().startsWith(queryLower);
      final bStartsWith = b.toLowerCase().startsWith(queryLower);
      
      if (aStartsWith && !bStartsWith) return -1;
      if (!aStartsWith && bStartsWith) return 1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });

    // Limit to top 10 suggestions for better UX
    return sortedSuggestions.take(10).toList();
  }

  /// Get unique product names from seller's previous listings
  static List<String> _getSellerProductNames(String sellerId) {
    try {
      final listings = _listingBox.values
          .where((listing) => listing.sellerId == sellerId)
          .toList();
      
      // Get unique names and sort by most recent (assuming newer items are at end)
      final names = <String>{};
      for (final listing in listings.reversed) {
        names.add(listing.name);
      }
      return names.toList();
    } catch (e) {
      return [];
    }
  }

  /// Get popular product names across the platform
  /// (based on frequency of listings)
  static List<String> _getPopularProductNames() {
    try {
      final nameCount = <String, int>{};
      
      for (final listing in _listingBox.values) {
        final name = listing.name;
        nameCount[name] = (nameCount[name] ?? 0) + 1;
      }
      
      // Sort by popularity (count)
      final sortedNames = nameCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      return sortedNames.take(50).map((e) => e.key).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get static suggestions, optionally filtered by category
  static List<String> _getStaticSuggestions(String? category) {
    if (category != null && _staticSuggestions.containsKey(category.toLowerCase())) {
      return _staticSuggestions[category.toLowerCase()]!;
    }
    
    // Return all static suggestions if no category specified
    final allSuggestions = <String>[];
    for (final list in _staticSuggestions.values) {
      allSuggestions.addAll(list);
    }
    return allSuggestions;
  }

  /// Get category string from SellType for filtering suggestions
  static String? getCategoryFromSellType(dynamic sellType) {
    final typeStr = sellType.toString().toLowerCase();
    if (typeStr.contains('cookedfood') || typeStr.contains('cooked')) {
      return 'food';
    } else if (typeStr.contains('groceries')) {
      return 'groceries';
    } else if (typeStr.contains('vegetables')) {
      return 'vegetables';
    } else if (typeStr.contains('clothing') || typeStr.contains('apparel')) {
      return 'clothing';
    }
    return 'other';
  }
}

