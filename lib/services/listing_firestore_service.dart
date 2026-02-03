import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive/hive.dart';
import '../models/listing.dart';
import '../models/sell_type.dart';
import '../models/food_category.dart';
import '../models/clothing_category.dart';
import '../models/cooked_food_source.dart';
import '../models/measurement_unit.dart';
import '../models/pack_size.dart';
import '../models/size_color_combination.dart';

/// Service to sync listings with Firestore for cloud persistence
class ListingFirestoreService {
  // Use the correct database ID: 'reqfood' (not the default)
  static FirebaseFirestore get _db => FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'reqfood',
  );
  static const String _collection = 'listings';

  /// Get document reference for a listing
  static DocumentReference<Map<String, dynamic>> doc(String listingId) {
    return _db.collection(_collection).doc(listingId);
  }

  /// Convert Listing to Firestore map
  static Map<String, dynamic> toMap(Listing listing) {
    return {
      'key': listing.key.toString(),
      'name': listing.name,
      'price': listing.price,
      'originalPrice': listing.originalPrice,
      'quantity': listing.quantity,
      'initialQuantity': listing.initialQuantity,
      'type': listing.type.name,
      'category': listing.category.name,
      'clothingCategory': listing.clothingCategory?.name,
      'description': listing.description,
      'imagePath': listing.imagePath,
      'sellerId': listing.sellerId,
      'sellerName': listing.sellerName,
      'cookedFoodSource': listing.cookedFoodSource?.name,
      'fssaiLicense': listing.fssaiLicense,
      'preparedAt': listing.preparedAt?.toUtc(),
      'expiryDate': listing.expiryDate?.toUtc(),
      'measurementUnit': listing.measurementUnit?.name,
      'packSizes': listing.packSizes?.map((p) => {
        'quantity': p.quantity,
        'price': p.price,
        'label': p.label,
      }).toList(),
      'isBulkFood': listing.isBulkFood,
      'servesCount': listing.servesCount,
      'portionDescription': listing.portionDescription,
      'isLiveKitchen': listing.isLiveKitchen,
      'isKitchenOpen': listing.isKitchenOpen,
      'preparationTimeMinutes': listing.preparationTimeMinutes,
      'maxCapacity': listing.maxCapacity,
      'currentOrders': listing.currentOrders,
      'availableSizes': listing.availableSizes,
      'availableColors': listing.availableColors,
      'sizeColorCombinations': listing.sizeColorCombinations?.map((c) => {
        'size': c.size,
        'availableColors': c.availableColors,
      }).toList(),
      'colorImages': listing.colorImages,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Save/update listing to Firestore
  static Future<void> upsertListing(Listing listing) async {
    try {
      final listingId = listing.key.toString();
      // Add timeout to prevent hanging (5 seconds max)
      await doc(listingId)
          .set(toMap(listing), SetOptions(merge: true))
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              print('⏱️ Firestore sync timeout for listing: $listingId');
              throw TimeoutException('Firestore sync timed out');
            },
          );
      print('✅ Listing synced to Firestore: $listingId');
    } on TimeoutException {
      print('⏱️ Firestore sync timed out - listing saved locally only');
      // Don't throw - allow app to continue with local storage
    } catch (e) {
      print('❌ Error syncing listing to Firestore: $e');
      // Don't throw - allow app to continue with local storage
    }
  }

  /// Delete listing from Firestore
  static Future<void> deleteListing(String listingId) async {
    try {
      await doc(listingId).delete();
      print('✅ Listing deleted from Firestore: $listingId');
    } catch (e) {
      print('❌ Error deleting listing from Firestore: $e');
    }
  }

  /// Convert Firestore map back to Listing object
  static Listing? _fromMap(Map<String, dynamic> data, int key) {
    try {
      // Parse enums
      final typeStr = data['type'] as String?;
      if (typeStr == null) return null;
      final type = SellType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => SellType.cookedFood,
      );

      final categoryStr = data['category'] as String?;
      if (categoryStr == null) return null;
      final category = FoodCategory.values.firstWhere(
        (e) => e.name == categoryStr,
        orElse: () => FoodCategory.veg,
      );

      CookedFoodSource? cookedFoodSource;
      if (data['cookedFoodSource'] != null) {
        cookedFoodSource = CookedFoodSource.values.firstWhere(
          (e) => e.name == data['cookedFoodSource'],
          orElse: () => CookedFoodSource.home,
        );
      }

      MeasurementUnit? measurementUnit;
      if (data['measurementUnit'] != null) {
        measurementUnit = MeasurementUnit.values.firstWhere(
          (e) => e.name == data['measurementUnit'],
          orElse: () => MeasurementUnit.kilograms,
        );
      }

      ClothingCategory? clothingCategory;
      if (data['clothingCategory'] != null) {
        clothingCategory = ClothingCategory.values.firstWhere(
          (e) => e.name == data['clothingCategory'],
          orElse: () => ClothingCategory.unisex,
        );
      }

      // Parse pack sizes
      List<PackSize>? packSizes;
      if (data['packSizes'] != null) {
        final packSizesList = data['packSizes'] as List?;
        packSizes = packSizesList?.map((p) {
          return PackSize(
            quantity: (p['quantity'] as num?)?.toDouble() ?? 0.0,
            price: (p['price'] as num?)?.toDouble() ?? 0.0,
            label: p['label'] as String?,
          );
        }).toList();
      }

      // Parse size-color combinations
      List<SizeColorCombination>? sizeColorCombinations;
      if (data['sizeColorCombinations'] != null) {
        final combosList = data['sizeColorCombinations'] as List?;
        sizeColorCombinations = combosList?.map((c) {
          return SizeColorCombination(
            size: c['size'] as String? ?? '',
            availableColors: (c['availableColors'] as List?)?.cast<String>() ?? [],
          );
        }).toList();
      }

      // Parse dates
      DateTime? preparedAt;
      if (data['preparedAt'] != null) {
        final ts = data['preparedAt'];
        if (ts is Timestamp) {
          preparedAt = ts.toDate();
        }
      }

      DateTime? expiryDate;
      if (data['expiryDate'] != null) {
        final ts = data['expiryDate'];
        if (ts is Timestamp) {
          expiryDate = ts.toDate();
        }
      }

      // Create Listing object
      final listing = Listing(
        name: data['name'] as String? ?? '',
        sellerName: data['sellerName'] as String? ?? '',
        price: (data['price'] as num?)?.toDouble() ?? 0.0,
        originalPrice: (data['originalPrice'] as num?)?.toDouble(),
        quantity: (data['quantity'] as int?) ?? 0,
        type: type,
        initialQuantity: (data['initialQuantity'] as int?) ?? (data['quantity'] as int?) ?? 0,
        sellerId: data['sellerId'] as String? ?? '',
        fssaiLicense: data['fssaiLicense'] as String?,
        preparedAt: preparedAt,
        expiryDate: expiryDate,
        category: category,
        cookedFoodSource: cookedFoodSource,
        imagePath: data['imagePath'] as String?,
        measurementUnit: measurementUnit,
        packSizes: packSizes,
        isBulkFood: data['isBulkFood'] as bool? ?? false,
        servesCount: data['servesCount'] as int?,
        portionDescription: data['portionDescription'] as String?,
        isKitchenOpen: data['isKitchenOpen'] as bool? ?? false,
        preparationTimeMinutes: data['preparationTimeMinutes'] as int?,
        maxCapacity: data['maxCapacity'] as int?,
        currentOrders: data['currentOrders'] as int? ?? 0,
        clothingCategory: clothingCategory,
        description: data['description'] as String?,
        availableSizes: (data['availableSizes'] as List?)?.cast<String>(),
        availableColors: (data['availableColors'] as List?)?.cast<String>(),
        sizeColorCombinations: sizeColorCombinations,
        colorImages: (data['colorImages'] as Map?)?.cast<String, String>(),
      );

      // Note: Hive key will be set when we call box.put(key, listing)
      return listing;
    } catch (e) {
      print('❌ Error converting Firestore data to Listing: $e');
      return null;
    }
  }

  /// Load all listings from Firestore and sync to Hive
  static Future<void> syncListingsFromFirestore() async {
    try {
      // Check authentication first
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        print('⚠️ No authenticated user - skipping Firestore sync for listings');
        return;
      }
      print('🔄 Starting Firestore sync for listings (authenticated as: ${currentUser.uid})...');
      
      // Add timeout to prevent hanging (15 seconds max - increased for rules propagation)
      final snapshot = await _db
          .collection(_collection)
          .get()
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              print('⏱️ Firestore sync timeout - using local data only');
              throw TimeoutException('Firestore sync timed out');
            },
          );
      
      final listingBox = Hive.box<Listing>('listingBox');
      
      int syncedCount = 0;
      int skippedCount = 0;
      int errorCount = 0;
      
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final listingId = data['key']?.toString() ?? doc.id;
          final key = int.tryParse(listingId);
          
          if (key == null) {
            print('⚠️ Invalid listing key: $listingId');
            skippedCount++;
            continue;
          }
          
          // Check if listing already exists in Hive
          final existingListing = listingBox.get(key);
          
          // Restore if it doesn't exist locally OR if Hive box is empty (full restore)
          // This ensures data is restored even if Hive was cleared
          if (existingListing == null || listingBox.isEmpty) {
            final listing = _fromMap(data, key);
            if (listing != null) {
              await listingBox.put(key, listing);
              syncedCount++;
              print('✅ Restored listing from Firestore: ${listing.name} (key: $key)');
            } else {
              errorCount++;
              print('⚠️ Failed to convert Firestore data to Listing: $listingId');
            }
          } else {
            // Listing exists locally, skip (local data takes precedence)
            skippedCount++;
          }
        } catch (e) {
          print('⚠️ Error processing Firestore document ${doc.id}: $e');
          errorCount++;
        }
      }
      
      print('✅ Firestore sync complete: $syncedCount restored, $skippedCount skipped (already exist), $errorCount errors');
      print('📊 Total listings in Hive: ${listingBox.length}');
    } on TimeoutException {
      print('⏱️ Firestore sync timed out - app will use local Hive data');
      _printCriticalInstructions();
      // Don't throw - allow app to continue with local data
    } catch (e) {
      print('❌ Error syncing listings from Firestore: $e');
      if (e.toString().contains('unavailable') || e.toString().contains('offline') || e.toString().contains('permission')) {
        print('🔴 CRITICAL: Rules are blocking access - they must be PUBLISHED!');
      }
      _printCriticalInstructions();
      // Don't throw - allow app to continue with local data
    }
  }

  static void _printCriticalInstructions() {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🔴 RULES NOT PUBLISHED - DO THIS NOW:');
    print('═══════════════════════════════════════════════════════');
    print('1. Go to: https://console.firebase.google.com/project/resqfood-66b5f/firestore/rules');
    print('2. Look for "Publish" button (top right, blue button)');
    print('3. Click "Publish" (NOT "Save"!)');
    print('4. Wait for "Rules published successfully"');
    print('5. Verify: Top of page shows "Last published: [time]"');
    print('6. Restart your app');
    print('═══════════════════════════════════════════════════════');
    print('');
  }

  /// Load listings from Firestore for a seller
  static Future<List<Listing>> loadSellerListings(String sellerId) async {
    try {
      final snapshot = await _db
          .collection(_collection)
          .where('sellerId', isEqualTo: sellerId)
          .get();
      
      final listings = <Listing>[];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final listingId = data['key']?.toString() ?? doc.id;
        final key = int.tryParse(listingId);
        
        if (key != null) {
          final listing = _fromMap(data, key);
          if (listing != null) {
            listings.add(listing);
          }
        }
      }
      
      return listings;
    } catch (e) {
      print('❌ Error loading listings from Firestore: $e');
      return [];
    }
  }
}

