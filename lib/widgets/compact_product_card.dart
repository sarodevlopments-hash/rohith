import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/listing.dart';
import '../models/sell_type.dart';
import '../screens/product_details_screen.dart';
import '../theme/app_theme.dart';
import '../services/image_storage_service.dart';
import '../services/seller_profile_service.dart';
import '../services/seller_review_service.dart';

class CompactProductCard extends StatefulWidget {
  final Listing listing;
  final String? badgeText; // e.g., "Popular", "Best Seller"

  const CompactProductCard({
    super.key,
    required this.listing,
    this.badgeText,
  });

  @override
  State<CompactProductCard> createState() => _CompactProductCardState();
}

class _CompactProductCardState extends State<CompactProductCard> {
  double? _sellerRating;
  int _reviewCount = 0;
  bool _isLoadingRating = false;

  @override
  void initState() {
    super.initState();
    _loadSellerRating();
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
            final approvedReviews = reviews.where((r) => r.isApproved).toList();
            final reviewsToUse = approvedReviews.isNotEmpty ? approvedReviews : reviews;
            final totalRating = reviewsToUse.fold<double>(0.0, (sum, review) => sum + review.rating);
            final averageRating = (totalRating / reviewsToUse.length);
            if (mounted) {
              setState(() {
                _sellerRating = averageRating;
                _reviewCount = reviewsToUse.length;
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

  Color _getRatingColor(double rating) {
    if (rating >= 4.5) return Colors.green;
    if (rating >= 3.5) return Colors.orange;
    return Colors.red;
  }

  double _calculateDiscount() {
    if (widget.listing.originalPrice == null) return 0;
    return ((widget.listing.originalPrice! - widget.listing.price) / widget.listing.originalPrice!) * 100;
  }

  bool _shouldShowSellerInfo() {
    return widget.listing.type == SellType.cookedFood || 
           widget.listing.type == SellType.liveKitchen;
  }

  @override
  Widget build(BuildContext context) {
    final discount = _calculateDiscount();
    final isAvailable = widget.listing.isLiveKitchen
        ? widget.listing.isLiveKitchenAvailable
        : widget.listing.quantity > 0;
    final imagePath = widget.listing.imagePath;
    final shouldShowSeller = _shouldShowSellerInfo();

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(listing: widget.listing),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
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
                    height: 140,
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
                                  child: Icon(Icons.image_not_supported, size: 40),
                                );
                              },
                            )
                          // Local file path - only load on mobile, show placeholder on web
                          : (kIsWeb
                              ? const Center(
                                  child: Icon(Icons.image_not_supported, size: 40),
                                )
                              : File(imagePath).existsSync()
                                  ? Image.file(
                                      File(imagePath),
                                      fit: BoxFit.cover,
                                    )
                                  : const Center(
                                      child: Icon(Icons.image_not_supported, size: 40),
                                    )))
                      : const Center(
                          child: Icon(Icons.fastfood, size: 40, color: Colors.grey),
                        ),
                  ),
                  // Badge (Top Left)
                  if (widget.badgeText != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.badgeText!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Discount Badge (Top Right)
                  if (discount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: AppTheme.getBadgeDecoration(Colors.red.shade600),
                        child: Text(
                          '${discount.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
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
                        padding: const EdgeInsets.all(4),
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
                              fontSize: 10,
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
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Product Name
                  Text(
                    widget.listing.name,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 4),

                  // Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: AppTheme.getPriceBadgeDecoration(),
                        child: Text(
                          '₹${widget.listing.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (widget.listing.originalPrice != null) ...[
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            '₹${widget.listing.originalPrice!.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade600,
                              decoration: TextDecoration.lineThrough,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  // Seller Name & Rating (Only for Cooked Food & Live Kitchen) - Below Price
                  if (shouldShowSeller) ...[
                    const SizedBox(height: 4),
                    // Restaurant/Seller Name
                    Text(
                      widget.listing.sellerName,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Rating - Compact display
                    if (_isLoadingRating)
                      const SizedBox(
                        height: 10,
                        width: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    else if (_sellerRating != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            size: 10,
                            color: _sellerRating! > 0 
                                ? _getRatingColor(_sellerRating!) 
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _sellerRating! > 0 
                                ? _sellerRating!.toStringAsFixed(1)
                                : '0.0',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: _sellerRating! > 0 
                                  ? _getRatingColor(_sellerRating!) 
                                  : Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            ' (${_reviewCount})',
                            style: TextStyle(
                              fontSize: 8,
                              color: _reviewCount > 0 
                                  ? Colors.grey.shade600 
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ],
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

