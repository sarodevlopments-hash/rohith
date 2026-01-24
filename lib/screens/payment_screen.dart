import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import '../models/listing.dart';
import '../models/order.dart';
import '../models/pack_size.dart';
import '../screens/main_tab_screen.dart';
import '../services/order_firestore_service.dart';
import '../services/user_service.dart';
import '../services/seller_profile_service.dart';

class PaymentScreen extends StatefulWidget {
  final Listing listing;
  final int quantity;
  final double totalPrice;
  final double originalTotal;
  final double savedAmount;
  final PackSize? selectedPackSize; // Selected pack size for groceries

  const PaymentScreen({
    super.key,
    required this.listing,
    required this.quantity,
    required this.totalPrice,
    required this.originalTotal,
    required this.savedAmount,
    this.selectedPackSize,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedPaymentMethod = 'UPI';
  bool _isProcessing = false;
  final TextEditingController _upiController = TextEditingController();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardNameController = TextEditingController();
  final TextEditingController _cardExpiryController = TextEditingController();
  final TextEditingController _cardCvvController = TextEditingController();
  final TextEditingController _buyerLocationController = TextEditingController();

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

  Future<void> _processPayment() async {
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

    // Simulate payment processing
    await Future.delayed(const Duration(seconds: 2));

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to continue')),
      );
      return;
    }

    try {
      // Check if this is a Live Kitchen order
      final isLiveKitchenOrder = widget.listing.isLiveKitchen;
      
      // Validate Live Kitchen capacity if applicable
      if (isLiveKitchenOrder) {
        if (!widget.listing.isKitchenOpen) {
          setState(() => _isProcessing = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Kitchen is currently closed. Please try again later.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        if (!widget.listing.hasAvailableCapacity) {
          setState(() => _isProcessing = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No order slots available. Please try again later.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }
      
      // Determine order status based on order type
      final orderStatus = isLiveKitchenOrder 
          ? 'OrderReceived'  // Live Kitchen orders start as "Order Received"
          : 'AwaitingSellerConfirmation';  // Regular orders await seller confirmation
      
      // Create order
      final order = Order(
        foodName: widget.listing.name,
        sellerName: widget.listing.sellerName,
        pricePaid: widget.totalPrice,
        savedAmount: widget.savedAmount,
        purchasedAt: DateTime.now(),
        listingId: widget.listing.key.toString(),
        quantity: widget.quantity,
        originalPrice: widget.listing.originalPrice ?? widget.listing.price,
        discountedPrice: widget.listing.price,
        userId: currentUser.uid,
        sellerId: widget.listing.sellerId,
        orderStatus: orderStatus,
        paymentCompletedAt: DateTime.now(),
        paymentMethod: _selectedPaymentMethod,
        selectedPackQuantity: widget.selectedPackSize?.quantity,
        selectedPackPrice: widget.selectedPackSize?.price,
        selectedPackLabel: widget.selectedPackSize?.label,
        isLiveKitchenOrder: isLiveKitchenOrder,
        preparationTimeMinutes: isLiveKitchenOrder ? widget.listing.preparationTimeMinutes : null,
        statusChangedAt: DateTime.now(),
      );

      // Save order
      final box = Hive.box<Order>('ordersBox');
      await box.add(order);

      // Update listing
      if (isLiveKitchenOrder) {
        // For Live Kitchen, increment currentOrders (capacity tracking)
        if (widget.listing.addLiveKitchenOrder()) {
          await widget.listing.save();
        } else {
          throw 'Failed to reserve order slot';
        }
      } else {
        // For regular orders, decrease quantity
        widget.listing.quantity -= widget.quantity;
        await widget.listing.save();
      }

      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful! Order sent to seller.'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to home
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainTabScreen()),
          (route) => false,
        );
      }

      // Best-effort Firestore sync (so seller response updates buyer across devices)
      unawaited(() async {
        try {
          await OrderFirestoreService.upsertOrder(order);
          // Store buyer/seller contact & location for privacy-gated display later.
          final user = await UserService().getUser(currentUser.uid);
          final sellerProfile = await SellerProfileService.getProfile(widget.listing.sellerId);
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
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Summary
            _buildOrderSummary(),
            const SizedBox(height: 24),

            // Payment Method Selection
            _buildPaymentMethodSelector(),
            const SizedBox(height: 24),

            // Payment Details Form
            if (_selectedPaymentMethod == 'UPI') _buildUPIForm(),
            if (_selectedPaymentMethod == 'Card') _buildCardForm(),
            if (_selectedPaymentMethod == 'Cash') _buildCashInfo(),

            const SizedBox(height: 32),

            // Pay Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Pay ₹${widget.totalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.listing.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                '× ${widget.quantity}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.savedAmount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Original Price',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                Text(
                  '₹${widget.originalTotal.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'You Save',
                  style: TextStyle(fontSize: 14, color: Colors.green.shade700),
                ),
                Text(
                  '₹${widget.savedAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₹${widget.totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Payment Method',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildPaymentOption('UPI', Icons.account_balance_wallet),
        const SizedBox(height: 8),
        _buildPaymentOption('Card', Icons.credit_card),
        const SizedBox(height: 8),
        _buildPaymentOption('Cash', Icons.money),
      ],
    );
  }

  Widget _buildPaymentOption(String method, IconData icon) {
    final isSelected = _selectedPaymentMethod == method;
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = method),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.shade50 : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.orange : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.orange : Colors.grey.shade600),
            const SizedBox(width: 12),
            Text(
              method,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.orange : Colors.black87,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildUPIForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter UPI ID',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _upiController,
            decoration: InputDecoration(
              hintText: 'yourname@upi',
              prefixIcon: const Icon(Icons.account_balance_wallet),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Card Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cardNumberController,
            decoration: InputDecoration(
              labelText: 'Card Number',
              hintText: '1234 5678 9012 3456',
              prefixIcon: const Icon(Icons.credit_card),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cardNameController,
            decoration: InputDecoration(
              labelText: 'Cardholder Name',
              hintText: 'John Doe',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cardExpiryController,
                  decoration: InputDecoration(
                    labelText: 'Expiry',
                    hintText: 'MM/YY',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _cardCvvController,
                  decoration: InputDecoration(
                    labelText: 'CVV',
                    hintText: '123',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCashInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pay in cash when you receive your order',
              style: TextStyle(color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }
}

