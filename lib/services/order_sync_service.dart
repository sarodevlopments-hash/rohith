import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive/hive.dart';
import '../models/order.dart';
import 'order_firestore_service.dart';

class OrderSyncService {
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sellerSub;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _buyerSub;
  static String? _activeUid;

  static Future<void> start() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      print('⚠️ OrderSyncService: No authenticated user - skipping Firestore sync');
      return;
    }
    if (_activeUid == uid && (_sellerSub != null || _buyerSub != null)) return;

    await stop();
    _activeUid = uid;
    print('🔍 OrderSyncService: Starting sync for authenticated user: $uid');

    // ✅ First, load existing orders from Firestore (one-time sync on startup)
    await _loadExistingOrders(uid);

    // ✅ Then start real-time listeners for future changes
    // Use the correct database ID: 'reqfood' (not the default)
    final db = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'reqfood',
    );
    final orders = db.collection('orders');
    _sellerSub = orders.where('sellerId', isEqualTo: uid).snapshots().listen(_applySnapshot);
    _buyerSub = orders.where('userId', isEqualTo: uid).snapshots().listen(_applySnapshot);
  }

  /// Load existing orders from Firestore on startup
  static Future<void> _loadExistingOrders(String uid) async {
    try {
      print('🔄 Loading existing orders from Firestore for user: $uid');
      // Use the correct database ID: 'reqfood' (not the default)
      final db = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'reqfood',
      );
      final orders = db.collection('orders');
      
      // Get orders where user is buyer
      final buyerSnapshot = await orders
          .where('userId', isEqualTo: uid)
          .get()
          .timeout(const Duration(seconds: 10));
      
      // Get orders where user is seller
      final sellerSnapshot = await orders
          .where('sellerId', isEqualTo: uid)
          .get()
          .timeout(const Duration(seconds: 10));

      final box = Hive.box<Order>('ordersBox');
      int loadedCount = 0;

      // Process buyer orders
      for (var doc in buyerSnapshot.docs) {
        try {
          final data = doc.data();
          final orderId = (data['orderId'] as String?) ?? doc.id;
          final merged = <String, dynamic>{...data, 'orderId': orderId};
          final order = OrderFirestoreService.fromMap(merged);
          
          // Check if order already exists
          final existingKey = _findOrderKey(box, orderId);
          if (existingKey == null) {
            await box.add(order);
            loadedCount++;
          }
        } catch (e) {
          print('⚠️ Error processing buyer order ${doc.id}: $e');
        }
      }

      // Process seller orders
      for (var doc in sellerSnapshot.docs) {
        try {
          final data = doc.data();
          final orderId = (data['orderId'] as String?) ?? doc.id;
          final merged = <String, dynamic>{...data, 'orderId': orderId};
          final order = OrderFirestoreService.fromMap(merged);
          
          // Check if order already exists
          final existingKey = _findOrderKey(box, orderId);
          if (existingKey == null) {
            await box.add(order);
            loadedCount++;
          }
        } catch (e) {
          print('⚠️ Error processing seller order ${doc.id}: $e');
        }
      }

      print('✅ Loaded $loadedCount orders from Firestore');
    } on TimeoutException {
      print('⏱️ Firestore order load timeout - using local data only');
      _printCriticalInstructions();
    } catch (e) {
      print('❌ Error loading orders from Firestore: $e');
      if (e.toString().contains('unavailable') || e.toString().contains('offline') || e.toString().contains('permission')) {
        print('🔴 CRITICAL: Rules are blocking access - they must be PUBLISHED!');
      }
      _printCriticalInstructions();
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

  static Future<void> stop() async {
    await _sellerSub?.cancel();
    await _buyerSub?.cancel();
    _sellerSub = null;
    _buyerSub = null;
    _activeUid = null;
  }

  static void _applySnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    final box = Hive.box<Order>('ordersBox');
    for (final change in snap.docChanges) {
      final data = change.doc.data();
      if (data == null) continue;
      final orderId = (data['orderId'] as String?) ?? change.doc.id;
      final merged = <String, dynamic>{...data, 'orderId': orderId};
      final incoming = OrderFirestoreService.fromMap(merged);
      final existingKey = _findOrderKey(box, orderId);

      if (change.type == DocumentChangeType.removed) {
        if (existingKey != null) {
          box.delete(existingKey);
        }
        continue;
      }

      if (existingKey != null) {
        box.put(existingKey, incoming);
      } else {
        box.add(incoming);
      }
    }
  }

  static dynamic _findOrderKey(Box<Order> box, String orderId) {
    for (final key in box.keys) {
      final o = box.get(key);
      if (o != null && o.orderId == orderId) return key;
    }
    return null;
  }
}


