import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/order.dart';
import 'order_details_screen.dart';
import '../services/order_firestore_service.dart';
import '../widgets/seller_name_widget.dart';

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
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedFilter == 'All'
                        ? 'No orders yet'
                        : 'No $_selectedFilter orders',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start shopping to see your orders here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
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
                  color: Colors.white,
                  child: Row(
                    children: [
                      Chip(
                        label: Text(_selectedFilter),
                        onDeleted: () {
                          setState(() {
                            _selectedFilter = 'All';
                          });
                        },
                        deleteIcon: const Icon(Icons.close, size: 18),
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
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (isAccepted) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 12,
                                      color: Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Accepted',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(order.purchasedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(order),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (order.isLiveKitchenOrder ?? false) ...[
                          Icon(
                            Icons.restaurant,
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
                        const SizedBox(width: 4),
                        Text(
                          order.statusDisplayText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(order),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              // Order details
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product image placeholder
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.fastfood, color: Colors.grey),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.foodName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Show seller name (blurred before confirmation, clear after) for groceries/vegetables
                        SellerNameWidget(
                          sellerName: order.sellerName,
                          shouldHideSellerIdentity: order.shouldHideSellerIdentity(),
                          isOrderAccepted: isAccepted,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildSellerContactIfAccepted(order),
                        const SizedBox(height: 4),
                        Text(
                          'Qty: ${order.quantity} × ₹${order.discountedPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Price and savings
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total: ₹${order.pricePaid.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (order.savedAmount > 0)
                        Text(
                          'Saved: ₹${order.savedAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
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
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show seller name for groceries/vegetables after acceptance
            if (order.shouldHideSellerIdentity()) ...[
              Text('Seller: ${order.sellerName}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
            ],
            if (phone.isNotEmpty)
              Text('Seller phone: $phone', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            if (pickup.isNotEmpty)
              Text('Pickup: $pickup', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'My Orders',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.black87),
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
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  _selectedFilter == 'All'
                      ? 'No orders yet'
                      : 'No $_selectedFilter orders',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start shopping to see your orders here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
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
              color: Colors.white,
              child: Row(
                children: [
                  const Text(
                    'My Orders',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.filter_list, color: Colors.black87),
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
                color: Colors.white,
                child: Row(
                  children: [
                    Chip(
                      label: Text(_selectedFilter),
                      onDeleted: () {
                        setState(() {
                          _selectedFilter = 'All';
                        });
                      },
                      deleteIcon: const Icon(Icons.close, size: 18),
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
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (isAccepted) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 12,
                                      color: Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Accepted',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(order.purchasedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(order),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (order.isLiveKitchenOrder ?? false) ...[
                          Icon(
                            Icons.restaurant,
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
                        const SizedBox(width: 4),
                        Text(
                          order.statusDisplayText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(order),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.fastfood, color: Colors.grey),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.foodName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
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
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Qty: ${order.quantity} × ₹${order.discountedPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total: ₹${order.pricePaid.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (order.savedAmount > 0)
                        Text(
                          'Saved: ₹${order.savedAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
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

