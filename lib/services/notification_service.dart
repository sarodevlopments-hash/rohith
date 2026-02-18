import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order.dart';
import '../models/listing.dart';
import '../models/seller_inline_notification.dart';
import '../screens/seller_dashboard_screen.dart';
import '../screens/order_details_screen.dart';
import '../services/order_firestore_service.dart';
import '../services/web_order_broadcast.dart';

class NotificationService {
  static final Box<Order> _notificationBox = Hive.box<Order>('ordersBox');
  static final Box<Listing> _listingBox = Hive.box<Listing>('listingBox');
  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static GlobalKey<NavigatorState>? _navigatorKey;
  // Bottom inset stack for in-app SnackBar positioning.
  // MainTabScreen pushes a value to keep the banner above the bottom nav.
  // Pushed full-screen pages (like ProductDetails) push 0 so CTAs aren't covered.
  static final List<double> _bottomInsetStack = <double>[0];

  static void pushBottomInset(double inset) {
    _bottomInsetStack.add(inset);
  }

  static void popBottomInset() {
    if (_bottomInsetStack.length > 1) {
      _bottomInsetStack.removeLast();
    }
  }

  static double get _currentBottomInset => _bottomInsetStack.isNotEmpty
      ? _bottomInsetStack.last
      : 0;
  // Legacy fields (top banner overlay) are no longer used.
  // (Legacy) overlay entry was used when seller notifications were shown as a top banner.
  // Guard against async race duplicates for seller new-order notifications
  static final Set<String> _sellerInFlightNotifications = <String>{};

  static final ValueNotifier<SellerInlineNotification?> sellerInlineNotifier =
      ValueNotifier<SellerInlineNotification?>(null);

  // Track current seller notification to re-show after other notifications dismiss
  static Order? _currentSellerNotificationOrder;
  static int _currentSellerNotificationPendingCount = 1;

  /// Simple data model for Cart's inline seller notification (current value).
  static SellerInlineNotification? get currentSellerInlineNotification =>
      sellerInlineNotifier.value;

  // When true, Cart screen is active and wants inline banner instead of SnackBar.
  static bool _cartInlineEnabled = false;

  static bool _initialized = false;
  static const String _channelId = 'new_orders_channel';
  static const String _channelName = 'New Orders';

  /// Enable/disable Cart-specific inline seller banner (above "You saved" card).
  /// When enabled, new seller notifications will be sent to [sellerInlineNotifier]
  /// and the global SnackBar will be suppressed while Cart is visible.
  static void setCartInlineBannerEnabled(bool enabled) {
    _cartInlineEnabled = enabled;
    if (!enabled) {
      sellerInlineNotifier.value = null;
    }
  }

  // Show in-app seller notification, either as top banner or bottom SnackBar
  static bool showOrderNotification(
    BuildContext? context,
    Order order, {
    int pendingCount = 1,
  }) {
    // If Cart is active, publish inline banner and SKIP SnackBar (to avoid duplicate confirmations).
    if (_cartInlineEnabled) {
      final data = SellerInlineNotification(order: order, pendingCount: pendingCount);
      sellerInlineNotifier.value = data;
      debugPrint(
        '[NotificationService] Published Cart inline seller banner for order: ${order.orderId} (pending: $pendingCount)',
      );
      return true;
    }

    // Default behavior when Cart is not active: bottom SnackBar as primary notification.
    return _showSellerSnackBar(order, pendingCount: pendingCount);
  }

  // Re-show seller notification if it was interrupted by another notification
  static void _reShowSellerNotificationIfNeeded() {
    if (_currentSellerNotificationOrder != null) {
      debugPrint('[NotificationService] Re-showing seller notification for order: ${_currentSellerNotificationOrder!.orderId}');
      // Small delay to ensure previous SnackBar is fully dismissed
      Future.delayed(const Duration(milliseconds: 300), () {
        _showSellerSnackBar(
          _currentSellerNotificationOrder!,
          pendingCount: _currentSellerNotificationPendingCount,
        );
      });
    }
  }

