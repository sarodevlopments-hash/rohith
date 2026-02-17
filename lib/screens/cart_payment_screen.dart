import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:async';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../services/cart_service.dart';
import '../models/listing.dart';
import '../models/order.dart';
import '../services/order_firestore_service.dart';
import '../services/web_order_broadcast.dart';
import '../services/user_service.dart';
import '../services/seller_profile_service.dart';
import '../services/accepted_order_notification_service.dart';
import '../theme/app_theme.dart';

class CartPaymentScreen extends StatefulWidget {
  final List<CartItemData> items;

  const CartPaymentScreen({super.key, required this.items});

  @override
  State<CartPaymentScreen> createState() => _CartPaymentScreenState();
}

class _CartPaymentScreenState extends State<CartPaymentScreen> {
  String _selectedPaymentMethod = 'UPI';
  bool _isProcessing = false;
  final TextEditingController _upiController = TextEditingController();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardNameController = TextEditingController();
  final TextEditingController _cardExpiryController = TextEditingController();
  final TextEditingController _cardCvvController = TextEditingController();
  final TextEditingController _buyerLocationController = TextEditingController();

  double get _total {
    if (widget.items.isEmpty) return 0.0;
    try {
      return widget.items.fold<double>(0.0, (sum, i) {
        // Safely get total, handling potential nulls
        final itemPrice = i.price;
        if (itemPrice == null || itemPrice.isNaN || itemPrice.isInfinite) {
          return sum;
        }
        final itemTotal = itemPrice * (i.quantity);
        if (itemTotal.isNaN || itemTotal.isInfinite) return sum;
        return sum + itemTotal;
      });
    } catch (e) {
      debugPrint('Error calculating total: $e');
      return 0.0;
    }
  }
  
  double get _originalTotal {
    if (widget.items.isEmpty) return 0.0;
    try {
      return widget.items.fold<double>(
        0.0,
        (sum, i) {
          // Safely get price, handling potential nulls
          final itemPrice = i.price;
          final originalPrice = i.originalPrice;
          final price = (originalPrice ?? itemPrice);
          
          if (price == null || price.isNaN || price.isInfinite) {
            return sum;
          }
          final qty = i.quantity;
          final itemTotal = price * qty;
          if (itemTotal.isNaN || itemTotal.isInfinite) return sum;
          return sum + itemTotal;
        },
      );
    } catch (e) {
      debugPrint('Error calculating original total: $e');
      return 0.0;
    }
  }
  
  double get _savings => (_originalTotal - _total).clamp(0.0, double.infinity);

  @override
  void dispose() {
    _upiController.dispose();
    _cardNumberController.dispose();
    _cardNameController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _buyerLocationController.dispose();
    super.dispose();
  }

  // Helper for local fallback lookup without importing collection extensions.
  Order? _firstLocalOrderById(String orderId) {
    final box = Hive.box<Order>('ordersBox');
    for (final o in box.values) {
      if (o.orderId == orderId) return o;
    }
    return null;
  }

