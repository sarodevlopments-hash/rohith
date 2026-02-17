import 'dart:async';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/seller_profile.dart';
import '../models/cooked_food_source.dart';
import '../models/sell_type.dart';

class SellerProfileService {
  static const String _boxName = 'sellerProfileBox';
  static const String _profileKey = 'seller_profile';
  
  // Use the correct database ID: 'reqfood' (not the default)
  static FirebaseFirestore get _firestore => FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'reqfood',
  );

  static Future<Box> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  /// Convert SellerProfile to Firestore map
  static Map<String, dynamic> _toMap(SellerProfile profile) {
    return {
      'sellerId': profile.sellerId,
      'sellerName': profile.sellerName,
      'fssaiLicense': profile.fssaiLicense,
      'phoneNumber': profile.phoneNumber,
      'pickupLocation': profile.pickupLocation,
      'cookedFoodSource': profile.cookedFoodSource?.name,
      'defaultFoodType': profile.defaultFoodType?.name,
      'groceryType': profile.groceryType,
      'sellerType': profile.sellerType,
      'groceryOnboardingCompleted': profile.groceryOnboardingCompleted,
      'groceryDocuments': profile.groceryDocuments,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Convert Firestore map to SellerProfile
  static SellerProfile? _fromMap(Map<String, dynamic> data, String sellerId) {
    try {
      // Parse cookedFoodSource
      CookedFoodSource? cookedFoodSource;
      if (data['cookedFoodSource'] != null) {
        final sourceStr = data['cookedFoodSource'].toString();
        try {
          // Try to parse enum name (e.g., "home", "restaurant", "event")
          cookedFoodSource = CookedFoodSource.values.firstWhere(
            (e) => e.name == sourceStr || e.toString().split('.').last == sourceStr,
          );
        } catch (e) {
          cookedFoodSource = CookedFoodSource.home; // Default
        }
      }

      // Parse defaultFoodType
      SellType? defaultFoodType;
      if (data['defaultFoodType'] != null) {
        final typeStr = data['defaultFoodType'].toString();
        try {
          // Try to parse enum name (e.g., "cookedFood", "groceries", etc.)
          defaultFoodType = SellType.values.firstWhere(
            (e) => e.name == typeStr || e.toString().split('.').last == typeStr,
          );
        } catch (e) {
          defaultFoodType = SellType.cookedFood; // Default
        }
      }

      return SellerProfile(
        sellerId: sellerId,
        sellerName: data['sellerName'] as String? ?? '',
        fssaiLicense: data['fssaiLicense'] as String? ?? '',
        phoneNumber: data['phoneNumber'] as String? ?? '',
        pickupLocation: data['pickupLocation'] as String? ?? '',
        cookedFoodSource: cookedFoodSource,
        defaultFoodType: defaultFoodType,
        groceryType: data['groceryType'] as String?,
        sellerType: data['sellerType'] as String?,
        groceryOnboardingCompleted: data['groceryOnboardingCompleted'] as bool? ?? false,
        groceryDocuments: (data['groceryDocuments'] as Map<dynamic, dynamic>?)?.cast<String, String>(),
        averageRating: (data['averageRating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: (data['reviewCount'] as int?) ?? 0,
      );
    } catch (e) {
      print('❌ Error converting Firestore data to SellerProfile: $e');
      return null;
    }
  }

  /// Get seller profile (tries Firestore first, then falls back to Hive)
  static Future<SellerProfile?> getProfile(String sellerId) async {
    // Try Firestore first
    try {
      final docSnapshot = await _firestore
          .collection('userProfiles')
          .doc(sellerId)
          .collection('sellerProfile')
          .doc('profile')
          .get()
          .timeout(const Duration(seconds: 5));

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final profile = _fromMap(docSnapshot.data()!, sellerId);
        if (profile != null) {
          // Also save to Hive for offline access
          final box = await _getBox();
          await box.put('${_profileKey}_$sellerId', profile);
          print('✅ Seller profile loaded from Firestore');
          return profile;
        }
      }
    } catch (e) {
      print('⚠️ Error loading from Firestore, trying Hive: $e');
    }

    // Fallback to Hive
    print('🔍 Loading from Hive (local storage)...');
    final box = await _getBox();
    final profileData = box.get('${_profileKey}_$sellerId');
    if (profileData != null) {
      print('✅ Seller profile loaded from Hive');
      final profile = profileData as SellerProfile;
      print('📦 Hive profile data:');
      print('   - Name: "${profile.sellerName}"');
      print('   - Phone: "${profile.phoneNumber}"');
      print('   - Location: "${profile.pickupLocation}"');
      print('   - FSSAI: "${profile.fssaiLicense}"');
      print('   - Food Source: ${profile.cookedFoodSource}');
      print('   - Type: ${profile.defaultFoodType}');
    } else {
      print('❌ No profile found in Hive');
    }
    return profileData as SellerProfile?;
  }

  /// Save seller profile to both Firestore and Hive
  static Future<void> saveProfile(SellerProfile profile) async {
    // Verify authentication
    final auth = FirebaseAuth.instance.currentUser;
    if (auth == null) {
      throw Exception('Not authenticated. Please log in first.');
    }
    if (auth.uid != profile.sellerId) {
      throw Exception('Seller ID mismatch. Expected ${auth.uid}, got ${profile.sellerId}');
    }

    // Save to Hive (local) first for fast access
    final box = await _getBox();
    await box.put('${_profileKey}_${profile.sellerId}', profile);
    print('✅ Seller profile saved to Hive (local)');

    // Save to Firestore (cloud)
    try {
      final profileMap = _toMap(profile);
      await _firestore
          .collection('userProfiles')
          .doc(profile.sellerId)
          .collection('sellerProfile')
          .doc('profile')
          .set(profileMap, SetOptions(merge: true))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('⏱️ Firestore save timeout - profile saved locally only');
              throw TimeoutException('Firestore save timed out');
            },
          );
      print('✅ Seller profile saved to Firestore (cloud)');
    } on TimeoutException {
      print('⚠️ Firestore save timed out - profile saved locally only');
      // Don't throw - profile is saved locally, will sync later
    } on FirebaseException catch (e) {
      print('❌ Firestore error saving seller profile: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        throw Exception('Permission denied. Please verify Firestore rules include sellerProfile subcollection.');
      }
      // Don't throw - profile is saved locally
    } catch (e) {
      print('❌ Unexpected error saving to Firestore: $e');
      // Don't throw - profile is saved locally
    }
  }

  static Future<bool> hasProfile(String sellerId) async {
    print('🔍 Checking if profile exists for: $sellerId');
    
    // Check Hive first (faster, works offline)
    final box = await _getBox();
    final hiveProfile = box.get('${_profileKey}_$sellerId');
    if (hiveProfile != null) {
      print('✅ Profile found in Hive');
      return true;
    }
    
    // Check Firestore if Hive doesn't have it
    try {
      final docSnapshot = await _firestore
          .collection('userProfiles')
          .doc(sellerId)
          .collection('sellerProfile')
          .doc('profile')
          .get()
          .timeout(const Duration(seconds: 5));
      
      if (docSnapshot.exists && docSnapshot.data() != null) {
        print('✅ Profile found in Firestore');
        // Sync to Hive for offline access
        final profile = _fromMap(docSnapshot.data()!, sellerId);
        if (profile != null) {
          await box.put('${_profileKey}_$sellerId', profile);
        }
        return true;
      }
    } catch (e) {
      print('⚠️ Error checking Firestore: $e');
    }

    print('❌ Profile not found');
    return false;
  }

  static Future<void> updateProfile(String sellerId, {
    String? sellerName,
    String? fssaiLicense,
    CookedFoodSource? cookedFoodSource,
    SellType? defaultFoodType,
    String? groceryType,
    String? sellerType,
    bool? groceryOnboardingCompleted,
    Map<String, String>? groceryDocuments,
  }) async {
    final profile = await getProfile(sellerId);
    if (profile != null) {
      profile.sellerName = sellerName ?? profile.sellerName;
      profile.fssaiLicense = fssaiLicense ?? profile.fssaiLicense;
      profile.cookedFoodSource = cookedFoodSource ?? profile.cookedFoodSource;
      profile.defaultFoodType = defaultFoodType ?? profile.defaultFoodType;
      if (groceryType != null) profile.groceryType = groceryType;
      if (sellerType != null) profile.sellerType = sellerType;
      if (groceryOnboardingCompleted != null) {
        profile.groceryOnboardingCompleted = groceryOnboardingCompleted;
      }
      if (groceryDocuments != null) profile.groceryDocuments = groceryDocuments;
      await saveProfile(profile); // This will save to both Hive and Firestore
    }
  }
}

