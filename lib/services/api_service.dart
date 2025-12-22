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

class ApiService {
  static Future<String?> createListing(
    BuildContext context,
    Listing listing,
  ) async {
    try {
      // ✅ Open Hive box
      final box = Hive.box<Listing>('listingBox');

      // ✅ Save listing
      await box.add(listing);

      debugPrint("Listing saved to Hive");
      debugPrint(listing.toString());

      return null; // ✅ success
    } catch (e) {
      debugPrint("Error saving listing: $e");
      return "Failed to create listing";
    }
  }
}
