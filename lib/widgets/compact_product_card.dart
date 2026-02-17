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
import '../services/distance_filter_service.dart';
import '../services/product_review_service.dart';

class CompactProductCard extends StatefulWidget {
  final Listing listing;
  final String? badgeText; // e.g., "Popular", "Best Seller"
  final ListingWithDistance? listingWithDistance; // Optional distance info

  const CompactProductCard({
    super.key,
    required this.listing,
    this.badgeText,
    this.listingWithDistance,
  });

  @override
  State<CompactProductCard> createState() => _CompactProductCardState();
}

class _CompactProductCardState extends State<CompactProductCard> {
  double? _sellerRating;
  int _sellerReviewCount = 0;
  bool _isLoadingSellerRating = false;
  double? _productRating;
  int _productReviewCount = 0;
  bool _isLoadingProductRating = false;

  @override
  void initState() {
    super.initState();
    _loadProductRating();
    _loadSellerRating();
  }

  Future<void> _loadProductRating() async {
    // If listing already has rating, use it
    if (widget.listing.averageRating > 0) {
      if (mounted) {
        setState(() {
          _productRating = widget.listing.averageRating;
          _productReviewCount = widget.listing.reviewCount;
        });
      }
      return;
    }

    // Otherwise, fetch from reviews
    setState(() => _isLoadingProductRating = true);
    try {
      final reviews = await ProductReviewService.getProductReviews(
        productId: widget.listing.key.toString(),
        approvedOnly: true,
      );
      
      if (reviews.isNotEmpty) {
        final approvedReviews = reviews.where((r) => r.isApproved).toList();
        final reviewsToUse = approvedReviews.isNotEmpty ? approvedReviews : reviews;
        final totalRating = reviewsToUse.fold<double>(0.0, (sum, review) => sum + review.rating);
        final averageRating = (totalRating / reviewsToUse.length);
        if (mounted) {
          setState(() {
            _productRating = averageRating;
            _productReviewCount = reviewsToUse.length;
            _isLoadingProductRating = false;
          });
        }
      } else {
        // No reviews yet
        if (mounted) {
          setState(() {
            _productRating = 0.0;
            _productReviewCount = 0;
            _isLoadingProductRating = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProductRating = false);
      }
    }
  }

  Future<void> _loadSellerRating() async {
    // Only load rating for Cooked Food and Live Kitchen
    if (widget.listing.type == SellType.cookedFood || 
        widget.listing.type == SellType.liveKitchen) {
      setState(() => _isLoadingSellerRating = true);
      try {
        // First try to get from profile
        final profile = await SellerProfileService.getProfile(widget.listing.sellerId);
        
        // If profile has rating, use it
        if (profile != null && profile.averageRating > 0) {
          if (mounted) {
            setState(() {
              _sellerRating = profile.averageRating;
              _sellerReviewCount = profile.reviewCount;
              _isLoadingSellerRating = false;
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
                _sellerReviewCount = reviewsToUse.length;
                _isLoadingSellerRating = false;
              });
            }
          } else {
            // No reviews yet
            if (mounted) {
              setState(() {
                _sellerRating = 0.0;
                _sellerReviewCount = 0;
                _isLoadingSellerRating = false;
              });
            }
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoadingSellerRating = false);
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
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Product Name with Product Rating on the right
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.listing.name,
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Product Rating (next to product name)
                      if (_isLoadingProductRating)
                        const SizedBox(
                          height: 11,
                          width: 11,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        )
                      else if (_productRating != null && _productRating! > 0) ...[
                        const SizedBox(width: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              size: 11,
                              color: _getRatingColor(_productRating!),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _productRating!.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 10,
                                color: _getRatingColor(_productRating!),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_productReviewCount > 0) ...[
                              const SizedBox(width: 2),
                              Text(
                                '(${_productReviewCount})',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 3),

                  // Price with Distance on the right
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Price on the left
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
                      // Distance on the right (opposite to price)
                      if (widget.listingWithDistance?.distanceInMeters != null) ...[
                        const Spacer(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 12,
                              color: Colors.blue.shade600,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              widget.listingWithDistance!.formattedDistance,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  
                  // Seller Name & Rating (Only for Cooked Food & Live Kitchen) - Below Price
                  if (shouldShowSeller) ...[
                    const SizedBox(height: 3),
                    // Restaurant/Seller Name with Seller Rating on the right
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            widget.listing.sellerName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Seller Rating (next to seller name)
                        if (_isLoadingSellerRating)
                          const SizedBox(
                            height: 11,
                            width: 11,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          )
                        else if (_sellerRating != null && _sellerRating! > 0) ...[
                          const SizedBox(width: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star,
                                size: 11,
                                color: _getRatingColor(_sellerRating!),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                _sellerRating!.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _getRatingColor(_sellerRating!),
                                ),
                              ),
                              if (_sellerReviewCount > 0) ...[
                                const SizedBox(width: 2),
                                Text(
                                  '(${_sellerReviewCount})',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
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

