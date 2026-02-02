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
import '../models/sell_type.dart';
import '../models/rating.dart';
import '../screens/product_details_screen.dart';
import '../theme/app_theme.dart';

class BuyerListingCard extends StatefulWidget {
  final Listing listing;

  const BuyerListingCard({super.key, required this.listing});

  @override
  State<BuyerListingCard> createState() => _BuyerListingCardState();
}

class _BuyerListingCardState extends State<BuyerListingCard> {
  double? averageFoodRating;

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
      
      setState(() {
        averageFoodRating = foodRatings.reduce((a, b) => a + b) / foodRatings.length;
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

  Future<Uint8List> _loadImageBytes(String imagePath) async {
    if (kIsWeb) {
      final XFile file = XFile(imagePath);
      return await file.readAsBytes();
    } else {
      final File file = File(imagePath);
      return await file.readAsBytes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAvailable = widget.listing.isLiveKitchen 
        ? widget.listing.isLiveKitchenAvailable 
        : widget.listing.quantity > 0;
    final currentPrice = widget.listing.price;
    final imagePath = widget.listing.imagePath;
    final discount = _calculateDiscount();

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(listing: widget.listing),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: AppTheme.getCardDecoration(elevated: true),
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
                  child: imagePath != null
                      ? (kIsWeb
                          ? FutureBuilder<Uint8List>(
                              future: _loadImageBytes(imagePath),
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
                          : File(imagePath).existsSync()
                              ? Image.file(
                                  File(imagePath),
                                  fit: BoxFit.cover,
                                )
                              : const Center(
                                  child: Icon(Icons.image_not_supported, size: 64),
                                ))
                      : const Center(
                          child: Icon(Icons.fastfood, size: 64, color: Colors.grey),
                        ),
                ),
                // Food Type Indicator (Top Left) - Only for food items, not clothing
                if (widget.listing.type != SellType.clothingAndApparel)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: AppTheme.getBadgeDecoration(_getFoodTypeColor()),
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
                      decoration: AppTheme.getBadgeDecoration(AppTheme.errorColor),
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

          // Product Details - Minimal Info Only
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Name
                Text(
                  widget.listing.name,
                  style: AppTheme.heading4,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Price Section
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (widget.listing.originalPrice != null) ...[
                      Text(
                        '₹${widget.listing.originalPrice!.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.lightText,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: AppTheme.getPriceBadgeDecoration(),
                      child: Text(
                        '₹${currentPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),

                // Discount Badge (if any)
                if (widget.listing.originalPrice != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Save ₹${(widget.listing.originalPrice! - widget.listing.price).toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.errorColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                // Stock Availability (Optional)
                if (!isAvailable) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Out of Stock',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else if (widget.listing.quantity <= 5) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Only ${widget.listing.quantity} left',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.warningColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
