import 'package:hive/hive.dart';
import '../models/seller_profile.dart';
import '../models/cooked_food_source.dart';
import '../models/sell_type.dart';

class SellerProfileService {
  static const String _boxName = 'sellerProfileBox';
  static const String _profileKey = 'seller_profile';

  static Future<Box> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  static Future<SellerProfile?> getProfile(String sellerId) async {
    final box = await _getBox();
    final profileData = box.get('${_profileKey}_$sellerId');
    return profileData as SellerProfile?;
  }

  static Future<void> saveProfile(SellerProfile profile) async {
    final box = await _getBox();
    await box.put('${_profileKey}_${profile.sellerId}', profile);
  }

  static Future<bool> hasProfile(String sellerId) async {
    final profile = await getProfile(sellerId);
    return profile != null;
  }

  static Future<void> updateProfile(String sellerId, {
    String? sellerName,
    String? fssaiLicense,
    CookedFoodSource? cookedFoodSource,
    SellType? defaultFoodType,
  }) async {
    final profile = await getProfile(sellerId);
    if (profile != null) {
      profile.sellerName = sellerName ?? profile.sellerName;
      profile.fssaiLicense = fssaiLicense ?? profile.fssaiLicense;
      profile.cookedFoodSource = cookedFoodSource ?? profile.cookedFoodSource;
      profile.defaultFoodType = defaultFoodType ?? profile.defaultFoodType;
      await profile.save();
    }
  }
}

