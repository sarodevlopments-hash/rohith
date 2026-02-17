import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui';
import 'package:hive/hive.dart';
import '../models/listing.dart';
import '../models/food_category.dart';
import '../models/sell_type.dart';
import '../models/rating.dart';
import '../screens/product_details_screen.dart';
import '../theme/app_theme.dart';
import '../services/image_storage_service.dart';
import '../services/distance_filter_service.dart';
import '../services/seller_profile_service.dart';
import '../services/seller_review_service.dart';

class BuyerListingCard extends StatefulWidget {
  final Listing listing;
  final ListingWithDistance? listingWithDistance; // Optional distance info

  const BuyerListingCard({
    super.key, 
    required this.listing,
    this.listingWithDistance,
  });

  @override
  State<BuyerListingCard> createState() => _BuyerListingCardState();
}

class _BuyerListingCardState extends State<BuyerListingCard> {
  double? averageFoodRating;
  double? _sellerRating;
  int _reviewCount = 0;
  bool _isLoadingRating = false;

  @override
  void initState() {
    super.initState();
    _loadRatings();
    _loadSellerRating();
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

  Future<void> _loadSellerRating() async {
    // Only load rating for Cooked Food and Live Kitchen
    if (widget.listing.type == SellType.cookedFood || 
        widget.listing.type == SellType.liveKitchen) {
      setState(() => _isLoadingRating = true);
      try {
        // First try to get from profile
        final profile = await SellerProfileService.getProfile(widget.listing.sellerId);
        
        // If profile has rating, use it
        if (profile != null && profile.averageRating > 0) {
          if (mounted) {
            setState(() {
              _sellerRating = profile.averageRating;
              _reviewCount = profile.reviewCount;
              _isLoadingRating = false;
            });
          }
        } else {
          // If profile doesn't have rating, fetch from reviews
          final reviews = await SellerReviewService.getSellerReviews(
            sellerId: widget.listing.sellerId,
            approvedOnly: true,
          );
          
          if (reviews.isNotEmpty) {
            final totalRating = reviews.fold<double>(0.0, (sum, review) => sum + review.rating);
            final averageRating = (totalRating / reviews.length);
            if (mounted) {
              setState(() {
                _sellerRating = averageRating;
                _reviewCount = reviews.length;
                _isLoadingRating = false;
              });
            }
          } else {
            // No reviews yet
            if (mounted) {
              setState(() {
                _sellerRating = 0.0;
                _reviewCount = 0;
                _isLoadingRating = false;
              });
            }
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoadingRating = false);
        }
      }
    }
  }

  bool _shouldShowSellerInfo() {
    return widget.listing.type == SellType.cookedFood || 
           widget.listing.type == SellType.liveKitchen;
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4.5) return Colors.green;
    if (rating >= 3.5) return Colors.orange;
    return Colors.red;
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
                      ? (ImageStorageService.isStorageUrl(imagePath)
                          // Firebase Storage URL - display directly
                          ? Image.network(
                              imagePath,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(Icons.image_not_supported, size: 64),
                                );
                              },
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
                // Distance Badge (Top Right, above discount if both exist)
                if (widget.listingWithDistance?.distanceInMeters != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
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
                          const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.listingWithDistance!.formattedDistance,
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
                // Discount Badge (Top Right, below distance if both exist)
                if (discount > 0)
                  Positioned(
                    top: widget.listingWithDistance?.distanceInMeters != null ? 50 : 12,
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
                
                // Seller Name & Rating (Only for Cooked Food & Live Kitchen)
                if (_shouldShowSellerInfo()) ...[
                  const SizedBox(height: 4),
                  // Restaurant/Seller Name
                  Text(
                    widget.listing.sellerName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  // Rating
                  if (_isLoadingRating)
                    const SizedBox(
                      height: 13,
                      width: 13,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (_sellerRating != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          size: 13,
                          color: _sellerRating! > 0 
                              ? _getRatingColor(_sellerRating!) 
                              : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _sellerRating! > 0 
                              ? _sellerRating!.toStringAsFixed(1)
                              : '0.0',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _sellerRating! > 0 
                                ? _getRatingColor(_sellerRating!) 
                                : Colors.grey.shade600,
                          ),
                        ),
                        if (_reviewCount > 0) ...[
                          const SizedBox(width: 3),
                          Text(
                            '(${_reviewCount})',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
                
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
