import 'package:hive/hive.dart';
import 'cooked_food_source.dart';
import 'sell_type.dart';
import 'grocery_type.dart';

part 'seller_profile.g.dart';

@HiveType(typeId: 7)
class SellerProfile extends HiveObject {
  @HiveField(0)
  String sellerName;

  @HiveField(1)
  String fssaiLicense;

  @HiveField(2)
  CookedFoodSource? cookedFoodSource;

  @HiveField(3)
  SellType? defaultFoodType;

  @HiveField(4)
  String sellerId;

  @HiveField(5)
  String phoneNumber; // Seller contact number

  @HiveField(6)
  String pickupLocation; // Pickup/collection address

  @HiveField(7)
  String? groceryType; // 'freshProduce' or 'packagedGroceries'

  @HiveField(8)
  String? sellerType; // 'farmer' or 'reseller' (only for freshProduce)

  @HiveField(9)
  bool groceryOnboardingCompleted; // Whether grocery onboarding is completed

  @HiveField(10)
  Map<String, String>? groceryDocuments; // Map of document type -> Firebase Storage URL

  SellerProfile({
    required this.sellerName,
    required this.fssaiLicense,
    this.cookedFoodSource,
    this.defaultFoodType,
    required this.sellerId,
    this.phoneNumber = '',
    this.pickupLocation = '',
    this.groceryType,
    this.sellerType,
    this.groceryOnboardingCompleted = false,
    this.groceryDocuments,
  });

  // Helper getters
  GroceryType? get groceryTypeEnum {
    if (groceryType == null) return null;
    return GroceryType.values.firstWhere(
      (e) => e.name == groceryType,
      orElse: () => GroceryType.freshProduce,
    );
  }

  SellerType? get sellerTypeEnum {
    if (sellerType == null) return null;
    return SellerType.values.firstWhere(
      (e) => e.name == sellerType,
      orElse: () => SellerType.farmer,
    );
  }
}

