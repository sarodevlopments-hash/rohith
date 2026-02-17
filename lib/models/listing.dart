import 'package:hive/hive.dart';
import 'sell_type.dart';
import 'food_category.dart';
import 'clothing_category.dart';
import 'cooked_food_source.dart';
import 'measurement_unit.dart';
import 'pack_size.dart';
import 'size_color_combination.dart';

part 'listing.g.dart';

@HiveType(typeId: 3)
class Listing extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String sellerName;

  @HiveField(2)
  final double price;

  @HiveField(3)
  final double? originalPrice;

  @HiveField(4)
  int quantity;

  @HiveField(5)
  final SellType type;

  @HiveField(6)
  final String? fssaiLicense;

  @HiveField(7)
  final DateTime? preparedAt;

  @HiveField(8)
  final DateTime? expiryDate;

  @HiveField(9)
  final FoodCategory category;

  @HiveField(10)
  final CookedFoodSource? cookedFoodSource;

  @HiveField(11)
  final int initialQuantity;

  @HiveField(12)
  String sellerId;

  @HiveField(13)
  final String? imagePath; // Path to product image

  @HiveField(14)
  final MeasurementUnit? measurementUnit; // For groceries/vegetables

  @HiveField(15)
  final List<PackSize>? packSizes; // Multiple pack sizes for groceries (e.g., 5kg=₹100, 250gm=₹50)

  @HiveField(16, defaultValue: false)
  final bool isBulkFood; // Whether this is a bulk/catering food item

  @HiveField(17)
  final int? servesCount; // Number of people this bulk item serves (e.g., 25 people)

  @HiveField(18)
  final String? portionDescription; // Description like "Full handi", "Large vessel", "Catering pack"

  // Live Kitchen fields
  @HiveField(19, defaultValue: false)
  bool isKitchenOpen; // Whether kitchen is currently accepting orders

  @HiveField(20)
  final int? preparationTimeMinutes; // Estimated preparation time per order (e.g., 15-30 mins)

  @HiveField(21)
  final int? maxCapacity; // Maximum number of orders available

  @HiveField(22, defaultValue: 0)
  int currentOrders; // Current number of pending orders (for capacity tracking)

  @HiveField(23)
  final ClothingCategory? clothingCategory; // For clothing and apparel items

  @HiveField(24)
  final String? description; // Product description (brand, details, etc.)

  @HiveField(25)
  final List<String>? availableSizes; // Available sizes (e.g., ["S", "M", "L", "XL"]) - deprecated, use sizeColorCombinations

  @HiveField(26)
  final List<String>? availableColors; // Available colors (e.g., ["Red", "Blue", "Black"]) - deprecated, use sizeColorCombinations

  @HiveField(27)
  final List<SizeColorCombination>? sizeColorCombinations; // Size-color combinations (e.g., S: [Red, Blue], M: [Blue, Black])

  @HiveField(28)
  final Map<String, String>? colorImages; // Map of color name to image path (e.g., {"Red": "/path/to/red.jpg", "Blue": "/path/to/blue.jpg"})

  @HiveField(29, defaultValue: 0.0)
  final double averageRating; // Average product rating (0.0 to 5.0)

  @HiveField(30, defaultValue: 0)
  final int reviewCount; // Total number of reviews

  Listing({
    required this.name,
    required this.sellerName,
    required this.price,
    this.originalPrice,
    required this.quantity,
    required this.type,
    required this.initialQuantity,
    required this.sellerId,
    this.fssaiLicense,
    this.preparedAt,
    this.expiryDate,
    required this.category,
    this.cookedFoodSource,
    this.imagePath,
    this.measurementUnit,
    this.packSizes,
    this.isBulkFood = false,
    this.servesCount,
    this.portionDescription,
    this.isKitchenOpen = false,
    this.preparationTimeMinutes,
    this.maxCapacity,
    this.currentOrders = 0,
    this.clothingCategory,
    this.description,
    this.availableSizes,
    this.availableColors,
    this.sizeColorCombinations,
    this.colorImages,
    this.averageRating = 0.0,
    this.reviewCount = 0,
  });

  // Helper method to check if listing has multiple pack sizes
  bool get hasMultiplePackSizes => packSizes != null && packSizes!.length > 1;

  // Helper method to get the default/primary pack size (for backward compatibility)
  PackSize? get defaultPackSize {
    if (packSizes != null && packSizes!.isNotEmpty) {
      return packSizes!.first;
    }
    return null;
  }

  // Helper method to check if this is a valid bulk food item
  bool get isValidBulkFood => isBulkFood && servesCount != null && servesCount! > 1;

  // Get bulk serving text for display
  String get bulkServingText {
    if (!isValidBulkFood) return '';
    final serves = servesCount ?? 0;
    return 'Serves $serves people';
  }

  // Get portion description or default
  String get bulkPortionText {
    if (!isValidBulkFood) return '';
    return portionDescription ?? 'Bulk pack';
  }

  // Get image path for a specific color (returns color-specific image or default image)
  String? getImagePathForColor(String? color) {
    if (color != null && colorImages != null && colorImages!.containsKey(color)) {
      return colorImages![color];
    }
    return imagePath; // Fallback to default image
  }

  // Live Kitchen helpers
  bool get isLiveKitchen => type == SellType.liveKitchen;

  bool get isLiveKitchenAvailable => 
      isLiveKitchen && isKitchenOpen && hasAvailableCapacity;

  bool get hasAvailableCapacity {
    if (!isLiveKitchen || maxCapacity == null) return true;
    return currentOrders < maxCapacity!;
  }

  int get remainingCapacity {
    if (!isLiveKitchen || maxCapacity == null) return 999;
    return maxCapacity! - currentOrders;
  }

  String get preparationTimeText {
    if (preparationTimeMinutes == null) return 'Time varies';
    if (preparationTimeMinutes! < 60) {
      return '${preparationTimeMinutes!} mins';
    }
    final hours = preparationTimeMinutes! ~/ 60;
    final mins = preparationTimeMinutes! % 60;
    if (mins == 0) return '$hours hr';
    return '$hours hr $mins mins';
  }

  String get kitchenStatusText {
    if (!isLiveKitchen) return '';
    if (!isKitchenOpen) return 'Kitchen Closed';
    if (!hasAvailableCapacity) return 'Fully Booked';
    return 'Kitchen Open';
  }

  // Method to add an order (for live kitchen capacity tracking)
  bool addLiveKitchenOrder() {
    if (!isLiveKitchenAvailable) return false;
    currentOrders++;
    return true;
  }

  // Method to complete an order (for live kitchen capacity tracking)
  void completeLiveKitchenOrder() {
    if (currentOrders > 0) {
      currentOrders--;
    }
  }

  /// Returns true if seller identity should be hidden for this listing
  /// (Groceries and Vegetables should hide seller identity in buyer view)
  bool get shouldHideSellerIdentity => type.shouldHideSellerIdentity;
}
