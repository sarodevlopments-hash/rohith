import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order.dart';
import '../models/listing.dart';
import '../screens/seller_dashboard_screen.dart';
import '../screens/order_details_screen.dart';
import '../services/order_firestore_service.dart';
import '../services/web_order_broadcast.dart';

class NotificationService {
  static final Box<Order> _notificationBox = Hive.box<Order>('ordersBox');
  static final Box<Listing> _listingBox = Hive.box<Listing>('listingBox');
  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static GlobalKey<NavigatorState>? _navigatorKey;
  static bool _initialized = false;
  static const String _channelId = 'new_orders_channel';
  static const String _channelName = 'New Orders';
  
  // Show in-app notification when new order arrives
  static bool showOrderNotification(BuildContext? context, Order order) {
    // ALWAYS use navigator key context (more stable than passed context)
    final scaffoldContext = _navigatorKey?.currentContext;
    if (scaffoldContext == null || !scaffoldContext.mounted) {
      debugPrint('[NotificationService] No valid navigator context for showing notification. Navigator key: ${_navigatorKey != null}');
      return false;
    }
    
      debugPrint('[NotificationService] Showing SnackBar notification for order: ${order.orderId}');
      debugPrint('[NotificationService] ScaffoldMessenger context: ${scaffoldContext.toString()}');
      try {
        final messenger = ScaffoldMessenger.of(scaffoldContext);
        debugPrint('[NotificationService] Got ScaffoldMessenger, showing SnackBar');
        // Don't clear existing snackbars - just show the new one (it will replace if needed)
        messenger.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    (order.isLiveKitchenOrder ?? false) ? Icons.restaurant : Icons.notifications_active, 
                    color: Colors.white, 
                    size: 24
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      (order.isLiveKitchenOrder ?? false) 
                          ? '🔥 Live Kitchen Order!'
                          : 'New Order Received!',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${order.foodName}${(order.isLiveKitchenOrder ?? false) ? "" : " × ${order.quantity}"} - ₹${order.pricePaid.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              if (order.isLiveKitchenOrder ?? false) ...[
                const SizedBox(height: 4),
                Text(
                  'Status: ${order.statusDisplayText}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Order ID: ${order.orderId.length > 6 ? order.orderId.substring(order.orderId.length - 6) : order.orderId}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 30), // Longer duration so user can see it
          behavior: SnackBarBehavior.floating, // Make it floating so it's more visible
          margin: const EdgeInsets.all(16), // Add margin for floating behavior
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
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

    debugPrint('[NotificationService] Checking for new orders for seller: $sellerId');
    debugPrint('[NotificationService] Total orders in box: ${_notificationBox.length}');

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

    debugPrint('[NotificationService] Found ${orders.length} pending orders for seller');

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
              debugPrint('[NotificationService] Order ${order.orderId} already ${firestoreStatus} in Firestore, marking as dismissed');
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
          final success = await _showLocalNotification(order, notificationContext);
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

  static Future<bool> _showLocalNotification(Order order, BuildContext context) async {
    await init();

    // Web fallback: show in-app banner/snackbar
    if (kIsWeb) {
      // ALWAYS use navigator key context for web notifications (more stable)
      final notificationContext = _navigatorKey?.currentContext;
      if (notificationContext != null && notificationContext.mounted) {
        debugPrint('[NotificationService] Web: Showing notification with navigator context');
        try {
          showOrderNotification(notificationContext, order);
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
            const SizedBox(height: 12),
            if (sellerPhone.isNotEmpty) ...[
              InkWell(
                onTap: () async {
                  final cleanedPhone = sellerPhone.replaceAll(RegExp(r'[^\d+]'), '');
                  final telUrl = 'tel:$cleanedPhone';
                  final uri = Uri.parse(telUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                child: Row(
                  children: [
                    Icon(Icons.phone, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seller Phone: $sellerPhone',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const Text(
                            'Tap to call',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (pickupLocation.isNotEmpty) ...[
              InkWell(
                onTap: () async {
                  final isCoordinates = RegExp(r'^-?\d+\.?\d*,\s*-?\d+\.?\d*$').hasMatch(pickupLocation.trim());
                  final googleMapsUrl = isCoordinates
                      ? 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(pickupLocation)}'
                      : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(pickupLocation)}';
                  final uri = Uri.parse(googleMapsUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pickup: ${pickupLocation.length > 30 ? pickupLocation.substring(0, 30) + "..." : pickupLocation}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const Text(
                            'Tap to open in Google Maps',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 30), // Longer duration so buyer can see it
        behavior: SnackBarBehavior.floating, // Make it floating so it's more visible
        margin: const EdgeInsets.all(16), // Add margin for floating behavior
        action: SnackBarAction(
          label: 'View Order',
          textColor: Colors.white,
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
                         order.orderStatus == 'Confirmed';
      
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

