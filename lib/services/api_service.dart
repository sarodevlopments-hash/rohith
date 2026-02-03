// import 'package:flutter/material.dart';
// import '../models/listing.dart';

// class ApiService {
//   /// Simulated API call (can be replaced with Firebase / REST later)
//   static Future<String?> createListing(
//     BuildContext context,
//     Listing listing,
//   ) async {
//     try {
//       // TODO: replace this with real backend / Firestore logic
//       await Future.delayed(const Duration(seconds: 1));

//       debugPrint("Listing created:");
//       debugPrint(listing.toJson().toString());

//       return null; // success
//     } catch (e) {
//       return "Failed to create listing";
//     }
//   }
// }

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/listing.dart';
import 'listing_firestore_service.dart';

class ApiService {
  static Future<String?> createListing(
    BuildContext context,
    Listing listing,
  ) async {
    try {
      // ✅ Save to Hive (local storage)
      final box = Hive.box<Listing>('listingBox');
      await box.add(listing);

      debugPrint("✅ Listing saved to Hive");

      // ✅ Sync to Firestore (cloud storage) - non-blocking
      // This ensures data persists even if app is uninstalled
      ListingFirestoreService.upsertListing(listing).catchError((e) {
        debugPrint("⚠️ Firestore sync failed (but listing saved locally): $e");
        // Don't fail the operation if Firestore is unavailable
      });

      debugPrint("Listing: ${listing.toString()}");

      return null; // ✅ success
    } catch (e) {
      debugPrint("Error saving listing: $e");
      return "Failed to create listing";
    }
  }
}
