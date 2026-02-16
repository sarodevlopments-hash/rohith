import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/seller_category.dart';

/// Service to store and retrieve seller verification status locally using Hive
class SellerVerificationStorage {
  static const String _boxName = 'sellerVerificationBox';
  static Box? _box;
  
  /// Get or open the Hive box for verification storage
  static Future<Box> _getBox() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox(_boxName);
    }
    return _box!;
  }
  
  /// Get the box instance (for accessing data)
  static Future<Box> getBox() async {
    return await _getBox();
  }
  
  /// Get bank details for a category
  static Future<Map<String, String>?> getBankDetails(SellerCategory category) async {
    try {
      final box = await _getBox();
      final key = '${category.name}_bankDetails';
      final data = box.get(key);
      if (data != null && data is Map) {
        return Map<String, String>.from(data);
      }
    } catch (e) {
      debugPrint('❌ Error getting bank details for ${category.name}: $e');
    }
    return null;
  }
  
  /// Save bank details for a category
  static Future<void> saveBankDetails(SellerCategory category, Map<String, String> bankDetails) async {
    try {
      final box = await _getBox();
      final key = '${category.name}_bankDetails';
      await box.put(key, bankDetails);
      await box.flush();
      debugPrint('💾 Saved bank details for ${category.name}');
    } catch (e) {
      debugPrint('❌ Error saving bank details for ${category.name}: $e');
    }
  }
  
  /// Get uploaded documents count for a category
  static Future<int> getUploadedDocumentsCount(SellerCategory category) async {
    try {
      final box = await _getBox();
      final key = '${category.name}_documents';
      final data = box.get(key);
      if (data != null && data is Map) {
        return data.length;
      }
    } catch (e) {
      debugPrint('❌ Error getting documents count for ${category.name}: $e');
    }
    return 0;
  }
  
  /// Save uploaded documents for a category
  static Future<void> saveDocuments(SellerCategory category, Map<String, String> documents) async {
    try {
      final box = await _getBox();
      final key = '${category.name}_documents';
      await box.put(key, documents);
      await box.flush();
      debugPrint('💾 Saved ${documents.length} documents for ${category.name}');
    } catch (e) {
      debugPrint('❌ Error saving documents for ${category.name}: $e');
    }
  }
  
  /// Check if verification is completed for a category
  static Future<bool> isVerificationCompleted(SellerCategory category) async {
    try {
      final box = await _getBox();
      final key = '${category.name}_completed';
      final value = box.get(key, defaultValue: false) as bool;
      debugPrint('🔍 Checking verification for ${category.name}: $value');
      return value;
    } catch (e) {
      debugPrint('❌ Error checking verification for ${category.name}: $e');
      return false;
    }
  }
  
  /// Mark verification as completed for a category
  static Future<void> markVerificationCompleted(SellerCategory category) async {
    try {
      final box = await _getBox();
      final key = '${category.name}_completed';
      await box.put(key, true);
      await box.flush(); // Ensure data is written to disk
      
      // Verify the save worked
      final saved = box.get(key, defaultValue: false) as bool;
      debugPrint('💾 Saved verification for ${category.name}: $saved');
      
      if (!saved) {
        debugPrint('❌ Warning: Verification save verification failed for ${category.name}');
      }
    } catch (e) {
      debugPrint('❌ Error saving verification for ${category.name}: $e');
      rethrow;
    }
  }
  
  /// Clear verification status for a category (for testing or reset)
  static Future<void> clearVerificationStatus(SellerCategory category) async {
    try {
      final box = await _getBox();
      final key = '${category.name}_completed';
      await box.delete(key);
      await box.flush();
      debugPrint('🗑️ Cleared verification status for ${category.name}');
    } catch (e) {
      debugPrint('❌ Error clearing verification for ${category.name}: $e');
    }
  }
}

