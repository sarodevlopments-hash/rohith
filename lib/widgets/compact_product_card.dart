import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/listing.dart';
import '../screens/product_details_screen.dart';
import '../theme/app_theme.dart';
import '../services/image_storage_service.dart';

class CompactProductCard extends StatelessWidget {
  final Listing listing;
  final String? badgeText; // e.g., "Popular", "Best Seller"

  const CompactProductCard({
    super.key,
    required this.listing,
    this.badgeText,
  });

  double _calculateDiscount() {
    if (listing.originalPrice == null) return 0;
    return ((listing.originalPrice! - listing.price) / listing.originalPrice!) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final discount = _calculateDiscount();
    final isAvailable = listing.isLiveKitchen
        ? listing.isLiveKitchenAvailable
        : listing.quantity > 0;
    final imagePath = listing.imagePath;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(listing: listing),
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
                  if (badgeText != null)
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
                          badgeText!,
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
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name
                  Text(
                    listing.name,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: AppTheme.getPriceBadgeDecoration(),
                        child: Text(
                          '₹${listing.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (listing.originalPrice != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '₹${listing.originalPrice!.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

