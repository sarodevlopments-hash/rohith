import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/cart_service.dart';
import '../models/listing.dart';
import 'cart_payment_screen.dart';
import '../theme/app_theme.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  static void _navigateToHome(BuildContext context) {
    // Pop until we reach the main tab screen (home)
    // This will take us back to the MainTabScreen which shows the home tab
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.cardColor,
        title: Text(
          'Your Cart',
          style: AppTheme.heading3.copyWith(color: AppTheme.darkText),
        ),
        iconTheme: const IconThemeData(color: AppTheme.darkText),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.darkText),
          onPressed: () => _navigateToHome(context),
        ),
      ),
      body: const CartScreenContent(),
    );
  }
}

class CartScreenContent extends StatefulWidget {
  const CartScreenContent({super.key});

  @override
  State<CartScreenContent> createState() => _CartScreenContentState();
}

class _CartScreenContentState extends State<CartScreenContent> {
  bool _isLoading = false;

  List<CartItemData> get _items => CartService.items();
  double get _subtotal => CartService.total();
  double get _total => _subtotal; // Can add fees/taxes here later
  double get _savings {
    return _items.fold<double>(0, (sum, item) {
      if (item.originalPrice != null) {
        return sum + ((item.originalPrice! - item.price) * item.quantity);
      }
      return sum;
    });
  }

