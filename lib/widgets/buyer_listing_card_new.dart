import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'package:hive/hive.dart';
import '../models/listing.dart';
import '../models/food_category.dart';
import '../models/measurement_unit.dart';
import '../models/pack_size.dart';
import '../models/sell_type.dart';
import '../models/rating.dart';
import '../screens/cart_screen.dart';
import '../services/cart_service.dart';

class BuyerListingCard extends StatefulWidget {
  final Listing listing;

  const BuyerListingCard({super.key, required this.listing});

  @override
  State<BuyerListingCard> createState() => _BuyerListingCardState();
}

class _BuyerListingCardState extends State<BuyerListingCard> {
  int selectedQuantity = 1;
  PackSize? selectedPackSize; // Selected pack size for groceries with multiple packs
  double? averageFoodRating;
  double? averageSellerRating;

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    final ratingsBox = Hive.box('ratingsBox');
    final ratings = ratingsBox.values
        .whereType<Rating>()
        .where((r) => r.listingId == widget.listing.key.toString())
        .toList();

    if (ratings.isNotEmpty) {
      final foodRatings = ratings.map((r) => r.foodRating).toList();
      final sellerRatings = ratings.map((r) => r.sellerRating).toList();
      
      setState(() {
        averageFoodRating = foodRatings.reduce((a, b) => a + b) / foodRatings.length;
        averageSellerRating = sellerRatings.reduce((a, b) => a + b) / sellerRatings.length;
      });
    }
  }

  Color _getFoodTypeColor() {
    switch (widget.listing.category) {
      case FoodCategory.veg:
        return Colors.green;
      case FoodCategory.egg:
        return Colors.orange;
      case FoodCategory.nonVeg:
        return Colors.red.shade700; // Darker red for better appearance
    }
  }

  String _getFoodTypeLabel() {
    return widget.listing.category.label;
  }

  double _calculateDiscount() {
    if (widget.listing.originalPrice == null) return 0;
    return ((widget.listing.originalPrice! - widget.listing.price) / 
            widget.listing.originalPrice!) * 100;
  }

  String _getUnitPrice() {
    // If pack sizes exist, show pack-specific price format
    if (widget.listing.hasMultiplePackSizes && widget.listing.packSizes != null && widget.listing.packSizes!.isNotEmpty) {
      if (selectedPackSize != null && widget.listing.measurementUnit != null) {
        final label = selectedPackSize!.getDisplayLabel(widget.listing.measurementUnit!.shortLabel);
        return '₹${selectedPackSize!.price.toStringAsFixed(0)} for $label';
      }
      // If no pack selected but packs exist, show first pack as example or prompt
      final firstPack = widget.listing.packSizes!.first;
      if (widget.listing.measurementUnit != null) {
        final label = firstPack.getDisplayLabel(widget.listing.measurementUnit!.shortLabel);
        return 'Select pack size (e.g., ₹${firstPack.price.toStringAsFixed(0)} for $label)';
      }
    }
    // For groceries/vegetables with measurement unit, show "for" format instead of "per"
    // Use pack size weight if available, otherwise show price for 1 unit
    if (widget.listing.type == SellType.groceries || widget.listing.type == SellType.vegetables) {
      if (widget.listing.measurementUnit != null) {
        // If there's a single pack size (even if not using multiple pack sizes feature)
        if (widget.listing.packSizes != null && widget.listing.packSizes!.isNotEmpty) {
          final packSize = widget.listing.packSizes!.first;
          final label = packSize.getDisplayLabel(widget.listing.measurementUnit!.shortLabel);
          return '₹${packSize.price.toStringAsFixed(0)} for $label';
        }
        // If no pack size, show price for 1 unit of the measurement
        return '₹${widget.listing.price.toStringAsFixed(0)} for 1 ${widget.listing.measurementUnit!.shortLabel}';
      }
    }
    // Regular items without pack sizes
    if (widget.listing.measurementUnit != null) {
      return '₹${widget.listing.price.toStringAsFixed(0)} per ${widget.listing.measurementUnit!.shortLabel}';
    }
    return '₹${widget.listing.price.toStringAsFixed(0)} per item';
  }

  Future<void> _addToCart() async {
    if (selectedQuantity > widget.listing.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Only ${widget.listing.quantity} items available')),
      );
      return;
    }

    final sellerInCart = CartService.currentSellerId();
    if (sellerInCart != null && sellerInCart != widget.listing.sellerId) {
      final clear = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Different seller'),
          content: const Text(
            'Your cart contains items from another seller. Please complete or clear the current cart to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Clear cart'),
            ),
          ],
        ),
      );
      if (clear != true) return;
      CartService.clear();
    }

    await CartService.addItem(widget.listing, selectedQuantity);
    if (mounted) {
      // Don't show notification if already on cart screen
      // Check by looking for CartScreen in the widget tree
      bool isOnCartScreen = false;
      try {
        final cartScreen = context.findAncestorWidgetOfExactType<CartScreen>();
        isOnCartScreen = cartScreen != null;
      } catch (e) {
        // If check fails, assume we're not on cart screen
      }
      
      if (isOnCartScreen) {
        return;
      }

      // Hide any existing snackbar first
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Text('Added to cart'),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.fixed,
          action: SnackBarAction(
            label: 'View Cart',
            onPressed: () {
              scaffoldMessenger.hideCurrentSnackBar();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
          ),
        ),
      );
      
      // Explicitly dismiss after 5 seconds to ensure it doesn't stay longer
      Timer(const Duration(seconds: 5), () {
        if (mounted) {
          scaffoldMessenger.hideCurrentSnackBar();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final discount = _calculateDiscount();
    final isAvailable = widget.listing.quantity > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child: widget.listing.imagePath != null
                      ? (kIsWeb
                          ? FutureBuilder<Uint8List>(
                              future: _loadImageBytes(widget.listing.imagePath!),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                  );
                                }
                                return const Center(child: CircularProgressIndicator());
                              },
                            )
                          : File(widget.listing.imagePath!).existsSync()
                              ? Image.file(
                                  File(widget.listing.imagePath!),
                                  fit: BoxFit.cover,
                                )
                              : const Center(
                                  child: Icon(Icons.image_not_supported, size: 64),
                                ))
                      : const Center(
                          child: Icon(Icons.fastfood, size: 64, color: Colors.grey),
                        ),
                ),
                // Food Type Indicator (Top Left)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getFoodTypeColor(),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.listing.category == FoodCategory.veg
                              ? Icons.eco
                              : widget.listing.category == FoodCategory.egg
                                  ? Icons.egg
                                  : Icons.set_meal, // Better icon for non-veg
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getFoodTypeLabel(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Discount Badge (Top Right)
                if (discount > 0)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${discount.toStringAsFixed(0)}% OFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                // Stock Indicator
                if (!isAvailable)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.black.withOpacity(0.7),
                      child: const Center(
                        child: Text(
                          'SOLD OUT',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Product Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Name & Ratings
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.listing.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          // Show blurred seller name for groceries and vegetables (always hidden in listing view)
                          if (widget.listing.shouldHideSellerIdentity) ...[
                            const SizedBox(height: 4),
                            _buildBlurredSellerName(),
                          ] else ...[
                            const SizedBox(height: 4),
                            Text(
                              'by ${widget.listing.sellerName}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (averageFoodRating != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: Colors.orange, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              averageFoodRating!.toStringAsFixed(1),
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 12),

                // Price Section
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (widget.listing.originalPrice != null) ...[
                      Text(
                        '₹${widget.listing.originalPrice!.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      '₹${widget.listing.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getUnitPrice(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),

                if (widget.listing.originalPrice != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'You save ₹${(widget.listing.originalPrice! - widget.listing.price).toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Stock & Type Info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2, size: 14, color: Colors.blue.shade700),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.listing.quantity} left',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.category, size: 14, color: Colors.purple.shade700),
                          const SizedBox(width: 4),
                          Text(
                            widget.listing.type.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Quantity Selection
                if (isAvailable) ...[
                  Row(
                    children: [
                      const Text(
                        'Quantity:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 20),
                              onPressed: selectedQuantity > 1
                                  ? () {
                                      setState(() {
                                        selectedQuantity--;
                                      });
                                    }
                                  : null,
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text(
                                selectedQuantity.toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 20),
                              onPressed: selectedQuantity < widget.listing.quantity
                                  ? () {
                                      setState(() {
                                        selectedQuantity++;
                                      });
                                    }
                                  : null,
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Buy Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isAvailable ? _addToCart : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAvailable ? Colors.orange : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      isAvailable
                          ? 'Add to Cart (${selectedQuantity}x)'
                          : 'Sold Out',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildBlurredSellerName() {
    // Create a blurred text effect - make seller name unreadable
    return ClipRect(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          child: Text(
            'by ${widget.listing.sellerName}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }
}

