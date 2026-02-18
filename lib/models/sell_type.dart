import 'package:hive/hive.dart';
import 'seller_category.dart';

part 'sell_type.g.dart';

@HiveType(typeId: 4)
enum SellType {
  @HiveField(0)
  cookedFood,

  @HiveField(1)
  groceries,

  @HiveField(2)
  vegetables,

  @HiveField(3)
  clothingAndApparel,

  @HiveField(4)
  liveKitchen, // Live Kitchen - cook on demand, real-time ordering

  @HiveField(5)
  electronics,

  @HiveField(6)
  electricals,

  @HiveField(7)
  hardware,

  @HiveField(8)
  automobiles,

  @HiveField(9)
  others,
}

extension SellTypeExtension on SellType {
  String get displayName {
    switch (this) {
      case SellType.cookedFood:
        return 'Cooked Food';
      case SellType.groceries:
        return 'Groceries';
      case SellType.vegetables:
        return 'Vegetables';
      case SellType.clothingAndApparel:
        return 'Clothing and Apparel';
      case SellType.liveKitchen:
        return 'Live Kitchen';
      case SellType.electronics:
        return 'Electronics';
      case SellType.electricals:
        return 'Electricals';
      case SellType.hardware:
        return 'Hardware';
      case SellType.automobiles:
        return 'Automobiles';
      case SellType.others:
        return 'Others';
    }
  }

  String get description {
    switch (this) {
      case SellType.cookedFood:
        return 'Pre-cooked food items';
      case SellType.groceries:
        return 'Grocery items';
      case SellType.vegetables:
        return 'Fresh vegetables';
      case SellType.clothingAndApparel:
        return 'Clothing and apparel items';
      case SellType.liveKitchen:
        return 'Cook on demand - real-time orders';
      case SellType.electronics:
        return 'Electronic devices and gadgets';
      case SellType.electricals:
        return 'Electrical appliances and equipment';
      case SellType.hardware:
        return 'Hardware tools and materials';
      case SellType.automobiles:
        return 'Automobile parts and accessories';
      case SellType.others:
        return 'Other products and items';
    }
  }

  bool get isLiveKitchen => this == SellType.liveKitchen;

  /// Returns true if seller identity should be hidden for this sell type
  /// (Groceries and Vegetables should hide seller identity)
  bool get shouldHideSellerIdentity {
    return this == SellType.groceries || this == SellType.vegetables;
  }

  /// Returns true if this is a food category
  bool get isFoodCategory {
    return this == SellType.cookedFood ||
        this == SellType.liveKitchen ||
        this == SellType.groceries ||
        this == SellType.vegetables;
  }

  /// Returns true if this is a non-food category
  bool get isNonFoodCategory {
    return !isFoodCategory;
  }

  /// Convert SellType to SellerCategory for verification purposes
  SellerCategory? toSellerCategory() {
    switch (this) {
      case SellType.cookedFood:
        return SellerCategory.cookedFood;
      case SellType.liveKitchen:
        return SellerCategory.liveKitchen;
      case SellType.clothingAndApparel:
        return SellerCategory.clothesApparel;
      case SellType.electronics:
        return SellerCategory.electronics;
      case SellType.electricals:
        return SellerCategory.electricals;
      case SellType.hardware:
        return SellerCategory.hardware;
      case SellType.automobiles:
        return SellerCategory.automobiles;
      case SellType.others:
        return SellerCategory.others;
      case SellType.groceries:
      case SellType.vegetables:
        // Groceries and vegetables don't have direct SellerCategory mapping
        return null;
    }
  }
}
