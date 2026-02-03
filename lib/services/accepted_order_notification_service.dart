import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order.dart';
import '../widgets/persistent_order_notification.dart';
import 'order_firestore_service.dart';

class AcceptedOrderNotificationService {
  static final Set<String> _dismissedNotifications = {};
  static final Set<String> _shownNotifications = {};
  static final Map<String, String> _lastShownStatus = {}; // Track last shown status per order
  static OverlayEntry? _currentOverlay;
  static GlobalKey<NavigatorState>? _navigatorKey;

  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  static void dismissNotification(String orderId) {
    // orderId should be the raw Order.orderId (without "accepted_" prefix)
    final notificationKey = 'accepted_$orderId';
    _dismissedNotifications.add(notificationKey);
    // Ensure it's treated as shown so it won't show again
    _shownNotifications.add(notificationKey);
    // Hide notification (with a small delay to allow animation to complete)
    Future.delayed(const Duration(milliseconds: 350), () {
      _hideNotification();
    });
    debugPrint('[AcceptedOrderNotification] Notification dismissed for order $orderId');
  }

  static void _hideNotification() {
    if (_currentOverlay != null) {
      try {
        _currentOverlay!.remove();
        debugPrint('[AcceptedOrderNotification] Overlay removed successfully');
      } catch (e) {
        debugPrint('[AcceptedOrderNotification] Error removing overlay: $e');
      }
      _currentOverlay = null;
    }
  }

  static void checkForAcceptedOrders(BuildContext? context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final contextToUse = context ?? _navigatorKey?.currentContext;
    if (contextToUse == null || !contextToUse.mounted) return;

    final ordersBox = Hive.box<Order>('ordersBox');
    if (!ordersBox.isOpen) return;

    final acceptedOrders = ordersBox.values.where((order) {
      // Check if order is for this buyer and was recently accepted
      final isForBuyer = order.userId == userId;
      
      // Check if this is a Live Kitchen order
      final isLiveKitchen = order.isLiveKitchenOrder ?? false;
      
      // For regular orders: check for AcceptedBySeller or Confirmed
      // For Live Kitchen orders: check for Preparing, ReadyForPickup, or ReadyForDelivery
      // (OrderReceived is too early - seller hasn't accepted yet)
      final isAccepted = isLiveKitchen
          ? (order.orderStatus == 'Preparing' || 
             order.orderStatus == 'ReadyForPickup' || 
             order.orderStatus == 'ReadyForDelivery')
          : (order.orderStatus == 'AcceptedBySeller' || 
             order.orderStatus == 'Confirmed');
      
      // Only show for recent orders (within last 7 days)
      final orderTime = order.paymentCompletedAt ?? order.purchasedAt;
      final isRecent = orderTime.isAfter(DateTime.now().subtract(const Duration(days: 7)));
      
      // Check if already dismissed
      final notificationKey = 'accepted_${order.orderId}';
      if (_dismissedNotifications.contains(notificationKey)) {
        debugPrint('[AcceptedOrderNotification] Order ${order.orderId} was dismissed, skipping');
        return false;
      }
      
      // For Live Kitchen orders, check if status has changed (allow re-showing for status changes)
      if (isLiveKitchen) {
        final lastStatus = _lastShownStatus[order.orderId];
        // Important statuses that should trigger notifications
        final importantStatuses = ['Preparing', 'ReadyForPickup', 'ReadyForDelivery'];
        
        // Only show for important statuses
        if (!importantStatuses.contains(order.orderStatus)) {
          return false;
        }
        
        // If we've shown a notification for this exact status before, skip
        if (lastStatus == order.orderStatus) {
          debugPrint('[AcceptedOrderNotification] Live Kitchen order ${order.orderId} already shown for status ${order.orderStatus}, skipping');
          return false;
        }
        
        // Show notification if:
        // 1. First time seeing this status, OR
        // 2. Status has changed to a more important status (e.g., Preparing -> ReadyForPickup)
        debugPrint('[AcceptedOrderNotification] Live Kitchen order ${order.orderId} status: ${order.orderStatus}, last shown: $lastStatus - will show notification');
      } else {
        // For regular orders, only show once
        if (_shownNotifications.contains(notificationKey)) {
          debugPrint('[AcceptedOrderNotification] Order ${order.orderId} was already shown, skipping');
          return false;
        }
      }
      
      return isForBuyer && isAccepted && isRecent;
    }).toList()
      ..sort((a, b) =>
          (b.sellerRespondedAt ?? b.purchasedAt)
              .compareTo(a.sellerRespondedAt ?? a.purchasedAt));

    if (acceptedOrders.isEmpty) return;

    // Show notification for the most recent accepted order
    final order = acceptedOrders.first;
    _showNotification(contextToUse, order);
  }

  static Future<void> _showNotification(BuildContext context, Order order) async {
    // Don't show if already showing
    if (_currentOverlay != null) {
      debugPrint('[AcceptedOrderNotification] Already showing a notification, skipping');
      return;
    }

    final notificationKey = 'accepted_${order.orderId}';
    if (_shownNotifications.contains(notificationKey)) {
      debugPrint('[AcceptedOrderNotification] Notification for ${order.orderId} already shown, skipping');
      return;
    }
    if (_dismissedNotifications.contains(notificationKey)) {
      debugPrint('[AcceptedOrderNotification] Notification for ${order.orderId} was dismissed, skipping');
      return;
    }

    // Get seller details from Firestore
    String? sellerPhone;
    String? pickupLocation;

    try {
      final doc = await OrderFirestoreService.doc(order.orderId).get();
      if (doc.exists) {
        final data = doc.data();
        sellerPhone = data?['sellerPhone'] as String?;
        pickupLocation = data?['sellerPickupLocation'] as String?;
      }
    } catch (e) {
      debugPrint('Failed to get seller details for order ${order.orderId}: $e');
    }

    // Only show if we have at least seller name
    if (order.sellerName.isEmpty || order.sellerName == '') return;

    final overlayState = Overlay.of(context);

    _currentOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          child: PersistentOrderNotification(
            order: order,
            sellerPhone: sellerPhone,
            pickupLocation: pickupLocation,
            onDismiss: () {
              // Pass the raw orderId so dismissNotification builds the correct key.
              dismissNotification(order.orderId);
            },
          ),
        ),
      ),
    );

    overlayState.insert(_currentOverlay!);
    _shownNotifications.add(notificationKey);
    // Track the status for which we showed the notification (for Live Kitchen status change tracking)
    _lastShownStatus[order.orderId] = order.orderStatus;
    debugPrint('[AcceptedOrderNotification] Notification shown for order ${order.orderId} with status ${order.orderStatus}');
  }

  static void clearShownNotifications() {
    _shownNotifications.clear();
  }

  static void reset() {
    _hideNotification();
    _dismissedNotifications.clear();
    _shownNotifications.clear();
    _lastShownStatus.clear();
  }
}

