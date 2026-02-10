import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order.dart';
import '../widgets/persistent_order_notification.dart';
import 'order_firestore_service.dart';

class AcceptedOrderNotificationService {
  static final Set<String> _dismissedNotifications = {};
  static final Set<String> _shownNotifications = {};
  static final Set<String> _inFlightNotifications = {}; // Prevent async race duplicates
  static final Map<String, String> _lastShownStatus = {}; // Track last shown status per order
  static OverlayEntry? _currentOverlay;
  static GlobalKey<NavigatorState>? _navigatorKey;

  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  static void dismissNotification(String orderId) {
    // Be tolerant: callers may accidentally pass "accepted_<id>" instead of "<id>"
    final normalizedOrderId =
        orderId.startsWith('accepted_') ? orderId.substring('accepted_'.length) : orderId;
    final notificationKey = 'accepted_$normalizedOrderId';

    // Idempotent: if already dismissed, do nothing (prevents double/triple logs/calls).
    if (_dismissedNotifications.contains(notificationKey)) {
      return;
    }

    _dismissedNotifications.add(notificationKey);
    // Ensure it's treated as shown so it won't show again (also persist across restarts)
    _shownNotifications.add(notificationKey);
    if (Hive.isBoxOpen('acceptedOrderNotificationsBox')) {
      Hive.box('acceptedOrderNotificationsBox').put(notificationKey, true);
    }
    // Hide notification (with a small delay to allow animation to complete)
    Future.delayed(const Duration(milliseconds: 350), () {
      _hideNotification();
    });
    debugPrint(
      '[AcceptedOrderNotification] Notification dismissed for order $normalizedOrderId (key: $notificationKey)',
    );
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
    final shownBox = Hive.isBoxOpen('acceptedOrderNotificationsBox')
        ? Hive.box('acceptedOrderNotificationsBox')
        : null;

    final acceptedOrders = ordersBox.values.where((order) {
      // Check if order is for this buyer
      final isForBuyer = order.userId == userId;
      if (!isForBuyer) return false;
      
      // STRICT: Never show for pending/payment statuses - only show when seller has actually accepted
      // Exclude these statuses explicitly: PaymentPending, PaymentCompleted, AwaitingSellerConfirmation
      final pendingStatuses = ['PaymentPending', 'PaymentCompleted', 'AwaitingSellerConfirmation'];
      if (pendingStatuses.contains(order.orderStatus)) {
        // Order still pending, skip silently
        return false;
      }
      
      // CRITICAL: For regular orders, verify seller actually responded (has sellerRespondedAt timestamp)
      // This ensures we only show for orders that were genuinely accepted by the seller
      final isLiveKitchen = order.isLiveKitchenOrder ?? false;
      if (!isLiveKitchen) {
        // Regular orders MUST have sellerRespondedAt timestamp to be considered accepted
        if (order.sellerRespondedAt == null) {
          // Order has no sellerRespondedAt timestamp, skip silently
          return false;
        }
        // Verify seller responded AFTER the order was purchased (not before)
        final orderTime = order.paymentCompletedAt ?? order.purchasedAt;
        if (order.sellerRespondedAt!.isBefore(orderTime) || 
            order.sellerRespondedAt!.difference(orderTime).inSeconds < 1) {
          // Order sellerRespondedAt is invalid, skip silently
          return false;
        }
        // CRITICAL: If order was just created (within last 30 seconds) and seller hasn't responded, skip
        // This prevents showing notifications for orders that were just placed
        if (orderTime.isAfter(DateTime.now().subtract(const Duration(seconds: 30))) &&
            order.sellerRespondedAt!.difference(orderTime).inSeconds < 5) {
          // Order was just created, skip silently
          return false;
        }
        // Only show if seller responded recently (within last hour) - prevents showing old notifications
        if (order.sellerRespondedAt!.isBefore(DateTime.now().subtract(const Duration(hours: 1)))) {
          // Order too old, skip silently
          return false;
        }
      }
      
      // For regular orders: ONLY check for AcceptedBySeller or Confirmed
      // For Live Kitchen orders: check for Preparing, ReadyForPickup, or ReadyForDelivery
      // (OrderReceived is too early - seller hasn't accepted yet)
      final isAccepted = isLiveKitchen
          ? (order.orderStatus == 'Preparing' || 
             order.orderStatus == 'ReadyForPickup' || 
             order.orderStatus == 'ReadyForDelivery')
          : (order.orderStatus == 'AcceptedBySeller' || 
             order.orderStatus == 'Confirmed');
      
      // CRITICAL: Double-check status matches - if status doesn't match accepted status, skip
      if (!isAccepted) {
        // Order status does not match accepted status, skip silently
        return false;
      }
      
      // Only show for recent orders (within last 7 days)
      final orderTime = order.paymentCompletedAt ?? order.purchasedAt;
      final isRecent = orderTime.isAfter(DateTime.now().subtract(const Duration(days: 7)));
      if (!isRecent) {
        // Order is too old, skip silently
        return false;
      }
      
      // Check if already dismissed or persisted as shown - STRICT check
      final notificationKey = 'accepted_${order.orderId}';
      if (_dismissedNotifications.contains(notificationKey) ||
          _shownNotifications.contains(notificationKey) ||
          (shownBox?.get(notificationKey) == true)) {
        debugPrint('[AcceptedOrderNotification] Order ${order.orderId} was dismissed/already shown (persisted), skipping');
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
        // For regular orders, only show once (even across app restarts)
        if (_shownNotifications.contains(notificationKey) ||
            (shownBox?.get(notificationKey) == true)) {
          debugPrint('[AcceptedOrderNotification] Order ${order.orderId} was already shown (persisted), skipping');
          return false;
        }
      }
      
      // All checks passed - this order is genuinely accepted
      return true;
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

    // Guard against async races: multiple triggers can call _showNotification while we're
    // awaiting Firestore. This prevents inserting multiple overlays for the same order.
    if (_inFlightNotifications.contains(notificationKey)) {
      debugPrint('[AcceptedOrderNotification] Notification for ${order.orderId} already in-flight, skipping');
      return;
    }
    _inFlightNotifications.add(notificationKey);

    if (_shownNotifications.contains(notificationKey)) {
      debugPrint('[AcceptedOrderNotification] Notification for ${order.orderId} already shown, skipping');
      _inFlightNotifications.remove(notificationKey);
      return;
    }
    if (_dismissedNotifications.contains(notificationKey)) {
      debugPrint('[AcceptedOrderNotification] Notification for ${order.orderId} was dismissed, skipping');
      _inFlightNotifications.remove(notificationKey);
      return;
    }

    // Check if this is a Live Kitchen order (needed for Firestore validation)
    final isLiveKitchen = order.isLiveKitchenOrder ?? false;

    // Get seller details from Firestore and verify status
    String? sellerPhone;
    String? pickupLocation;
    String? firestoreStatus;

    try {
      final doc = await OrderFirestoreService.doc(order.orderId).get();
      if (doc.exists) {
        final data = doc.data();
        firestoreStatus = data?['orderStatus'] as String?;
        sellerPhone = data?['sellerPhone'] as String?;
        pickupLocation = data?['sellerPickupLocation'] as String?;
        
        // CRITICAL: Verify Firestore status FIRST - if it's pending or doesn't match, abort immediately
        if (firestoreStatus != null) {
          final pendingStatuses = ['PaymentPending', 'PaymentCompleted', 'AwaitingSellerConfirmation'];
          if (pendingStatuses.contains(firestoreStatus)) {
            debugPrint('[AcceptedOrderNotification] Order ${order.orderId} Firestore status is pending (${firestoreStatus}), aborting notification');
            // Also mark as dismissed to prevent re-checking
            _dismissedNotifications.add(notificationKey);
            if (Hive.isBoxOpen('acceptedOrderNotificationsBox')) {
              Hive.box('acceptedOrderNotificationsBox').put(notificationKey, true);
            }
            _inFlightNotifications.remove(notificationKey);
            return;
          }
          // For regular orders, verify Firestore status is actually accepted
          if (!isLiveKitchen && firestoreStatus != 'AcceptedBySeller' && firestoreStatus != 'Confirmed') {
            debugPrint('[AcceptedOrderNotification] Order ${order.orderId} Firestore status is not accepted (${firestoreStatus}), aborting notification');
            // Mark as dismissed to prevent re-checking
            _dismissedNotifications.add(notificationKey);
            if (Hive.isBoxOpen('acceptedOrderNotificationsBox')) {
              Hive.box('acceptedOrderNotificationsBox').put(notificationKey, true);
            }
            _inFlightNotifications.remove(notificationKey);
            return;
          }
          // CRITICAL: Verify Firestore status matches local status
          if (firestoreStatus != order.orderStatus) {
            debugPrint('[AcceptedOrderNotification] Order ${order.orderId} Firestore status (${firestoreStatus}) doesn\'t match local status (${order.orderStatus}), aborting');
            _inFlightNotifications.remove(notificationKey);
            return;
          }
        } else {
          // Firestore document exists but no status - this is suspicious, abort
          debugPrint('[AcceptedOrderNotification] Order ${order.orderId} Firestore document exists but has no status, aborting');
          _inFlightNotifications.remove(notificationKey);
          return;
        }
      } else {
        // Firestore document doesn't exist - order might not be synced yet, abort to be safe
        debugPrint('[AcceptedOrderNotification] Order ${order.orderId} Firestore document does not exist, aborting (order may not be synced yet)');
        _inFlightNotifications.remove(notificationKey);
        return;
      }
    } catch (e) {
      debugPrint('Failed to get seller details for order ${order.orderId}: $e');
      // If Firestore check fails, abort to be safe (don't show notification if we can't verify)
      debugPrint('[AcceptedOrderNotification] Firestore check failed, aborting notification to prevent false positives');
      _inFlightNotifications.remove(notificationKey);
      return;
    }

    // Only show if we have at least seller name
    if (order.sellerName.isEmpty || order.sellerName == '') {
      _inFlightNotifications.remove(notificationKey);
      return;
    }

    // FINAL CHECK: Verify order is still accepted before showing (prevent race conditions)
    final pendingStatuses = ['PaymentPending', 'PaymentCompleted', 'AwaitingSellerConfirmation'];
    if (pendingStatuses.contains(order.orderStatus)) {
      debugPrint('[AcceptedOrderNotification] Order ${order.orderId} status changed to pending (${order.orderStatus}), aborting notification');
      _inFlightNotifications.remove(notificationKey);
      return;
    }
    
    // CRITICAL: For regular orders, verify seller actually responded before showing
    if (!isLiveKitchen) {
      if (order.sellerRespondedAt == null) {
        debugPrint('[AcceptedOrderNotification] Order ${order.orderId} has no sellerRespondedAt, aborting notification');
        _inFlightNotifications.remove(notificationKey);
        return;
      }
      // Verify seller responded recently (within last hour)
      if (order.sellerRespondedAt!.isBefore(DateTime.now().subtract(const Duration(hours: 1)))) {
        debugPrint('[AcceptedOrderNotification] Order ${order.orderId} seller responded too long ago, aborting notification');
        _inFlightNotifications.remove(notificationKey);
        return;
      }
    }
    
    final isStillAccepted = isLiveKitchen
        ? (order.orderStatus == 'Preparing' || 
           order.orderStatus == 'ReadyForPickup' || 
           order.orderStatus == 'ReadyForDelivery')
        : (order.orderStatus == 'AcceptedBySeller' || 
           order.orderStatus == 'Confirmed');
    
    if (!isStillAccepted) {
      debugPrint('[AcceptedOrderNotification] Order ${order.orderId} is not accepted (status: ${order.orderStatus}), aborting notification');
      _inFlightNotifications.remove(notificationKey);
      return;
    }

    // Mark as shown IMMEDIATELY before showing to prevent duplicates
    _shownNotifications.add(notificationKey);
    if (Hive.isBoxOpen('acceptedOrderNotificationsBox')) {
      Hive.box('acceptedOrderNotificationsBox').put(notificationKey, true);
    }
    // Track the status for which we showed the notification (for Live Kitchen status change tracking)
    _lastShownStatus[order.orderId] = order.orderStatus;

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
    debugPrint('[AcceptedOrderNotification] Notification shown for order ${order.orderId} with status ${order.orderStatus}');
    // Notification persists until user takes action (dismisses manually or taps View Order/Map/Call)

    _inFlightNotifications.remove(notificationKey);
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