  int get _totalItemCount => _items.fold<int>(0, (sum, item) => sum + item.quantity);
  String? get _sellerName {
    if (_items.isEmpty) return null;
    // Check if seller should be hidden for the first item (all items in cart are from same seller)
    final firstItem = _items.first;
    final listing = _getListing(firstItem.listingId);
    if (listing != null && listing.shouldHideSellerIdentity) {
      return null; // Hide seller name for groceries/vegetables
    }
    return firstItem.sellerName;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _checkout() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to checkout'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CartPaymentScreen(items: List<CartItemData>.from(_items)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeItem(BuildContext context, CartItemData item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Item'),
        content: Text('Remove "${item.name}" from cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await CartService.removeItem(item.listingId);
    }
  }

  Future<void> _updateQuantity(CartItemData item, int newQuantity) async {
    if (newQuantity <= 0) {
      await _removeItem(context, item);
      return;
    }

    // Check stock availability
    final listingBox = Hive.box<Listing>('listingBox');
    final listingKey = int.tryParse(item.listingId);
    if (listingKey != null) {
      final listing = listingBox.get(listingKey);
      if (listing != null) {
        // For Live Kitchen, check capacity
        if (listing.isLiveKitchen) {
          final availableCapacity = (listing.maxCapacity ?? 0) - listing.currentOrders;
          if (newQuantity > availableCapacity) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Only $availableCapacity order${availableCapacity != 1 ? 's' : ''} available'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }
        } else {
          // For regular items, check quantity
          if (newQuantity > listing.quantity) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Only ${listing.quantity} item${listing.quantity != 1 ? 's' : ''} available'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }
        }
      }
    }

    await CartService.updateQuantity(item.listingId, newQuantity);
  }

  Listing? _getListing(String listingId) {
    final listingBox = Hive.box<Listing>('listingBox');
    final listingKey = int.tryParse(listingId);
    if (listingKey != null) {
      return listingBox.get(listingKey);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('cartBox').listenable(),
      builder: (context, Box box, _) {
        final items = _items;

        if (items.isEmpty) {
          return _buildEmptyCart();
        }

        return Column(
          children: [
            // Cart Header
            _buildCartHeader(),

            // Cart Items List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildCartItemCard(item),
                  );
                },
              ),
            ),

            // Price Summary (Sticky Bottom)
            _buildPriceSummary(),
          ],
        );
      },
    );
  }

  Widget _buildCartHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      color: AppTheme.cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_totalItemCount ${_totalItemCount == 1 ? 'item' : 'items'}${_sellerName != null ? ' from $_sellerName' : ''}',
            style: AppTheme.bodyMedium.copyWith(
              fontSize: 14,
              color: AppTheme.lightText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(CartItemData item) {
    final listing = _getListing(item.listingId);
    final isLowStock = listing != null && listing.quantity <= 5 && listing.quantity > 0;
    final isOutOfStock = listing != null && listing.quantity == 0;
    final maxQuantity = listing?.quantity ?? item.quantity;

    return Container(
      decoration: AppTheme.getCardDecoration(elevated: true),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 80,
                height: 80,
                color: AppTheme.backgroundColorAlt,
                child: item.imagePath != null
                    ? (kIsWeb
                        ? FutureBuilder<Uint8List>(
                            future: _loadImageBytes(item.imagePath!),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                );
                              }
                              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                            },
                          )
                        : File(item.imagePath!).existsSync()
                            ? Image.file(
                                File(item.imagePath!),
                                fit: BoxFit.cover,
                              )
                            : Icon(Icons.image_not_supported_rounded, color: AppTheme.disabledText))
                    : Icon(Icons.image_not_supported_rounded, color: AppTheme.disabledText),
              ),
            ),
            const SizedBox(width: 12),

            // Item Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name
                  Text(
                    item.name,
                    style: AppTheme.heading3.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Variant/Pack Size
                  if (item.selectedPackSize != null && item.measurementUnitLabel != null)
                    Text(
                      item.selectedPackSize!.getDisplayLabel(item.measurementUnitLabel!),
                      style: AppTheme.bodySmall.copyWith(
                        fontSize: 13,
                        color: AppTheme.lightText,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else if (item.measurementUnitLabel != null)
                    Text(
                      'Per ${item.measurementUnitLabel}',
                      style: AppTheme.bodySmall.copyWith(
                        fontSize: 13,
                        color: AppTheme.lightText,
                      ),
                    ),

                  const SizedBox(height: 6),

                  // Price per unit
                  Row(
                    children: [
                      Text(
                        '₹${item.price.toStringAsFixed(0)}',
                        style: AppTheme.heading3.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText,
                        ),
                      ),
                      if (item.originalPrice != null && item.originalPrice! > item.price) ...[
                        const SizedBox(width: 8),
                        Text(
                          '₹${item.originalPrice!.toStringAsFixed(0)}',
                          style: AppTheme.bodySmall.copyWith(
                            fontSize: 13,
                            color: AppTheme.disabledText,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: AppTheme.successGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${(((item.originalPrice! - item.price) / item.originalPrice!) * 100).toStringAsFixed(0)}% off',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Stock Warning
                  if (isLowStock && !isOutOfStock)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.warningColor),
                          const SizedBox(width: 4),
                          Text(
                            'Only $maxQuantity left',
                            style: AppTheme.bodySmall.copyWith(
                              fontSize: 11,
                              color: AppTheme.warningColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (isOutOfStock)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, size: 14, color: AppTheme.errorColor),
                          const SizedBox(width: 4),
                          Text(
                            'Out of stock',
                            style: AppTheme.bodySmall.copyWith(
                              fontSize: 11,
                              color: AppTheme.errorColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Quantity Control & Subtotal Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Quantity Control
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.borderColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: item.quantity > 1
                                    ? () => _updateQuantity(item, item.quantity - 1)
                                    : null,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  bottomLeft: Radius.circular(12),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.remove_rounded,
                                    size: 18,
                                    color: item.quantity > 1 ? AppTheme.darkText : AppTheme.disabledText,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                '${item.quantity}',
                                style: AppTheme.heading3.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkText,
                                ),
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: item.quantity < maxQuantity
                                    ? () => _updateQuantity(item, item.quantity + 1)
                                    : null,
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.add_rounded,
                                    size: 18,
                                    color: item.quantity < maxQuantity ? AppTheme.darkText : AppTheme.disabledText,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Subtotal
                      Text(
                        '₹${item.total.toStringAsFixed(0)}',
                        style: AppTheme.heading2.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Remove Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _removeItem(context, item),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: AppTheme.errorColor,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSummary() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Savings Info
              if (_savings > 0)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: AppTheme.successGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_offer_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You saved ₹${_savings.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Price Breakdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Item Total',
                    style: AppTheme.bodyMedium.copyWith(
                      fontSize: 15,
                      color: AppTheme.lightText,
                    ),
                  ),
                  Text(
                    '₹${_subtotal.toStringAsFixed(0)}',
                    style: AppTheme.bodyMedium.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.lightText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: AppTheme.borderColor.withOpacity(0.5)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Grand Total',
                    style: AppTheme.heading2.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                  ),
                  Text(
                    '₹${_total.toStringAsFixed(0)}',
                    style: AppTheme.heading2.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Checkout Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading || _items.isEmpty ? null : _checkout,
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
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Proceed to Checkout',
                          style: AppTheme.heading3.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(
                height: kBottomNavigationBarHeight + 72,
              ), // Reserve space equivalent to bottom nav so seller notification sits at same height as Home
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildEmptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColorAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 80,
                color: AppTheme.disabledText,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your cart is empty',
              style: AppTheme.heading2.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add items to start your order',
              style: AppTheme.bodyMedium.copyWith(
                fontSize: 16,
                color: AppTheme.lightText,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => CartScreen._navigateToHome(context),
              icon: const Icon(Icons.store_rounded),
              label: const Text('Browse Items'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Uint8List> _loadImageBytes(String imagePath) async {
    if (kIsWeb) {
      final XFile file = XFile(imagePath);
      return await file.readAsBytes();
    } else {
      final File file = File(imagePath);
      return await file.readAsBytes();
    }
  }
}
