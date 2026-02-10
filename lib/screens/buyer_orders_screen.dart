import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/order.dart';
import 'order_details_screen.dart';
import '../services/order_firestore_service.dart';
import '../widgets/seller_name_widget.dart';
import '../theme/app_theme.dart';

class BuyerOrdersScreen extends StatefulWidget {
  const BuyerOrdersScreen({super.key});

  @override
  State<BuyerOrdersScreen> createState() => _BuyerOrdersScreenState();
}

class _BuyerOrdersScreenState extends State<BuyerOrdersScreen> {
  String _selectedFilter = 'All'; // All, Confirmed, Completed, Cancelled

  Color _getStatusColor(Order order) {
    if (order.isLiveKitchenOrder ?? false) {
      return order.statusColor;
    }
    switch (order.orderStatus) {
      case 'Confirmed':
        return Colors.blue;
      case 'Completed':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(Order order) {
    if (order.isLiveKitchenOrder ?? false) {
      switch (order.orderStatus) {
        case 'OrderReceived':
          return Icons.restaurant;
        case 'Preparing':
          return Icons.restaurant_menu;
        case 'ReadyForPickup':
        case 'ReadyForDelivery':
          return Icons.check_circle;
        case 'Completed':
          return Icons.done_all;
        case 'Cancelled':
          return Icons.cancel_outlined;
        default:
          return Icons.info_outline;
      }
    }
    switch (order.orderStatus) {
      case 'Confirmed':
        return Icons.check_circle_outline;
      case 'Completed':
        return Icons.done_all;
      case 'Cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Widget buildContent() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Please log in to view orders'));
    }

    return ValueListenableBuilder(
        valueListenable: Hive.box<Order>('ordersBox').listenable(),
        builder: (context, Box<Order> box, _) {
          final allOrders = box.values
              .where((order) => order.userId == currentUser.uid)
              .toList();

          // Sort by date (newest first)
          allOrders.sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));

          // Filter orders
          final filteredOrders = _selectedFilter == 'All'
              ? allOrders
              : allOrders.where((o) => o.orderStatus == _selectedFilter).toList();

          if (filteredOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColorAlt,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      size: 64,
                      color: AppTheme.disabledText,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _selectedFilter == 'All'
                        ? 'No orders yet'
                        : 'No $_selectedFilter orders',
                    style: AppTheme.heading3.copyWith(color: AppTheme.lightText),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start shopping to see your orders here',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.disabledText),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Filter chips
              if (_selectedFilter != 'All')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppTheme.cardColor,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedFilter,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedFilter = 'All';
                                });
                              },
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              // Orders list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    return _buildOrderCard(order);
                  },
                ),
              ),
            ],
          );
        },
      );
  }

  Widget _buildOrderCard(Order order) {
    final isAccepted = order.orderStatus == 'AcceptedBySeller' ||
        order.orderStatus == 'Confirmed';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isAccepted
            ? Border.all(color: Colors.green.shade400, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: isAccepted
                ? Colors.green.withOpacity(0.15)
                : Colors.black.withOpacity(0.08),
            blurRadius: isAccepted ? 15 : 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailsScreen(order: order),
            ),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Order ID and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Order #${order.orderId.substring(order.orderId.length - 6)}',
                              style: AppTheme.heading3.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkText,
                              ),
                            ),
                            if (isAccepted) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.successGradient,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Accepted',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatDateTime(order.purchasedAt),
                          style: AppTheme.bodySmall.copyWith(
                            fontSize: 12,
                            color: AppTheme.lightText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(order).withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (order.isLiveKitchenOrder ?? false) ...[
                          Icon(
                            Icons.restaurant_rounded,
                            size: 14,
                            color: _getStatusColor(order),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Icon(
                          _getStatusIcon(order),
                          size: 16,
                          color: _getStatusColor(order),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            order.statusDisplayText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(order),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Divider(height: 1, color: AppTheme.borderColor.withOpacity(0.5)),
              const SizedBox(height: 18),
              // Order details
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product image placeholder
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColorAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.fastfood_rounded,
                      color: AppTheme.disabledText,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.foodName,
                          style: AppTheme.heading3.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkText,
                          ),
                        ),
                        // Show size and color if available
                        if ((order.selectedSize != null && order.selectedSize!.isNotEmpty) ||
                            (order.selectedColor != null && order.selectedColor!.isNotEmpty)) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (order.selectedSize != null && order.selectedSize!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.blue.shade200, width: 0.5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.straighten, size: 12, color: Colors.blue.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Size: ${order.selectedSize}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (order.selectedColor != null && order.selectedColor!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.purple.shade200, width: 0.5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.palette, size: 12, color: Colors.purple.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Color: ${order.selectedColor}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.purple.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        const SizedBox(height: 6),
                        // Show seller name (blurred before confirmation, clear after) for groceries/vegetables
                        SellerNameWidget(
                          sellerName: order.sellerName,
                          shouldHideSellerIdentity: order.shouldHideSellerIdentity(),
                          isOrderAccepted: isAccepted,
                          style: AppTheme.bodySmall.copyWith(
                            fontSize: 13,
                            color: AppTheme.lightText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildSellerContactIfAccepted(order),
                        const SizedBox(height: 6),
                        Text(
                          'Qty: ${order.quantity} × ₹${order.discountedPrice.toStringAsFixed(0)}',
                          style: AppTheme.bodySmall.copyWith(
                            fontSize: 13,
                            color: AppTheme.lightText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Price and savings
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total: ₹${order.pricePaid.toStringAsFixed(0)}',
                        style: AppTheme.heading2.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText,
                        ),
                      ),
                      if (order.savedAmount > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: AppTheme.successGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Saved ₹${order.savedAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColorAlt,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.disabledText,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSellerContactIfAccepted(Order order) {
    final accepted = order.orderStatus == 'AcceptedBySeller' ||
        order.orderStatus == 'Confirmed' ||
        order.orderStatus == 'Completed';
    if (!accepted) {
      final shouldHideSeller = order.shouldHideSellerIdentity();
      return Text(
        shouldHideSeller
            ? 'Seller name, contact & pickup location will appear after acceptance.'
            : 'Seller contact & pickup location will appear after acceptance.',
        style: AppTheme.bodySmall.copyWith(fontSize: 12, color: AppTheme.lightText),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: OrderFirestoreService.doc(order.orderId).snapshots(),
      builder: (context, snap) {
        final data = (snap.data?.exists ?? false) ? snap.data!.data() : null;
        final phone = (data?['sellerPhone'] as String?) ?? '';
        final pickup = (data?['sellerPickupLocation'] as String?) ?? '';
        if (phone.isEmpty && pickup.isEmpty) {
          return Text(
            'Seller details unavailable',
            style: AppTheme.bodySmall.copyWith(fontSize: 12, color: AppTheme.lightText),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show seller name for groceries/vegetables after acceptance
            if (order.shouldHideSellerIdentity()) ...[
              Text('Seller: ${order.sellerName}', style: AppTheme.bodySmall.copyWith(fontSize: 12, color: AppTheme.lightText, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
            ],
            if (phone.isNotEmpty)
              Text('Seller phone: $phone', style: AppTheme.bodySmall.copyWith(fontSize: 12, color: AppTheme.lightText)),
            if (pickup.isNotEmpty)
              Text('Pickup: $pickup', style: AppTheme.bodySmall.copyWith(fontSize: 12, color: AppTheme.lightText)),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.cardColor,
        title: Text(
          'My Orders',
          style: AppTheme.heading3.copyWith(color: AppTheme.darkText),
        ),
        iconTheme: const IconThemeData(color: AppTheme.darkText),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: AppTheme.darkText),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All Orders')),
              const PopupMenuItem(value: 'Confirmed', child: Text('Confirmed')),
              const PopupMenuItem(value: 'Completed', child: Text('Completed')),
              const PopupMenuItem(value: 'Cancelled', child: Text('Cancelled')),
            ],
          ),
        ],
      ),
      body: buildContent(),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

// Content widget for use in MainTabScreen
class BuyerOrdersContent extends StatefulWidget {
  const BuyerOrdersContent({super.key});

  @override
  State<BuyerOrdersContent> createState() => _BuyerOrdersContentState();
}

class _BuyerOrdersContentState extends State<BuyerOrdersContent> {
  String _selectedFilter = 'All';

  Color _getStatusColor(Order order) {
    if (order.isLiveKitchenOrder ?? false) {
      return order.statusColor;
    }
    switch (order.orderStatus) {
      case 'Confirmed':
        return Colors.blue;
      case 'Completed':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(Order order) {
    if (order.isLiveKitchenOrder ?? false) {
      switch (order.orderStatus) {
        case 'OrderReceived':
          return Icons.restaurant;
        case 'Preparing':
          return Icons.restaurant_menu;
        case 'ReadyForPickup':
        case 'ReadyForDelivery':
          return Icons.check_circle;
        case 'Completed':
          return Icons.done_all;
        case 'Cancelled':
          return Icons.cancel_outlined;
        default:
          return Icons.info_outline;
      }
    }
    switch (order.orderStatus) {
      case 'Confirmed':
        return Icons.check_circle_outline;
      case 'Completed':
        return Icons.done_all;
      case 'Cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Please log in to view orders'));
    }

    return ValueListenableBuilder(
      valueListenable: Hive.box<Order>('ordersBox').listenable(),
      builder: (context, Box<Order> box, _) {
        final allOrders = box.values
            .where((order) => order.userId == currentUser.uid)
            .toList();

        allOrders.sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));

        final filteredOrders = _selectedFilter == 'All'
            ? allOrders
            : allOrders.where((o) => o.orderStatus == _selectedFilter).toList();

        if (filteredOrders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColorAlt,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: 64,
                    color: AppTheme.disabledText,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _selectedFilter == 'All'
                      ? 'No orders yet'
                      : 'No $_selectedFilter orders',
                  style: AppTheme.heading3.copyWith(color: AppTheme.lightText),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start shopping to see your orders here',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.disabledText),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Filter header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppTheme.cardColor,
              child: Row(
                children: [
                  Text(
                    'My Orders',
                    style: AppTheme.heading3.copyWith(color: AppTheme.darkText),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.filter_list, color: AppTheme.darkText),
                    onSelected: (value) {
                      setState(() {
                        _selectedFilter = value;
                      });
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'All', child: Text('All Orders')),
                      const PopupMenuItem(value: 'Confirmed', child: Text('Confirmed')),
                      const PopupMenuItem(value: 'Completed', child: Text('Completed')),
                      const PopupMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                    ],
                  ),
                ],
              ),
            ),
            // Filter chips
            if (_selectedFilter != 'All')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.cardColor,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedFilter,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFilter = 'All';
                              });
                            },
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            // Orders list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  final order = filteredOrders[index];
                  return _buildOrderCard(order);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrderCard(Order order) {
    final isAccepted = order.orderStatus == 'AcceptedBySeller' ||
        order.orderStatus == 'Confirmed' ||
        order.orderStatus == 'Completed';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: isAccepted
            ? Border.all(color: AppTheme.successColor.withOpacity(0.4), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: isAccepted
                ? AppTheme.successColor.withOpacity(0.1)
                : Colors.black.withOpacity(0.04),
            blurRadius: isAccepted ? 20 : 12,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailsScreen(order: order),
            ),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Order #${order.orderId.substring(order.orderId.length - 6)}',
                              style: AppTheme.heading3.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkText,
                              ),
                            ),
                            if (isAccepted) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.successGradient,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Accepted',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatDateTime(order.purchasedAt),
                          style: AppTheme.bodySmall.copyWith(
                            fontSize: 12,
                            color: AppTheme.lightText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(order).withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (order.isLiveKitchenOrder ?? false) ...[
                          Icon(
                            Icons.restaurant_rounded,
                            size: 14,
                            color: _getStatusColor(order),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Icon(
                          _getStatusIcon(order),
                          size: 16,
                          color: _getStatusColor(order),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            order.statusDisplayText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(order),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Divider(height: 1, color: AppTheme.borderColor.withOpacity(0.5)),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColorAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.fastfood_rounded,
                      color: AppTheme.disabledText,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.foodName,
                          style: AppTheme.heading3.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkText,
                          ),
                        ),
                        // Show size and color if available
                        if ((order.selectedSize != null && order.selectedSize!.isNotEmpty) ||
                            (order.selectedColor != null && order.selectedColor!.isNotEmpty)) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (order.selectedSize != null && order.selectedSize!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.blue.shade200, width: 0.5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.straighten, size: 12, color: Colors.blue.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Size: ${order.selectedSize}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (order.selectedColor != null && order.selectedColor!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.purple.shade200, width: 0.5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.palette, size: 12, color: Colors.purple.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Color: ${order.selectedColor}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.purple.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        // Show seller name (blurred before confirmation, clear after) for groceries/vegetables
                        Builder(
                          builder: (context) {
                            final isAccepted = order.orderStatus == 'AcceptedBySeller' ||
                                order.orderStatus == 'Confirmed' ||
                                order.orderStatus == 'Completed';
                            return SellerNameWidget(
                              sellerName: order.sellerName,
                              shouldHideSellerIdentity: order.shouldHideSellerIdentity(),
                              isOrderAccepted: isAccepted,
                              style: AppTheme.bodySmall.copyWith(
                                fontSize: 13,
                                color: AppTheme.lightText,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Qty: ${order.quantity} × ₹${order.discountedPrice.toStringAsFixed(0)}',
                          style: AppTheme.bodySmall.copyWith(
                            fontSize: 13,
                            color: AppTheme.lightText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total: ₹${order.pricePaid.toStringAsFixed(0)}',
                        style: AppTheme.heading2.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText,
                        ),
                      ),
                      if (order.savedAmount > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: AppTheme.successGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Saved ₹${order.savedAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColorAlt,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.disabledText,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}



