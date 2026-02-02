import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/listing.dart';

class RecentlyViewedService {
  static const String _boxName = 'recentlyViewedBox';
  static const int _maxItems = 20; // Keep last 20 viewed items

  static Future<Box<String>> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox<String>(_boxName);
    }
    return Hive.box<String>(_boxName);
  }

  /// Add a listing to recently viewed
  static Future<void> addToList(Listing listing) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final box = await _getBox();
    final userId = currentUser.uid;
    final key = '${userId}_${listing.key.toString()}';
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    // Store as: userId_listingId -> timestamp
    await box.put(key, timestamp);

    // Clean up old items (keep only last _maxItems)
    final userKeys = box.keys
        .where((k) => k.toString().startsWith('${userId}_'))
        .toList();
    
    if (userKeys.length > _maxItems) {
      // Sort by timestamp and remove oldest
      final items = userKeys.map((k) {
        final ts = int.tryParse(box.get(k) ?? '0') ?? 0;
        return MapEntry(k, ts);
      }).toList();
      
      items.sort((a, b) => b.value.compareTo(a.value)); // Newest first
      
      // Remove oldest items
      for (var i = _maxItems; i < items.length; i++) {
        await box.delete(items[i].key);
      }
    }
  }

  /// Get recently viewed listing IDs for current user
  static Future<List<String>> getRecentlyViewedIds() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    final box = await _getBox();
    final userId = currentUser.uid;
    
    final userKeys = box.keys
        .where((k) => k.toString().startsWith('${userId}_'))
        .toList();
    
    // Sort by timestamp (newest first)
    final items = userKeys.map((k) {
      final keyStr = k.toString();
      final listingId = keyStr.substring(userId.length + 1); // Remove userId_
      final ts = int.tryParse(box.get(k) ?? '0') ?? 0;
      return MapEntry(listingId, ts);
    }).toList();
    
    items.sort((a, b) => b.value.compareTo(a.value)); // Newest first
    
    return items.map((e) => e.key).toList();
  }

  /// Clear recently viewed for current user
  static Future<void> clear() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final box = await _getBox();
    final userId = currentUser.uid;
    
    final userKeys = box.keys
        .where((k) => k.toString().startsWith('${userId}_'))
        .toList();
    
    for (var key in userKeys) {
      await box.delete(key);
    }
  }
}

