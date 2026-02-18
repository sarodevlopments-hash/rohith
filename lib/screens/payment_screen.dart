import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import '../models/listing.dart';
import '../models/order.dart';
import '../models/pack_size.dart';
import '../screens/main_tab_screen.dart';
import '../services/image_storage_service.dart';
import '../services/order_firestore_service.dart';
import '../services/user_service.dart';
import '../services/seller_profile_service.dart';
import '../theme/app_theme.dart';

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
      
      // Ensure all price values are valid doubles (not null)
      final totalPrice = (widget.totalPrice.isNaN || widget.totalPrice.isInfinite || widget.totalPrice < 0) 
          ? 0.0 
          : widget.totalPrice;
      final savedAmount = (widget.savedAmount.isNaN || widget.savedAmount.isInfinite || widget.savedAmount < 0) 
          ? 0.0 
          : widget.savedAmount;
      
      // Safely get listing prices with null checks
      final listingPrice = widget.listing.price;
      final listingOriginalPrice = widget.listing.originalPrice;
      final originalPrice = (listingOriginalPrice ?? listingPrice);
      final discountedPrice = listingPrice;
      
      // Validate all values are valid numbers
      if (totalPrice.isNaN || totalPrice.isInfinite || 
          savedAmount.isNaN || savedAmount.isInfinite ||
          originalPrice.isNaN || originalPrice.isInfinite ||
          discountedPrice.isNaN || discountedPrice.isInfinite) {
        throw Exception('Invalid price values detected. Please try again.');
      }
      
      // Create order
      final order = Order(
        foodName: widget.listing.name,
        sellerName: widget.listing.sellerName,
        pricePaid: totalPrice,
        savedAmount: savedAmount,
        purchasedAt: DateTime.now(),
        listingId: widget.listing.key.toString(),
        quantity: widget.quantity,
        originalPrice: originalPrice,
        discountedPrice: discountedPrice,
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
        
        // Delete images from S3 if out of stock
        if (widget.listing.quantity <= 0) {
          await ImageStorageService.deleteImagesIfOutOfStock(widget.listing);
        }
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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Payment',
          style: AppTheme.heading3.copyWith(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
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
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ).copyWith(
                  backgroundColor: MaterialStateProperty.resolveWith<Color>(
                    (Set<MaterialState> states) {
                      if (states.contains(MaterialState.disabled)) {
                        return AppTheme.disabledText;
                      }
                      return AppTheme.primaryColor;
                    },
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
                        style: AppTheme.heading3.copyWith(
                          fontSize: 18,
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
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.getCardDecoration(elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: AppTheme.heading2.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.listing.name,
                  style: AppTheme.heading3.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkText,
                  ),
                ),
              ),
              Text(
                '× ${widget.quantity}',
                style: AppTheme.bodyMedium.copyWith(
                  fontSize: 14,
                  color: AppTheme.lightText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (widget.savedAmount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Original Price',
                  style: AppTheme.bodyMedium.copyWith(
                    fontSize: 14,
                    color: AppTheme.lightText,
                  ),
                ),
                Text(
                  '₹${widget.originalTotal.toStringAsFixed(0)}',
                  style: AppTheme.bodyMedium.copyWith(
                    fontSize: 14,
                    decoration: TextDecoration.lineThrough,
                    color: AppTheme.disabledText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'You Save',
                  style: AppTheme.bodyMedium.copyWith(
                    fontSize: 14,
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppTheme.successGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '₹${widget.savedAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Divider(height: 1, color: AppTheme.borderColor.withOpacity(0.5)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: AppTheme.heading2.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                ),
              ),
              Text(
                '₹${widget.totalPrice.toStringAsFixed(0)}',
                style: AppTheme.heading2.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
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
        Text(
          'Select Payment Method',
          style: AppTheme.heading2.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkText,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildPaymentOption('UPI', Icons.account_balance_wallet_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _buildPaymentOption('Card', Icons.credit_card_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _buildPaymentOption('Cash', Icons.money_rounded)),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentOption(String method, IconData icon) {
    final isSelected = _selectedPaymentMethod == method;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedPaymentMethod = method),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withOpacity(0.12)
                : AppTheme.cardColor,
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.borderColor,
              width: isSelected ? 2 : 1.5,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withOpacity(0.15)
                      : AppTheme.backgroundColorAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.disabledText,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                method,
                style: AppTheme.bodyMedium.copyWith(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.lightText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUPIForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.getCardDecoration(elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter UPI ID',
            style: AppTheme.heading3.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _upiController,
            decoration: AppTheme.getInputDecoration(
              label: 'UPI ID',
              hint: 'yourname@upi',
              prefixIcon: Icons.account_balance_wallet_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.getCardDecoration(elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Card Details',
            style: AppTheme.heading3.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cardNumberController,
            decoration: AppTheme.getInputDecoration(
              label: 'Card Number',
              hint: '1234 5678 9012 3456',
              prefixIcon: Icons.credit_card_rounded,
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cardNameController,
            decoration: AppTheme.getInputDecoration(
              label: 'Cardholder Name',
              hint: 'John Doe',
              prefixIcon: Icons.person_rounded,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cardExpiryController,
                  decoration: AppTheme.getInputDecoration(
                    label: 'Expiry',
                    hint: 'MM/YY',
                    prefixIcon: Icons.calendar_today_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _cardCvvController,
                  decoration: AppTheme.getInputDecoration(
                    label: 'CVV',
                    hint: '123',
                    prefixIcon: Icons.lock_rounded,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.infoColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.infoColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.infoColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.info_outline_rounded,
              color: AppTheme.infoColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pay in cash when you receive your order',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.darkText,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


