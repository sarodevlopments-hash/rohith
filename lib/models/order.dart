import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'listing.dart';

part 'order.g.dart';

@HiveType(typeId: 0)
class Order extends HiveObject {
  @HiveField(0)
  final String foodName;

  @HiveField(1)
  final String sellerName;

  @HiveField(2)
  final double pricePaid;

  @HiveField(3)
  final double savedAmount;

  @HiveField(4)
  final DateTime purchasedAt;

  @HiveField(5)
  final String listingId; // Reference to the listing

  @HiveField(6)
  final int quantity; // Quantity purchased

  @HiveField(7)
  final double originalPrice; // Original price per unit

  @HiveField(8)
  final double discountedPrice; // Discounted price per unit

  @HiveField(9)
  final String userId; // Buyer's user ID

  @HiveField(10)
  String orderStatus; // PaymentPending, PaymentCompleted, AwaitingSellerConfirmation, AcceptedBySeller, RejectedBySeller, Completed, Cancelled

  @HiveField(11)
  final String orderId; // Unique order ID

  @HiveField(12)
  DateTime? paymentCompletedAt; // When payment was completed

  @HiveField(13)
  DateTime? sellerRespondedAt; // When seller accepted/rejected

  @HiveField(14)
  final String? paymentMethod; // Payment method used (mock for now)

  @HiveField(15)
  final String sellerId; // Seller's user ID for notifications

  @HiveField(16)
  final double? selectedPackQuantity; // Selected pack size quantity (for groceries with multiple packs)

  @HiveField(17)
  final double? selectedPackPrice; // Selected pack size price (for groceries with multiple packs)

  @HiveField(18)
  final String? selectedPackLabel; // Selected pack size label (for groceries with multiple packs)

  // Live Kitchen fields
  @HiveField(19)
  final bool? isLiveKitchenOrder; // Whether this is a Live Kitchen order (null for old orders)

  @HiveField(20)
  final int? preparationTimeMinutes; // Preparation time for Live Kitchen orders

  @HiveField(21)
  DateTime? statusChangedAt; // When order status was last changed

  Order({
    required this.foodName,
    required this.sellerName,
    required this.pricePaid,
    required this.savedAmount,
    required this.purchasedAt,
    required this.listingId,
    required this.quantity,
    required this.originalPrice,
    required this.discountedPrice,
    required this.userId,
    required this.sellerId,
    this.orderStatus = 'PaymentPending',
    String? orderId,
    this.paymentCompletedAt,
    this.sellerRespondedAt,
    this.paymentMethod,
    this.selectedPackQuantity,
    this.selectedPackPrice,
    this.selectedPackLabel,
    this.isLiveKitchenOrder,
    this.preparationTimeMinutes,
    this.statusChangedAt,
  }) : orderId = orderId ?? DateTime.now().millisecondsSinceEpoch.toString();

  // Helper methods for Live Kitchen order status
  bool get isLiveKitchenStatus => (isLiveKitchenOrder ?? false) && [
    'OrderReceived',
    'Preparing',
    'ReadyForPickup',
    'ReadyForDelivery',
  ].contains(orderStatus);

  String get statusDisplayText {
    if (isLiveKitchenOrder ?? false) {
      switch (orderStatus) {
        case 'OrderReceived':
          return 'Order Received';
        case 'Preparing':
          return 'Preparing';
        case 'ReadyForPickup':
          return 'Ready for Pickup';
        case 'ReadyForDelivery':
          return 'Ready for Delivery';
        case 'Completed':
          return 'Completed';
        case 'Cancelled':
          return 'Cancelled';
        default:
          return orderStatus;
      }
    }
    return orderStatus;
  }

  Color get statusColor {
    if (isLiveKitchenOrder ?? false) {
      switch (orderStatus) {
        case 'OrderReceived':
          return Colors.blue;
        case 'Preparing':
          return Colors.orange;
        case 'ReadyForPickup':
        case 'ReadyForDelivery':
          return Colors.green;
        case 'Completed':
          return Colors.grey;
        case 'Cancelled':
          return Colors.red;
        default:
          return Colors.grey;
      }
    }
    // Regular order colors
    switch (orderStatus) {
      case 'PaymentPending':
        return Colors.orange;
      case 'PaymentCompleted':
        return Colors.blue;
      case 'AwaitingSellerConfirmation':
        return Colors.amber;
      case 'AcceptedBySeller':
        return Colors.green;
      case 'RejectedBySeller':
        return Colors.red;
      case 'Completed':
        return Colors.grey;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  bool get canSellerUpdateStatus {
    if (!(isLiveKitchenOrder ?? false)) return false;
    return ['OrderReceived', 'Preparing'].contains(orderStatus);
  }

  bool get canMarkReady {
    if (!(isLiveKitchenOrder ?? false)) return false;
    return orderStatus == 'Preparing';
  }

  /// Returns true if seller identity should be hidden for this order
  /// (Groceries and Vegetables should hide seller identity in buyer view)
  /// This checks the listing type by looking up the listing from Hive
  bool shouldHideSellerIdentity() {
    try {
      final listingBox = Hive.box<Listing>('listingBox');
      final listingKey = int.tryParse(listingId);
      if (listingKey != null) {
        final listing = listingBox.get(listingKey);
        if (listing != null) {
          return listing.shouldHideSellerIdentity;
        }
      }
    } catch (e) {
      // If listing lookup fails, default to showing seller (safer fallback)
    }
    return false;
  }
}
