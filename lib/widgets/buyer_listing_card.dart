import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  String _getButtonText(bool isAvailable) {
    if (!isAvailable) {
      if (widget.listing.isLiveKitchen) {
        if (!widget.listing.isKitchenOpen) return 'Kitchen Closed';
        if (!widget.listing.hasAvailableCapacity) return 'Fully Booked';
      }
      return 'Sold Out';
    }
    if (widget.listing.isLiveKitchen) {
      return 'Order Now • ${widget.listing.preparationTimeText}';
    }
    if (widget.listing.isValidBulkFood) {
      return 'Order Bulk Pack (${widget.listing.bulkServingText})';
    }
    if (widget.listing.hasMultiplePackSizes && selectedPackSize != null) {
      return 'Add ${selectedQuantity} Pack${selectedQuantity > 1 ? 's' : ''} to Cart';
    }
    return 'Add to Cart (${selectedQuantity}x)';
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
    // Use pack size weight if available, otherwise don't show pack size in price
    if (widget.listing.type == SellType.groceries || widget.listing.type == SellType.vegetables) {
      if (widget.listing.measurementUnit != null) {
        // If there's a single pack size (even if not using multiple pack sizes feature)
        if (widget.listing.packSizes != null && widget.listing.packSizes!.isNotEmpty) {
          final packSize = widget.listing.packSizes!.first;
          final label = packSize.getDisplayLabel(widget.listing.measurementUnit!.shortLabel);
          return '₹${packSize.price.toStringAsFixed(0)} for $label';
        }
        // Don't show pack size if not available - just show price
        return '₹${widget.listing.price.toStringAsFixed(0)}';
      }
    }
    // Regular items without pack sizes
    if (widget.listing.measurementUnit != null) {
      return '₹${widget.listing.price.toStringAsFixed(0)} per ${widget.listing.measurementUnit!.shortLabel}';
    }
    return '₹${widget.listing.price.toStringAsFixed(0)} per item';
  }

  double _getCurrentPrice() {
    return selectedPackSize?.price ?? widget.listing.price;
  }

  Future<void> _addToCart() async {
    // Validate pack size selection for groceries with multiple packs
    if (widget.listing.hasMultiplePackSizes && selectedPackSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pack size')),
      );
      return;
    }

    // For live kitchen, check if kitchen is open
    if (widget.listing.isLiveKitchen) {
      if (!widget.listing.isKitchenOpen) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kitchen is currently closed. Please try again later.')),
        );
        return;
      }
      if (!widget.listing.hasAvailableCapacity) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No order slots available. Please try again later.')),
        );
        return;
      }
    }

    // For bulk items or live kitchen, always use quantity of 1
    final quantityToAdd = (widget.listing.isValidBulkFood || widget.listing.isLiveKitchen) ? 1 : selectedQuantity;

    if (quantityToAdd > widget.listing.quantity && !widget.listing.isLiveKitchen) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.listing.isValidBulkFood 
            ? 'This bulk pack is not available'
            : 'Only ${widget.listing.quantity} items available')),
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

    await CartService.addItem(widget.listing, quantityToAdd, packSize: selectedPackSize);
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

      String message;
      if (widget.listing.isLiveKitchen) {
        message = 'Order placed! Preparation time: ${widget.listing.preparationTimeText}';
      } else if (widget.listing.isValidBulkFood) {
        message = 'Bulk pack added to cart (${widget.listing.bulkServingText})';
      } else {
        message = 'Added to cart';
      }
      
      // Hide any existing snackbar first
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(message),
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
    // For live kitchen, check kitchen status and capacity
    final isAvailable = widget.listing.isLiveKitchen 
        ? widget.listing.isLiveKitchenAvailable 
        : widget.listing.quantity > 0;
    final currentPrice = _getCurrentPrice();

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
                // Bulk Food Badge (Top Left, below food type)
                if (widget.listing.isValidBulkFood)
                  Positioned(
                    top: 52,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade600,
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
                          const Icon(Icons.groups, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            widget.listing.bulkServingText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Live Kitchen Badge (Top Left, below food type or bulk badge)
                if (widget.listing.isLiveKitchen)
                  Positioned(
                    top: widget.listing.isValidBulkFood ? 92 : 52,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: widget.listing.isKitchenOpen 
                              ? [Colors.green.shade400, Colors.green.shade600]
                              : [Colors.grey.shade400, Colors.grey.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
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
                            widget.listing.isKitchenOpen ? Icons.restaurant : Icons.restaurant_outlined,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.listing.isKitchenOpen 
                                ? '🔥 Live Kitchen' 
                                : 'Kitchen Closed',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
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
                          const SizedBox(height: 4),
                          Text(
                            'by ${widget.listing.sellerName}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
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
                      '₹${currentPrice.toStringAsFixed(0)}',
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
                          Icon(
                            widget.listing.isLiveKitchen ? Icons.people_outline : Icons.inventory_2, 
                            size: 14, 
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.listing.isLiveKitchen
                                ? '${widget.listing.remainingCapacity} slots'
                                : widget.listing.isValidBulkFood 
                                    ? '${widget.listing.quantity} pack${widget.listing.quantity > 1 ? 's' : ''}'
                                    : '${widget.listing.quantity} left',
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
                          Icon(
                            widget.listing.isLiveKitchen ? Icons.restaurant : Icons.category, 
                            size: 14, 
                            color: widget.listing.isLiveKitchen ? Colors.deepOrange.shade700 : Colors.purple.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.listing.type.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.listing.isLiveKitchen ? Colors.deepOrange.shade700 : Colors.purple.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Bulk Food Info
                if (widget.listing.isValidBulkFood) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade50, Colors.purple.shade100],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade600,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.groups, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Bulk Food Item',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    widget.listing.bulkServingText,
                                    style: TextStyle(
                                      color: Colors.purple.shade700,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (widget.listing.portionDescription != null && widget.listing.portionDescription!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.local_dining, size: 14, color: Colors.purple.shade600),
                              const SizedBox(width: 6),
                              Text(
                                widget.listing.portionDescription!,
                                style: TextStyle(
                                  color: Colors.purple.shade800,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline, size: 12, color: Colors.amber.shade800),
                              const SizedBox(width: 4),
                              Text(
                                'Sold as complete pack only',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Live Kitchen Info
                if (widget.listing.isLiveKitchen) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: widget.listing.isKitchenOpen 
                            ? [Colors.green.shade50, Colors.green.shade100]
                            : [Colors.grey.shade100, Colors.grey.shade200],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.listing.isKitchenOpen 
                            ? Colors.green.shade300 
                            : Colors.grey.shade400,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: widget.listing.isKitchenOpen 
                                      ? [Colors.green.shade400, Colors.green.shade600]
                                      : [Colors.grey.shade400, Colors.grey.shade600],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                widget.listing.isKitchenOpen ? Icons.restaurant : Icons.restaurant_outlined,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.listing.isKitchenOpen ? '🔥 Live Kitchen Open' : 'Kitchen Closed',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: widget.listing.isKitchenOpen 
                                          ? Colors.green.shade800 
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                  Text(
                                    widget.listing.isKitchenOpen 
                                        ? 'Cooking fresh on order'
                                        : 'Not accepting orders now',
                                    style: TextStyle(
                                      color: widget.listing.isKitchenOpen 
                                          ? Colors.green.shade700 
                                          : Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (widget.listing.isKitchenOpen) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // Preparation Time
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange.shade200),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.timer, size: 16, color: Colors.orange.shade700),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Prep Time',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.orange.shade600,
                                              ),
                                            ),
                                            Text(
                                              widget.listing.preparationTimeText,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Available Slots
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: widget.listing.hasAvailableCapacity 
                                        ? Colors.blue.shade50 
                                        : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: widget.listing.hasAvailableCapacity 
                                          ? Colors.blue.shade200 
                                          : Colors.red.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.people_outline, 
                                        size: 16, 
                                        color: widget.listing.hasAvailableCapacity 
                                            ? Colors.blue.shade700 
                                            : Colors.red.shade700,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Slots',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: widget.listing.hasAvailableCapacity 
                                                    ? Colors.blue.shade600 
                                                    : Colors.red.shade600,
                                              ),
                                            ),
                                            Text(
                                              widget.listing.hasAvailableCapacity 
                                                  ? '${widget.listing.remainingCapacity} available'
                                                  : 'Fully booked',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: widget.listing.hasAvailableCapacity 
                                                    ? Colors.blue.shade800 
                                                    : Colors.red.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline, size: 12, color: Colors.amber.shade800),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Freshly prepared after you order',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.amber.shade900,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Pack Size Selection (for groceries with multiple packs)
                if (isAvailable && widget.listing.hasMultiplePackSizes && widget.listing.packSizes != null) ...[
                  const Text(
                    'Select Pack Size:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.listing.packSizes!.map((pack) {
                      final isSelected = selectedPackSize?.quantity == pack.quantity &&
                          selectedPackSize?.price == pack.price;
                      final unitLabel = widget.listing.measurementUnit?.shortLabel ?? '';
                      return ChoiceChip(
                        label: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              pack.getDisplayLabel(unitLabel),
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '₹${pack.price.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected ? Colors.white : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            selectedPackSize = selected ? pack : null;
                            // Reset quantity to 1 when pack size changes
                            selectedQuantity = 1;
                          });
                        },
                        selectedColor: Colors.orange,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Quantity Selection (Number of Packs) - Not shown for bulk items or live kitchen (always 1)
                if (isAvailable && !widget.listing.isValidBulkFood && !widget.listing.isLiveKitchen) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Quantity:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
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
                  if (widget.listing.hasMultiplePackSizes && selectedPackSize != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${selectedQuantity} pack${selectedQuantity > 1 ? 's' : ''} of ${selectedPackSize!.getDisplayLabel(widget.listing.measurementUnit?.shortLabel ?? '')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],

                // Buy Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isAvailable ? _addToCart : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAvailable 
                          ? (widget.listing.isLiveKitchen 
                              ? Colors.green.shade600
                              : widget.listing.isValidBulkFood 
                                  ? Colors.purple 
                                  : Colors.orange)
                          : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.listing.isLiveKitchen && isAvailable) ...[
                          const Icon(Icons.restaurant, size: 20),
                          const SizedBox(width: 8),
                        ] else if (widget.listing.isValidBulkFood && isAvailable) ...[
                          const Icon(Icons.groups, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          _getButtonText(isAvailable),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
}

