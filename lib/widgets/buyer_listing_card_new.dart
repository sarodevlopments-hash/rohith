import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive/hive.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/listing.dart';
import '../models/food_category.dart';
import '../models/measurement_unit.dart';
import '../models/sell_type.dart';
import '../models/rating.dart';
import '../screens/product_details_screen.dart';
import '../theme/app_theme.dart';
import '../services/image_storage_service.dart';

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
        return Colors.red.shade700;
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
    // For groceries/vegetables with measurement unit, show "for" format
    if (widget.listing.type == SellType.groceries || widget.listing.type == SellType.vegetables) {
      if (widget.listing.measurementUnit != null) {
        // If there's a pack size, show it
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
                    child: imagePath != null && imagePath.isNotEmpty
                        ? (ImageStorageService.isStorageUrl(imagePath)
                            // Firebase Storage URL - use CachedNetworkImage
                            ? CachedNetworkImage(
                                imageUrl: imagePath,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Center(
                                  child: SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 64),
                                ),
                              )
                            // Local file path - only load on mobile, show placeholder on web
                            : (kIsWeb
                                ? const Center(
                                    child: Icon(Icons.image_not_supported, size: 64),
                                  )
                                : File(imagePath).existsSync()
                                    ? Image.file(
                                        File(imagePath),
                                        fit: BoxFit.cover,
                                      )
                                    : const Center(
                                        child: Icon(Icons.image_not_supported, size: 64),
                                      )))
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
                                      : Icons.set_meal,
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
                  // Live Kitchen Badge (Top Left, below bulk food)
                  if (widget.listing.isLiveKitchen)
                    Positioned(
                      top: widget.listing.isValidBulkFood ? 92 : 52,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade600,
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
                            const Icon(Icons.restaurant, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              widget.listing.isLiveKitchenAvailable ? 'Available Now' : 'Closed',
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
                        decoration: AppTheme.getBadgeDecoration(Colors.red.shade600),
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
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.0),
                              Colors.black.withOpacity(0.7),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
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
                            color: Colors.grey.shade600,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: AppTheme.getPriceBadgeDecoration(),
                        child: Text(
                          '₹${currentPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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

                  // Discount savings text
                  if (widget.listing.originalPrice != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'You save ₹${(widget.listing.originalPrice! - currentPrice).toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],

                  // Stock Availability
                  if (isAvailable && widget.listing.quantity <= 10 && widget.listing.quantity > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Only ${widget.listing.quantity} left',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.warningColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else if (!isAvailable) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Out of Stock',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.errorColor,
                        fontWeight: FontWeight.w600,
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
