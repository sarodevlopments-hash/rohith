import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import '../models/order.dart';
import 'order_firestore_service.dart';

class OrderSyncService {
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sellerSub;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _buyerSub;
  static String? _activeUid;

  static Future<void> start() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_activeUid == uid && (_sellerSub != null || _buyerSub != null)) return;

    await stop();
    _activeUid = uid;

    final orders = FirebaseFirestore.instance.collection('orders');
    _sellerSub = orders.where('sellerId', isEqualTo: uid).snapshots().listen(_applySnapshot);
    _buyerSub = orders.where('userId', isEqualTo: uid).snapshots().listen(_applySnapshot);
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


