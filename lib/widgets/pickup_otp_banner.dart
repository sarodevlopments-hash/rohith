import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/order.dart';
import '../services/order_firestore_service.dart';
import '../screens/order_details_screen.dart';

class PickupOtpBanner extends StatefulWidget {
  const PickupOtpBanner({super.key});

  @override
  State<PickupOtpBanner> createState() => _PickupOtpBannerState();
}

class _PickupOtpBannerState extends State<PickupOtpBanner> {
  // Map of orderId -> dismissal timestamp (allows reappearing after 2 minutes)
  final Map<String, DateTime> _dismissedOrderIds = {};
  String? _currentOtp;
  String? _currentOrderShortId;

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    return ValueListenableBuilder<Box<Order>>(
      valueListenable: Hive.box<Order>('ordersBox').listenable(),
      builder: (context, ordersBox, _) {
        // Find orders with ReadyForPickup status and pending OTP
        // Clear old dismissals (older than 2 minutes) to allow reappearing
        final now = DateTime.now();
        _dismissedOrderIds.removeWhere((orderId, dismissedAt) =>
            now.difference(dismissedAt).inMinutes > 2);

        final readyForPickupOrders = ordersBox.values.where((order) {
          if (order.userId != userId) return false;
          if (order.orderStatus != 'ReadyForPickup') return false;
          // Check if recently dismissed (within last 2 minutes)
          final dismissedAt = _dismissedOrderIds[order.orderId];
          if (dismissedAt != null && now.difference(dismissedAt).inMinutes < 2) {
            return false; // Still in dismissal period
          }
          return true;
        }).toList();

        if (readyForPickupOrders.isEmpty) {
          _currentOtp = null;
          return const SizedBox.shrink();
        }

        // Sort by most recent (use sellerRespondedAt or purchasedAt)
        readyForPickupOrders.sort((a, b) =>
            (b.sellerRespondedAt ?? b.purchasedAt)
                .compareTo(a.sellerRespondedAt ?? a.purchasedAt));

        final order = readyForPickupOrders.first;

        // Get OTP from Firestore (real-time)
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: OrderFirestoreService.doc(order.orderId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const SizedBox.shrink();
            }

            final data = snapshot.data!.data()!;
            final firestoreStatus = data['orderStatus'] as String?;
            final pickupOtp = data['pickupOtp'] as String?;
            final otpStatus = data['otpStatus'] as String?;

            // Only show if status is ReadyForPickup and OTP is pending
            if (firestoreStatus != 'ReadyForPickup' ||
                otpStatus == 'verified' ||
                pickupOtp == null ||
                pickupOtp.isEmpty) {
              return const SizedBox.shrink();
            }

            // If OTP is verified or order is completed, clear dismissal and hide banner
            if (otpStatus == 'verified' || firestoreStatus == 'Completed') {
              _dismissedOrderIds.remove(order.orderId);
              return const SizedBox.shrink();
            }

            _currentOtp = pickupOtp;
            _currentOrderShortId = order.orderId.length > 6
                ? order.orderId.substring(order.orderId.length - 6)
                : order.orderId;

            return _buildBanner(context, order);
          },
        );
      },
    );
  }

  Widget _buildBanner(BuildContext context, Order order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade400,
            Colors.green.shade600,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailsScreen(order: order),
              ),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // Minimal circular status indicator with check icon
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.green,
                    size: 12,
                  ),
                ),
                const SizedBox(width: 8),
                // Order info
                Row(
                  children: [
                    const Text(
                      'Ready',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '#$_currentOrderShortId',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // OTP section with lock icon
                Row(
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'OTP:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _currentOtp ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                          letterSpacing: 1.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // View Order button
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetailsScreen(order: order),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'View',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Close button with proper tap area
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _dismissedOrderIds[order.orderId] = DateTime.now();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Banner dismissed. It will reappear if order is still ready.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                      opticalSize: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