  Future<void> _pay() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to continue')),
      );
      return;
    }

    if (widget.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty')),
      );
      return;
    }

    if (_selectedPaymentMethod == 'UPI' && _upiController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter UPI ID')),
      );
      return;
    }
    if (_selectedPaymentMethod == 'Card') {
      if (_cardNumberController.text.trim().isEmpty ||
          _cardNameController.text.trim().isEmpty ||
          _cardExpiryController.text.trim().isEmpty ||
          _cardCvvController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all card details')),
        );
        return;
      }
    }

    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(seconds: 2)); // mock payment processing

    try {
      // Validate and update listing quantities
      final listingBox = Hive.box<Listing>('listingBox');
      Listing? firstListing;
      bool isLiveKitchenOrder = false;
      
      for (final item in widget.items) {
        final listingKey = int.tryParse(item.listingId);
        if (listingKey == null) {
          throw 'Invalid listing id: ${item.listingId}';
        }
        final listing = listingBox.get(listingKey);
        if (listing == null) {
          throw 'Listing not found for ${item.name}';
        }
        
        // Check if this is a Live Kitchen order (only first item needs to be checked for single orders)
        if (firstListing == null) {
          firstListing = listing;
          isLiveKitchenOrder = listing.isLiveKitchen;
        }
        
        if (isLiveKitchenOrder) {
          // For Live Kitchen, validate capacity
          if (!listing.isKitchenOpen) {
            throw 'Kitchen is currently closed for ${listing.name}';
          }
          if (!listing.hasAvailableCapacity) {
            throw 'No available order slots for ${listing.name}';
          }
        } else {
          // For regular orders, validate quantity
          if (listing.quantity < item.quantity) {
            throw 'Only ${listing.quantity} left for ${listing.name}';
          }
        }
      }
      
      // Update listings
      for (final item in widget.items) {
        final listingKey = int.tryParse(item.listingId)!;
        final listing = listingBox.get(listingKey)!;
        
        if (isLiveKitchenOrder) {
          // For Live Kitchen, increment currentOrders (capacity tracking)
          if (listing.addLiveKitchenOrder()) {
            await listing.save();
          } else {
            throw 'Failed to reserve order slot for ${listing.name}';
          }
        } else {
          // For regular orders, decrease quantity
          listing.quantity -= item.quantity;
          await listing.save();
        }
      }

      // Create combined order (mock)
      final sellerId = widget.items.first.sellerId;
      final sellerName = widget.items.first.sellerName;
      final now = DateTime.now();
      
      // Build item summary with pack size info
      String itemSummary;
      if (widget.items.length == 1) {
        final item = widget.items.first;
        if (item.selectedPackSize != null && item.measurementUnitLabel != null) {
          final packLabel = item.selectedPackSize!.getDisplayLabel(item.measurementUnitLabel!);
          itemSummary = '${item.name} (${packLabel}) × ${item.quantity} pack${item.quantity > 1 ? 's' : ''}';
        } else {
          itemSummary = '${item.name} × ${item.quantity}';
        }
      } else {
        final firstItem = widget.items.first;
        if (firstItem.selectedPackSize != null && firstItem.measurementUnitLabel != null) {
          final packLabel = firstItem.selectedPackSize!.getDisplayLabel(firstItem.measurementUnitLabel!);
          itemSummary = '${firstItem.name} (${packLabel}) + ${widget.items.length - 1} more';
        } else {
          itemSummary = '${firstItem.name} + ${widget.items.length - 1} more';
        }
      }
      
      final totalQty = widget.items.fold<int>(0, (sum, i) => sum + i.quantity);

      final ordersBox = Hive.box<Order>('ordersBox');
      // Get pack size info from first item (for single item orders)
      final firstItem = widget.items.first;
      
      // Build pack label if available
      String? packLabel;
      if (firstItem.selectedPackSize != null && firstItem.measurementUnitLabel != null) {
        packLabel = firstItem.selectedPackSize!.getDisplayLabel(firstItem.measurementUnitLabel!);
      } else if (firstItem.selectedPackSize?.label != null) {
        packLabel = firstItem.selectedPackSize!.label;
      }
      
      // Determine order status based on order type
      // IMPORTANT: Only mark as Live Kitchen if the listing is actually Live Kitchen
      final orderStatus = isLiveKitchenOrder 
          ? 'OrderReceived'  // Live Kitchen orders start as "Order Received"
          : 'AwaitingSellerConfirmation';  // Regular orders await seller confirmation
      
      // Debug: Log order creation details
      debugPrint('[CartPayment] Creating order with status: $orderStatus');
      debugPrint('[CartPayment] isLiveKitchenOrder: $isLiveKitchenOrder');
      debugPrint('[CartPayment] Listing type: ${firstListing?.type}');
      debugPrint('[CartPayment] Listing isLiveKitchen: ${firstListing?.isLiveKitchen}');
      
      // Ensure all price values are valid doubles (not null)
      final finalTotal = _total.isNaN || _total.isInfinite ? 0.0 : _total;
      final finalOriginalTotal = _originalTotal.isNaN || _originalTotal.isInfinite ? finalTotal : _originalTotal;
      final finalSavings = _savings.isNaN || _savings.isInfinite ? 0.0 : _savings;
      
      final order = Order(
        foodName: itemSummary,
        sellerName: sellerName,
        pricePaid: finalTotal,
        savedAmount: finalSavings,
        purchasedAt: now,
        listingId: widget.items.first.listingId,
        quantity: totalQty, // This is the total number of packs/items
        originalPrice: finalOriginalTotal,
        discountedPrice: finalTotal,
        userId: currentUser.uid,
        sellerId: sellerId,
        orderStatus: orderStatus,
        paymentCompletedAt: now,
        paymentMethod: _selectedPaymentMethod,
        selectedPackQuantity: firstItem.selectedPackSize?.quantity,
        selectedPackPrice: firstItem.selectedPackSize?.price,
        selectedPackLabel: packLabel,
        isLiveKitchenOrder: isLiveKitchenOrder,
        preparationTimeMinutes: isLiveKitchenOrder && firstListing != null 
            ? firstListing.preparationTimeMinutes 
            : null,
        statusChangedAt: now,
        selectedSize: firstItem.selectedSize,
        selectedColor: firstItem.selectedColor,
      );
      await ordersBox.add(order);

      // Clear cart immediately and show confirmation popup right away (don't block on Firestore).
      CartService.clear();
      if (mounted) {
        setState(() => _isProcessing = false);
        // Hide any previous buyer "Order Accepted" banner so it doesn't overlap this new payment flow.
        AcceptedOrderNotificationService.reset();
        _showWaitingPopup(order.orderId);
      }

      // Best-effort Firestore sync (so seller response updates buyer across devices)
      unawaited(() async {
        try {
          await OrderFirestoreService.upsertOrder(order);
          // Store buyer/seller contact & location for privacy-gated display later.
          final user = await UserService().getUser(currentUser.uid);
          final sellerProfile = await SellerProfileService.getProfile(sellerId);
          await OrderFirestoreService.updateMeta(order.orderId, {
            'buyerName': user?.fullName ?? '',
            'buyerPhone': user?.phoneNumber ?? '',
            'sellerPhone': sellerProfile?.phoneNumber ?? '',
            'sellerPickupLocation': sellerProfile?.pickupLocation ?? '',
          });
        } catch (e) {
          // Keep UI responsive even if Firestore is unavailable on web.
          // Seller response will only sync cross-device once this succeeds.
          // ignore: avoid_print
          print('Firestore upsert failed: $e');
        }
      }());
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e')),
        );
      }
    }
  }

  void _showWaitingPopup(String orderId) {
    showDialog(
      barrierDismissible: true, // Allow dismissing by tapping outside
      context: context,
      builder: (ctx) {
        // Listen to BOTH:
        // - Hive ordersBox: immediate updates in the same browser/app session
        // - Firestore: cross-device/sessions
        return StreamBuilder<OrderStatusMessage>(
          stream: WebOrderBroadcast.stream,
          builder: (context, broadcastSnap) {
            final broadcastStatus = (broadcastSnap.data?.orderId == orderId)
                ? broadcastSnap.data?.status
                : null;

            return ValueListenableBuilder(
              valueListenable: Hive.box<Order>('ordersBox').listenable(),
              builder: (context, Box<Order> _, __) {
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: OrderFirestoreService.doc(orderId).snapshots(),
                  builder: (context, snap) {
                    final localOrder = _firstLocalOrderById(orderId);

                    final data = (snap.data?.exists ?? false) ? snap.data!.data() : null;
                    final firestoreStatus = data?['orderStatus'] as String?;
                    final localStatus = localOrder?.orderStatus;
                    final status =
                        broadcastStatus ?? firestoreStatus ?? localStatus ?? 'AwaitingSellerConfirmation';
                    final itemsText = (data?['foodName'] as String?) ?? localOrder?.foodName ?? '';
                    final totalPaid =
                        (data?['pricePaid'] as num?)?.toDouble() ?? localOrder?.pricePaid ?? 0;

                    final accepted = status == 'AcceptedBySeller' || status == 'Confirmed';
                    final rejected = status == 'RejectedBySeller' || status == 'Cancelled';
                    final isFinal = accepted || rejected;

                    return Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Success Icon
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: AppTheme.successGradient,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Title
                            Text(
                              'Payment Successful',
                              style: AppTheme.heading2.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkText,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Status Message
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.warningColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.warningColor.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                !isFinal
                                    ? 'Awaiting seller confirmation'
                                    : accepted
                                        ? 'Order accepted ✅'
                                        : rejected
                                            ? 'Order rejected ❌'
                                            : 'Processing...',
                                style: AppTheme.bodyMedium.copyWith(
                                  fontSize: 14,
                                  color: AppTheme.darkText,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Order Details
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundColorAlt,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  _buildDetailRow('Order ID', orderId.substring(orderId.length - 8)),
                                  const SizedBox(height: 12),
                                  _buildDetailRow('Items', itemsText),
                                  const SizedBox(height: 12),
                                  _buildDetailRow('Total', '₹${totalPaid.toStringAsFixed(0)}'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Close Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  Navigator.of(context).pop(); // close payment screen
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Close',
                                  style: AppTheme.heading3.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Listing? _getListing(String listingId) {
    try {
      final listingBox = Hive.box<Listing>('listingBox');
      final listingKey = int.tryParse(listingId);
      if (listingKey != null) {
        return listingBox.get(listingKey);
      }
    } catch (e) {
      // Listing might not exist
    }
    return null;
  }

  bool _shouldHideSellerName() {
    if (widget.items.isEmpty) return false;
    final firstItem = widget.items.first;
    final listing = _getListing(firstItem.listingId);
    return listing != null && listing.shouldHideSellerIdentity;
  }

  @override
  Widget build(BuildContext context) {
    final sellerName = widget.items.isNotEmpty ? widget.items.first.sellerName : 'Seller';
    final shouldHideSeller = _shouldHideSellerName();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(sellerName, shouldHideSeller: shouldHideSeller),
            const SizedBox(height: 16),
            _buildPaymentMethodSelector(),
            const SizedBox(height: 16),
            if (_selectedPaymentMethod == 'UPI') _buildUPIForm(),
            if (_selectedPaymentMethod == 'Card') _buildCardForm(),
            if (_selectedPaymentMethod == 'Cash') _buildCashInfo(),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _pay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Pay ₹${_total.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            fontSize: 13,
            color: AppTheme.lightText,
          ),
        ),
        Text(
          value,
          style: AppTheme.bodyMedium.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkText,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String sellerName, {bool shouldHideSeller = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hide seller name for groceries and vegetables
          if (!shouldHideSeller)
            Text('Seller: ${sellerName.isEmpty ? 'Seller' : sellerName}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          if (!shouldHideSeller) const SizedBox(height: 10),
          ...widget.items.map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                  Expanded(
                    child: Text(
                      i.selectedPackSize != null && i.measurementUnitLabel != null
                          ? '${i.name} (${i.selectedPackSize!.getDisplayLabel(i.measurementUnitLabel!)})'
                          : i.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                    Text('₹${i.total.toStringAsFixed(0)}'),
                  ],
                ),
              )),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
              Text('₹${_total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          if (_savings > 0) ...[
            const SizedBox(height: 4),
            Text(
              'You save ₹${_savings.toStringAsFixed(0)}',
              style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('UPI'),
                selected: _selectedPaymentMethod == 'UPI',
                onSelected: (_) => setState(() => _selectedPaymentMethod = 'UPI'),
              ),
              ChoiceChip(
                label: const Text('Card'),
                selected: _selectedPaymentMethod == 'Card',
                onSelected: (_) => setState(() => _selectedPaymentMethod = 'Card'),
              ),
              ChoiceChip(
                label: const Text('Cash'),
                selected: _selectedPaymentMethod == 'Cash',
                onSelected: (_) => setState(() => _selectedPaymentMethod = 'Cash'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUPIForm() {
    return TextField(
      controller: _upiController,
      decoration: const InputDecoration(
        labelText: 'UPI ID',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildCardForm() {
    return Column(
      children: [
        TextField(
          controller: _cardNumberController,
          decoration: const InputDecoration(labelText: 'Card Number', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _cardNameController,
          decoration: const InputDecoration(labelText: 'Name on Card', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _cardExpiryController,
                decoration: const InputDecoration(labelText: 'MM/YY', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _cardCvvController,
                decoration: const InputDecoration(labelText: 'CVV', border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCashInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: const Text('Mock Cash payment selected (for demo).'),
    );
  }
}


