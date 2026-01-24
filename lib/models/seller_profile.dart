import 'package:hive/hive.dart';
import 'cooked_food_source.dart';
import 'sell_type.dart';

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

  SellerProfile({
    required this.sellerName,
    required this.fssaiLicense,
    this.cookedFoodSource,
    this.defaultFoodType,
    required this.sellerId,
    this.phoneNumber = '',
    this.pickupLocation = '',
  });
}