  // Bottom floating SnackBar implementation (default)
  static bool _showSellerSnackBar(
    Order order, {
    int pendingCount = 1,
  }) {
    // ALWAYS use navigator key context (more stable than passed context)
    final scaffoldContext = _navigatorKey?.currentContext;
    if (scaffoldContext == null || !scaffoldContext.mounted) {
      debugPrint('[NotificationService] No valid navigator context for showing notification. Navigator key: ${_navigatorKey != null}');
      return false;
    }

    debugPrint('[NotificationService] Showing SnackBar notification for order: ${order.orderId}');
    debugPrint('[NotificationService] ScaffoldMessenger context: ${scaffoldContext.toString()}');
    try {
      // Track current seller notification for re-showing after interruptions
      _currentSellerNotificationOrder = order;
      _currentSellerNotificationPendingCount = pendingCount;

      final messenger = ScaffoldMessenger.of(scaffoldContext);
      debugPrint('[NotificationService] Got ScaffoldMessenger, showing SnackBar');
      final mediaQuery = MediaQuery.of(scaffoldContext);
      final bottomSafe = mediaQuery.padding.bottom;
      // Position notification exactly like "Added to cart" SnackBar
      // "Added to cart" has NO custom margin - uses default SnackBar positioning
      // Default floating SnackBar appears ~16px from bottom nav bar
      // _currentBottomInset = 70px (nav height + small gap)
      final bottomMargin = bottomSafe + _currentBottomInset;
      final safeCount = pendingCount < 1 ? 1 : pendingCount;
      final countLabel = safeCount > 10 ? '10+' : '$safeCount';
      final showCount = safeCount > 1;
      final pendingText =
          showCount ? '$countLabel orders pending approval' : null;

      // Don't clear existing snackbars - just show the new one (it will replace if needed)
      debugPrint('[NotificationService] Bottom margin calculated: $bottomMargin (bottomSafe: $bottomSafe, inset: $_currentBottomInset)');
      messenger.showSnackBar(
        SnackBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          behavior: SnackBarBehavior.floating, // Floating behavior positions from bottom
          padding: EdgeInsets.zero,
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: bottomMargin.clamp(10.0, 35.0), // Clamp to 10-35px range
          ), // Position with minimal gap (8-12px) above Buyer/Seller toggle
          // Persist until user takes action - seller must acknowledge new orders
          duration: const Duration(days: 1), // Very long duration - dismisses only on user action
          content: _NewOrderNotificationCard(
            title: (order.isLiveKitchenOrder ?? false)
                ? (showCount
                    ? 'New Live Kitchen Orders'
                    : 'New Live Kitchen Order')
                : (showCount ? 'New Orders Received' : 'New Order Received'),
            orderLine:
                '${order.foodName}${(order.isLiveKitchenOrder ?? false) ? "" : " × ${order.quantity}"} - ₹${order.pricePaid.toStringAsFixed(0)}',
            orderId: order.orderId.length > 6
                ? order.orderId.substring(order.orderId.length - 6)
                : order.orderId,
            pendingText: pendingText,
            onView: () {
              // Dismiss the snackbar
              ScaffoldMessenger.of(scaffoldContext).hideCurrentSnackBar();
              // Navigate to seller dashboard where they can accept/reject orders
              final sellerId = order.sellerId.isNotEmpty
                  ? order.sellerId
                  : FirebaseAuth.instance.currentUser?.uid ?? '';
              if (sellerId.isNotEmpty && scaffoldContext.mounted) {
                Navigator.push(
                  scaffoldContext,
                  MaterialPageRoute(
                    builder: (_) => SellerDashboardScreen(sellerId: sellerId),
                  ),
                );
              }
            },
          ),
        ),
      );
      debugPrint('[NotificationService] SnackBar displayed successfully for order: ${order.orderId}');
      return true;
    } catch (e, stackTrace) {
      debugPrint('[NotificationService] Error showing SnackBar: $e');
      debugPrint('[NotificationService] Stack trace: $stackTrace');
      return false;
    }
  }

  // (Legacy) Top banner overlay implementation removed from active use.

  // Track shown notifications to avoid duplicates (persist across app sessions)
  static final Set<String> _shownNotifications = <String>{};
  static final Map<String, DateTime> _lastShownAt = <String, DateTime>{};
  // Track explicitly dismissed notifications (should not re-show)
  static final Set<String> _dismissedNotifications = <String>{};
  // Track shown buyer acceptance notifications
  static final Set<String> _shownBuyerAcceptanceNotifications = <String>{};
  
  // Dismiss notification for a specific order (when seller accepts/rejects)
  static void dismissNotificationForOrder(String orderId, BuildContext? context) {
    // Use orderId as the key (consistent with checkForNewOrders)
    final notificationKey = orderId;
    _dismissedNotifications.add(notificationKey); // Mark as explicitly dismissed
    _shownNotifications.add(notificationKey);
    _lastShownAt[notificationKey] = DateTime.now();
    
    // Clear tracked seller notification if this is the current one
    if (_currentSellerNotificationOrder?.orderId == orderId) {
      _currentSellerNotificationOrder = null;
      _currentSellerNotificationPendingCount = 1;
    }
    
    debugPrint('[NotificationService] Dismissed notification for order: $orderId');
    debugPrint('[NotificationService] Added to dismissed list, will not show again');
    
    // Dismiss any active SnackBar using navigator context (more reliable)
    final scaffoldContext = _navigatorKey?.currentContext;
    if (scaffoldContext != null && scaffoldContext.mounted) {
      try {
        // Clear all snackbars to ensure the notification is removed
        ScaffoldMessenger.of(scaffoldContext).clearSnackBars();
        debugPrint('[NotificationService] Cleared all SnackBars');
      } catch (e) {
        debugPrint('[NotificationService] Error clearing SnackBars: $e');
      }
    }
    
    // Dismiss platform-specific notifications
    _local.cancel(orderId.hashCode); // Use a consistent ID for cancellation
  }

  // Public method to re-show seller notification after other notifications dismiss
  static void reShowSellerNotificationIfNeeded() {
    _reShowSellerNotificationIfNeeded();
  }
  static void registerNavigatorKey(GlobalKey<NavigatorState> navKey) {
    _navigatorKey = navKey;
  }

  static Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) async {
        final actionId = resp.actionId ?? '';
        if (actionId.startsWith('ACCEPT_')) {
          final orderId = actionId.substring(7);
          await _handleAction(orderId, accept: true);
        } else if (actionId.startsWith('REJECT_')) {
          final orderId = actionId.substring(7);
          await _handleAction(orderId, accept: false);
        } else {
          final payload = resp.payload ?? '';
          if (payload.startsWith('OPEN_')) {
            final orderId = payload.substring(5);
            _openOrder(orderId);
          }
        }
      },
    );

    // Runtime notification permission (Android 13+ and iOS)
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _local
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Alerts for new orders awaiting your action',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    _initialized = true;
  }

  static Future<void> _handleAction(String orderId, {required bool accept}) async {
    try {
      final order = _notificationBox.values.firstWhere(
        (o) => o.orderId == orderId,
        orElse: () => throw 'Order not found',
      );
      order.orderStatus = accept ? 'AcceptedBySeller' : 'RejectedBySeller';
      order.sellerRespondedAt = DateTime.now();
      await order.save();
      await OrderFirestoreService.updateStatus(
        orderId: orderId,
        status: order.orderStatus,
        sellerRespondedAt: order.sellerRespondedAt,
      );
      WebOrderBroadcast.postStatus(orderId: orderId, status: order.orderStatus);
    } catch (e) {
      debugPrint('Failed to handle action for $orderId: $e');
    }
  }

  static void _openOrder(String orderId) {
    final nav = _navigatorKey;
    if (nav == null) return;
    final sellerId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (sellerId.isEmpty) return;
    nav.currentState?.push(
      MaterialPageRoute(
        builder: (_) => SellerDashboardScreen(sellerId: sellerId),
      ),
    );
  }

  // Check for new orders and show notifications
  static void checkForNewOrders(BuildContext context, String sellerId) async {
    if (!context.mounted) {
      debugPrint('[NotificationService] Context not mounted');
      return;
    }

    if (!_notificationBox.isOpen || !_listingBox.isOpen) {
      debugPrint('[NotificationService] boxes not open');
      return;
    }

    // Checking for new orders silently (reduces log spam)

    final orders = _notificationBox.values.where((order) {
      // Check if order is for this seller and is pending
      bool isForSeller = false;

      // Primary: sellerId present on order
      if (order.sellerId.isNotEmpty) {
        isForSeller = order.sellerId == sellerId;
      } else {
        // Fallback: look up listing to find sellerId (older orders)
        final listingKey = int.tryParse(order.listingId);
        if (listingKey != null) {
          final listing = _listingBox.get(listingKey);
          isForSeller = listing?.sellerId == sellerId;
        }
      }

      // Accept paymentCompletedAt or fallback to purchasedAt for recency
      final orderTime = order.paymentCompletedAt ?? order.purchasedAt;
      final isRecent = orderTime.isAfter(DateTime.now().subtract(const Duration(days: 7)));

      // Consider pending / awaiting / completed payments for notification
      // Exclude orders that have been accepted or rejected
      final isLiveKitchen = order.isLiveKitchenOrder ?? false;
      
      // For regular orders, check standard pending statuses
      // For Live Kitchen orders, check Live Kitchen specific statuses
      final isPending = isLiveKitchen
          ? (order.orderStatus == 'OrderReceived' || order.orderStatus == 'Preparing')
          : (order.orderStatus == 'PaymentPending' ||
             order.orderStatus == 'PaymentCompleted' ||
             order.orderStatus == 'AwaitingSellerConfirmation');
      
      // Exclude orders that have been responded to
      final isResponded = order.orderStatus == 'AcceptedBySeller' ||
          order.orderStatus == 'RejectedBySeller' ||
          order.orderStatus == 'Confirmed' ||
          order.orderStatus == 'Completed' ||
          order.orderStatus == 'Cancelled';

      return isForSeller && isPending && !isResponded && isRecent;
    }).toList()
      ..sort((a, b) => (b.paymentCompletedAt ?? b.purchasedAt).compareTo(a.paymentCompletedAt ?? a.purchasedAt));

    // Found ${orders.length} pending orders for seller (logged only when > 0)

    // Show notification for the most recent order not yet shown
    for (final order in orders) {
      debugPrint('[NotificationService] Checking order: ${order.orderId}, status: ${order.orderStatus}');
      // Use orderId as the key (simpler and more reliable)
      final notificationKey = order.orderId;
      
      // Skip if explicitly dismissed (seller accepted/rejected)
      if (_dismissedNotifications.contains(notificationKey)) {
        debugPrint('[NotificationService] Order ${order.orderId} was dismissed, skipping');
        continue;
      }

      // Skip if a notification for this order is already in-flight (prevents duplicate SnackBars
      // when checkForNewOrders is invoked from multiple listeners at nearly the same time).
      if (_sellerInFlightNotifications.contains(notificationKey)) {
        debugPrint('[NotificationService] Notification for ${order.orderId} already in-flight, skipping');
        continue;
      }
      
      // For pending orders, allow re-showing after a short delay to prevent spam
      // This ensures notifications persist until action is taken
      final lastShown = _lastShownAt[notificationKey];
      final shortDelay = const Duration(seconds: 3); // Short delay to prevent spam
      if (lastShown != null && DateTime.now().difference(lastShown) <= shortDelay) {
        debugPrint('[NotificationService] Order ${order.orderId} shown very recently (${DateTime.now().difference(lastShown).inSeconds}s ago), skipping to prevent spam');
        continue;
      }
      // After short delay, allow re-showing for pending orders
      
      // If notification was shown before but order is still pending and enough time has passed, allow re-showing
      // This handles cases where the snackbar was hidden (e.g., switching to cart tab) but order is still pending
      
      // Double-check order hasn't been accepted/rejected since we filtered
      // Also check if it's in dismissed list (should have been added when seller accepted/rejected)
      final isLiveKitchen = order.isLiveKitchenOrder ?? false;
      final isStillPending = isLiveKitchen
          ? (order.orderStatus == 'OrderReceived' || order.orderStatus == 'Preparing')
          : (order.orderStatus == 'PaymentPending' ||
             order.orderStatus == 'PaymentCompleted' ||
             order.orderStatus == 'AwaitingSellerConfirmation');
      
      // If order is already accepted/rejected, skip it (shouldn't happen due to filter above, but double-check)
      final isAlreadyResponded = order.orderStatus == 'AcceptedBySeller' ||
          order.orderStatus == 'RejectedBySeller' ||
          order.orderStatus == 'Confirmed' ||
          order.orderStatus == 'Completed' ||
          order.orderStatus == 'Cancelled';
      
      // Also check if this order was explicitly dismissed (even if status hasn't updated yet)
      if (_dismissedNotifications.contains(notificationKey)) {
        debugPrint('[NotificationService] Order ${order.orderId} is in dismissed list, skipping');
        continue;
      }

      if (isStillPending && !isAlreadyResponded) {
        debugPrint('[NotificationService] Attempting to show notification for order: ${order.orderId}');
        
        // Check Firestore status FIRST before showing (to avoid showing for already accepted/rejected orders)
        // Use timeout to prevent blocking when Firestore is offline
        bool shouldShow = true;
        try {
          final doc = await OrderFirestoreService.doc(order.orderId)
              .get()
              .timeout(
                const Duration(seconds: 2),
                onTimeout: () {
                  debugPrint('[NotificationService] Firestore check timeout for ${order.orderId}, will show notification based on local status');
                  return OrderFirestoreService.doc(order.orderId).get(); // Return a future that will fail gracefully
                },
              );
          if (doc.exists) {
            final firestoreStatus = doc.data()?['orderStatus'] as String?;
            // If order is accepted/rejected in Firestore, don't show notification
            if (firestoreStatus == 'AcceptedBySeller' ||
                firestoreStatus == 'RejectedBySeller' ||
                firestoreStatus == 'Confirmed' ||
                firestoreStatus == 'Completed' ||
                firestoreStatus == 'Cancelled') {
              debugPrint('[NotificationService] Order ${order.orderId} already $firestoreStatus in Firestore, marking as dismissed');
              _dismissedNotifications.add(notificationKey);
              shouldShow = false;
            } else {
              debugPrint('[NotificationService] Firestore status for ${order.orderId}: $firestoreStatus, will show notification');
            }
          } else {
            debugPrint('[NotificationService] Firestore document does not exist for ${order.orderId}, will show notification based on local status');
          }
        } catch (e) {
          debugPrint('[NotificationService] Failed to check Firestore status for ${order.orderId}: $e, will show notification anyway');
          // If Firestore check fails, show notification based on local status
        }
        
        if (!shouldShow) {
          debugPrint('[NotificationService] Skipping notification for ${order.orderId} (already processed in Firestore)');
          continue; // Skip this order
        }
        
        debugPrint('[NotificationService] Proceeding to show notification for order: ${order.orderId}');
        
        // ALWAYS use navigator key context for notifications (more stable than ValueListenableBuilder context)
        final notificationContext = _navigatorKey?.currentContext;
        if (notificationContext != null && notificationContext.mounted) {
          // Try to show notification first, only mark as shown if successful
          _sellerInFlightNotifications.add(notificationKey);
          final success = await _showLocalNotification(
            order,
            notificationContext,
            pendingCount: orders.length,
          );
          if (success) {
            // Wait a moment to ensure SnackBar is actually displayed before marking as shown
            await Future.delayed(const Duration(milliseconds: 100));
            // Only mark as shown AFTER successfully displaying and a brief delay
            _shownNotifications.add(notificationKey);
            _lastShownAt[notificationKey] = DateTime.now();
            debugPrint('[NotificationService] Notification successfully shown for order: ${order.orderId}');
            debugPrint('[NotificationService] Notification marked as shown, will not re-show for 3 seconds');
          } else {
            debugPrint('[NotificationService] Failed to show notification for order: ${order.orderId}');
            // Don't mark as shown if it failed, so it can retry
          }
          _sellerInFlightNotifications.remove(notificationKey);
        } else {
          debugPrint('[NotificationService] No valid navigator context available, cannot show notification. Navigator key: ${_navigatorKey != null}');
        }
        
        // Only show one notification at a time
        break;
      } else {
        debugPrint('[NotificationService] Order ${order.orderId} is not pending (status: ${order.orderStatus}), skipping');
      }
    }
  }

  static Future<bool> _showLocalNotification(
    Order order,
    BuildContext context, {
    int pendingCount = 1,
  }) async {
    await init();

    // Web fallback: show in-app banner/snackbar
    if (kIsWeb) {
      // ALWAYS use navigator key context for web notifications (more stable)
      final notificationContext = _navigatorKey?.currentContext;
      if (notificationContext != null && notificationContext.mounted) {
        debugPrint('[NotificationService] Web: Showing notification with navigator context');
        try {
          showOrderNotification(notificationContext, order, pendingCount: pendingCount);
          return true; // Successfully shown
        } catch (e) {
          debugPrint('[NotificationService] Web: Error showing notification: $e');
          return false; // Failed to show
        }
      } else {
        debugPrint('[NotificationService] Web: No valid navigator context for notification. Navigator key: ${_navigatorKey != null}');
        return false;
      }
    }

    final isLiveKitchen = order.isLiveKitchenOrder ?? false;
    final title = isLiveKitchen 
        ? '🔥 Live Kitchen Order: ${order.foodName}'
        : 'New order: ${order.foodName} × ${order.quantity}';
    final body = isLiveKitchen
        ? 'Order ${order.orderId.substring(order.orderId.length - 6)} • ₹${order.pricePaid.toStringAsFixed(0)} • Status: ${order.statusDisplayText}'
        : 'Order ${order.orderId} • ₹${order.pricePaid.toStringAsFixed(0)} • Awaiting your action';
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.max,
      priority: Priority.high,
      ongoing: false,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.call,
      actions: [
        AndroidNotificationAction('ACCEPT_${order.orderId}', 'Accept'),
        AndroidNotificationAction('REJECT_${order.orderId}', 'Reject'),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    try {
      await _local.show(
        order.hashCode,
        title,
        body,
        details,
        payload: 'OPEN_${order.orderId}',
      );
      return true; // Successfully shown
    } catch (e) {
      debugPrint('[NotificationService] Error showing platform notification: $e');
      return false; // Failed to show
    }
  }

  // Show buyer notification when seller accepts order
  static bool showBuyerAcceptanceNotification(BuildContext? context, Order order, String sellerPhone, String pickupLocation) {
    final notificationKey = 'buyer_acceptance_${order.orderId}';
    
    // Skip if already shown
    if (_shownBuyerAcceptanceNotifications.contains(notificationKey)) {
      debugPrint('[NotificationService] Buyer acceptance notification already shown for order: ${order.orderId}');
      return false;
    }
    
    // ALWAYS use navigator key context (more stable than passed context)
    final scaffoldContext = _navigatorKey?.currentContext;
    if (scaffoldContext == null || !scaffoldContext.mounted) {
      debugPrint('[NotificationService] No valid navigator context for showing buyer acceptance notification. Navigator key: ${_navigatorKey != null}');
      return false;
    }
    
    debugPrint('[NotificationService] Showing buyer acceptance notification for order: ${order.orderId}');
    try {
      final messenger = ScaffoldMessenger.of(scaffoldContext);
      messenger.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade300, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Order Accepted! 🎉',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    _shownBuyerAcceptanceNotifications.add(notificationKey); // Mark as dismissed
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${order.foodName} × ${order.quantity}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Order ID: ${order.orderId} • ${order.userId}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (sellerPhone.isNotEmpty || pickupLocation.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (sellerPhone.isNotEmpty)
                    _BuyerNotificationActionChip(
                      icon: Icons.phone,
                      label: sellerPhone,
                      onTap: () async {
                        final cleanedPhone = sellerPhone.replaceAll(RegExp(r'[^\d+]'), '');
                        final telUrl = 'tel:$cleanedPhone';
                        final uri = Uri.parse(telUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                    ),
                  if (sellerPhone.isNotEmpty && pickupLocation.isNotEmpty)
                    const SizedBox(width: 8),
                  if (pickupLocation.isNotEmpty)
                    _BuyerNotificationActionChip(
                      icon: Icons.location_on,
                      label: 'View on Maps',
                      onTap: () async {
                        final isCoordinates = RegExp(r'^-?\d+\.?\d*,\s*-?\d+\.?\d*$')
                            .hasMatch(pickupLocation.trim());
                        final googleMapsUrl = isCoordinates
                            ? 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(pickupLocation)}'
                            : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(pickupLocation)}';
                        final uri = Uri.parse(googleMapsUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
        backgroundColor: const Color(0xFFA7E3B3), // Soft green from AppTheme.successColor
        // Persist until user takes action - buyer must acknowledge order acceptance
        duration: const Duration(days: 1), // Very long duration - dismisses only on user action
        behavior: SnackBarBehavior.floating, // Make it floating so it's more visible
        margin: const EdgeInsets.all(16), // Add margin for floating behavior
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
        action: SnackBarAction(
          label: 'View Order',
          textColor: const Color(0xFF2E3440), // Dark text from AppTheme
          backgroundColor: Colors.white,
          onPressed: () {
            messenger.hideCurrentSnackBar();
            if (scaffoldContext.mounted) {
              Navigator.push(
                scaffoldContext,
                MaterialPageRoute(
                  builder: (_) => OrderDetailsScreen(order: order),
                ),
              );
            }
          },
        ),
      ),
    );
    // Only mark as shown AFTER successfully displaying
    _shownBuyerAcceptanceNotifications.add(notificationKey);
    debugPrint('[NotificationService] Buyer acceptance SnackBar displayed successfully for order: ${order.orderId}');
    return true;
    } catch (e, stackTrace) {
      debugPrint('[NotificationService] Error showing buyer acceptance SnackBar: $e');
      debugPrint('[NotificationService] Stack trace: $stackTrace');
      return false;
    }
  }

  // Check for accepted orders and show buyer notifications
  static void checkForAcceptedOrders(BuildContext context, String buyerId) async {
    if (!context.mounted) return;

    if (!_notificationBox.isOpen) {
      debugPrint('[NotificationService] ordersBox not open');
      return;
    }

    final orders = _notificationBox.values.where((order) {
      // Check if order is for this buyer and was recently accepted
      final isForBuyer = order.userId == buyerId;
      final isAccepted = order.orderStatus == 'AcceptedBySeller' || 
                         order.orderStatus == 'Confirmed' ||
                         order.orderStatus == 'ReadyForPickup';
      
      // Only show for recent orders (within last 7 days)
      final orderTime = order.paymentCompletedAt ?? order.purchasedAt;
      final isRecent = orderTime.isAfter(DateTime.now().subtract(const Duration(days: 7)));
      
      return isForBuyer && isAccepted && isRecent;
    }).toList()
      ..sort((a, b) => (b.paymentCompletedAt ?? b.purchasedAt).compareTo(a.paymentCompletedAt ?? a.purchasedAt));

    for (final order in orders) {
      final notificationKey = 'buyer_acceptance_${order.orderId}';
      
      // Skip if already shown
      if (_shownBuyerAcceptanceNotifications.contains(notificationKey)) {
        continue;
      }
      
      // Get seller details from Firestore
      try {
        final doc = await OrderFirestoreService.doc(order.orderId).get();
        if (doc.exists) {
          final data = doc.data();
          final sellerPhone = (data?['sellerPhone'] as String?) ?? '';
          final pickupLocation = (data?['sellerPickupLocation'] as String?) ?? '';
          
          // Only show if we have seller details
          if (sellerPhone.isNotEmpty || pickupLocation.isNotEmpty) {
            // Use navigator key context instead of passed context (more stable)
            final notificationContext = _navigatorKey?.currentContext;
            if (notificationContext != null && notificationContext.mounted) {
              final success = showBuyerAcceptanceNotification(notificationContext, order, sellerPhone, pickupLocation);
              if (success) {
                debugPrint('[NotificationService] Buyer acceptance notification successfully shown for order: ${order.orderId}');
                // Only show one notification at a time
                break;
              } else {
                debugPrint('[NotificationService] Failed to show buyer acceptance notification for order: ${order.orderId}');
              }
            } else {
              debugPrint('[NotificationService] No valid navigator context for buyer acceptance notification');
            }
          } else {
            debugPrint('[NotificationService] Seller details not available for order ${order.orderId}, skipping buyer notification');
          }
        }
      } catch (e) {
        debugPrint('Failed to get seller details for order ${order.orderId}: $e');
      }
    }
  }
}

class _NewOrderNotificationCard extends StatelessWidget {
  final String title;
  final String orderLine;
  final String orderId;
  final String? pendingText;
  final VoidCallback onView;

  const _NewOrderNotificationCard({
    required this.title,
    required this.orderLine,
    required this.orderId,
    this.pendingText,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Premium floating card design with status colors
    // Use teal/mint for pending orders (primary brand color)
    const Color backgroundColor = Color(0xFF5EC6C6); // Teal from AppTheme
    const Color onBackgroundColor = Colors.white;

    return Material(
      color: Colors.transparent,
      elevation: 0,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: onBackgroundColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_active_rounded,
                color: onBackgroundColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: onBackgroundColor,
                        ) ??
                        TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: onBackgroundColor,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    orderLine,
                    style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: onBackgroundColor.withValues(alpha: 0.95),
                        ) ??
                        TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: onBackgroundColor.withValues(alpha: 0.95),
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (pendingText != null || orderId.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (pendingText != null) ...[
                          Flexible(
                            child: Text(
                              pendingText!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: onBackgroundColor.withValues(alpha: 0.9),
                                  ) ??
                                  TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: onBackgroundColor.withValues(alpha: 0.9),
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        if (pendingText != null && orderId.isNotEmpty)
                          Text(
                            ' • ',
                            style: TextStyle(
                              fontSize: 11,
                              color: onBackgroundColor.withValues(alpha: 0.6),
                            ),
                          ),
                        if (orderId.isNotEmpty)
                          Flexible(
                            child: Text(
                              'ID: $orderId',
                              style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: onBackgroundColor.withValues(alpha: 0.8),
                                  ) ??
                                  TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: onBackgroundColor.withValues(alpha: 0.8),
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onView,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: onBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'View',
                    style: theme.textTheme.labelMedium?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: backgroundColor,
                        ) ??
                        TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: backgroundColor,
                        ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuyerNotificationActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BuyerNotificationActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: Colors.green.shade700,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

