import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/order.dart';

class OrderFirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> doc(String orderId) {
    return _db.collection('orders').doc(orderId);
  }

  static Map<String, dynamic> toMap(Order o) {
    return {
      'orderId': o.orderId,
      'foodName': o.foodName,
      'sellerName': o.sellerName,
      'pricePaid': o.pricePaid,
      'savedAmount': o.savedAmount,
      'purchasedAt': o.purchasedAt.toUtc(),
      'listingId': o.listingId,
      'quantity': o.quantity,
      'originalPrice': o.originalPrice,
      'discountedPrice': o.discountedPrice,
      'userId': o.userId,
      'sellerId': o.sellerId,
      'orderStatus': o.orderStatus,
      'paymentCompletedAt': o.paymentCompletedAt?.toUtc(),
      'sellerRespondedAt': o.sellerRespondedAt?.toUtc(),
      'paymentMethod': o.paymentMethod,
      'selectedPackQuantity': o.selectedPackQuantity,
      'selectedPackPrice': o.selectedPackPrice,
      'selectedPackLabel': o.selectedPackLabel,
      'selectedSize': o.selectedSize,
      'selectedColor': o.selectedColor,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Future<void> upsertOrder(Order o) async {
    await doc(o.orderId).set(toMap(o), SetOptions(merge: true));
  }

  static Future<void> updateStatus({
    required String orderId,
    required String status,
    DateTime? sellerRespondedAt,
  }) async {
    await doc(orderId).set(
      {
        'orderStatus': status,
        'sellerRespondedAt': sellerRespondedAt?.toUtc(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> updateMeta(String orderId, Map<String, dynamic> data) async {
    await doc(orderId).set(
      {
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Order fromMap(Map<String, dynamic> m) {
    DateTime _dt(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    return Order(
      foodName: (m['foodName'] as String?) ?? '',
      sellerName: (m['sellerName'] as String?) ?? '',
      pricePaid: (m['pricePaid'] as num?)?.toDouble() ?? 0,
      savedAmount: (m['savedAmount'] as num?)?.toDouble() ?? 0,
      purchasedAt: _dt(m['purchasedAt']),
      listingId: (m['listingId'] as String?) ?? '',
      quantity: (m['quantity'] as num?)?.toInt() ?? 0,
      originalPrice: (m['originalPrice'] as num?)?.toDouble() ?? 0,
      discountedPrice: (m['discountedPrice'] as num?)?.toDouble() ?? 0,
      userId: (m['userId'] as String?) ?? '',
      sellerId: (m['sellerId'] as String?) ?? '',
      orderStatus: (m['orderStatus'] as String?) ?? 'PaymentPending',
      orderId: (m['orderId'] as String?) ?? '',
      paymentCompletedAt: m['paymentCompletedAt'] == null ? null : _dt(m['paymentCompletedAt']),
      sellerRespondedAt: m['sellerRespondedAt'] == null ? null : _dt(m['sellerRespondedAt']),
      paymentMethod: m['paymentMethod'] as String?,
      selectedPackQuantity: (m['selectedPackQuantity'] as num?)?.toDouble(),
      selectedPackPrice: (m['selectedPackPrice'] as num?)?.toDouble(),
      selectedPackLabel: m['selectedPackLabel'] as String?,
      selectedSize: m['selectedSize'] as String?,
      selectedColor: m['selectedColor'] as String?,
    );
  }
}


