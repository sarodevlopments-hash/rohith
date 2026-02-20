import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:hive/hive.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/listing.dart';
import '../models/food_category.dart';
import '../models/measurement_unit.dart';
import '../models/pack_size.dart';
import '../models/sell_type.dart';
import '../models/size_color_combination.dart';
import '../models/rating.dart';
import '../screens/cart_screen.dart';
import '../services/cart_service.dart';
import '../services/recently_viewed_service.dart';
import '../services/image_storage_service.dart';
import '../services/notification_service.dart';
import '../services/location_service.dart';
import '../services/seller_profile_service.dart';
import '../utils/distance_utils.dart';
import '../utils/location_parser.dart';
import '../theme/app_theme.dart';
import '../widgets/seller_name_widget.dart';
import '../main.dart' show navigatorKey;

class ProductDetailsScreen extends StatefulWidget {
  final Listing listing;

  const ProductDetailsScreen({super.key, required this.listing});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int selectedQuantity = 1;
  PackSize? selectedPackSize;
  String? selectedSize;
  String? selectedColor;
  double? averageFoodRating;
  double? averageSellerRating;

  @override
  void initState() {
    super.initState();
    // Product details is a full-screen route with its own bottom CTA.
    // Ensure global SnackBars don't cover the "Add to Cart" button.
    NotificationService.pushBottomInset(80);
    _loadRatings();
    // Track recently viewed
    RecentlyViewedService.addToList(widget.listing);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoSelectSizeIfSingle();
    });
  }

  @override
  void dispose() {
    NotificationService.popBottomInset();
    super.dispose();
  }

  Future<double?> _calculateDistance() async {
    try {
      // Get buyer location
      final buyerPosition = await LocationService.getCurrentLocation();
      if (buyerPosition == null) return null;

      // Get seller profile
      final sellerProfile = await SellerProfileService.getProfile(widget.listing.sellerId);
      if (sellerProfile == null || sellerProfile.pickupLocation.isEmpty) return null;

      // Parse seller location
      final sellerCoords = await LocationParser.parseLocation(sellerProfile.pickupLocation);
      if (sellerCoords == null) return null;

      // Calculate distance
      return DistanceUtils.calculateDistance(
        buyerPosition.latitude,
        buyerPosition.longitude,
        sellerCoords['latitude']!,
        sellerCoords['longitude']!,
      );
    } catch (e) {
      debugPrint('[ProductDetailsScreen] Error calculating distance: $e');
      return null;
    }
  }

  void _autoSelectSizeIfSingle() {
    if (widget.listing.type == SellType.clothingAndApparel) {
      final hasCombinations = widget.listing.sizeColorCombinations != null && 
          widget.listing.sizeColorCombinations!.isNotEmpty;
      final sizes = hasCombinations
          ? widget.listing.sizeColorCombinations!.map((combo) => combo.size).toList()
          : (widget.listing.availableSizes ?? []);
      
      if (sizes.length == 1 && selectedSize == null) {
        setState(() {
          selectedSize = sizes.first;
        });
      }
    }
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
        return Colors.red.shade700;
    }
  }

  String _getFoodTypeLabel() {
    return widget.listing.category.label;
  }

  double _getCurrentPrice() {
    if (widget.listing.hasMultiplePackSizes && selectedPackSize != null) {
      return selectedPackSize!.price;
    }
    return widget.listing.price;
  }

  String _getUnitPrice() {
    if (widget.listing.hasMultiplePackSizes && widget.listing.packSizes != null && 
        widget.listing.packSizes!.isNotEmpty) {
      if (selectedPackSize != null && widget.listing.measurementUnit != null) {
        final label = selectedPackSize!.getDisplayLabel(widget.listing.measurementUnit!.shortLabel);
        return '₹${selectedPackSize!.price.toStringAsFixed(0)} for $label';
      }
      final firstPack = widget.listing.packSizes!.first;
      if (widget.listing.measurementUnit != null) {
        final label = firstPack.getDisplayLabel(widget.listing.measurementUnit!.shortLabel);
        return 'Select pack size (e.g., ₹${firstPack.price.toStringAsFixed(0)} for $label)';
      }
    }
    if (widget.listing.type == SellType.groceries || widget.listing.type == SellType.vegetables) {
      if (widget.listing.measurementUnit != null) {
        if (widget.listing.packSizes != null && widget.listing.packSizes!.isNotEmpty) {
          final packSize = widget.listing.packSizes!.first;
          final label = packSize.getDisplayLabel(widget.listing.measurementUnit!.shortLabel);
          return '₹${packSize.price.toStringAsFixed(0)} for $label';
        }
        return '₹${widget.listing.price.toStringAsFixed(0)} for 1 ${widget.listing.measurementUnit!.shortLabel}';
      }
    }
    return 'per item';
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

  Future<void> _addToCart() async {
    final isAvailable = widget.listing.quantity > 0;
    if (!isAvailable) return;

    // Validation for clothing items
    if (widget.listing.type == SellType.clothingAndApparel) {
      if (selectedSize == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a size')),
        );
        return;
      }
      // Check if color is required
      final hasCombinations = widget.listing.sizeColorCombinations != null && 
          widget.listing.sizeColorCombinations!.isNotEmpty;
      if (hasCombinations) {
        final combo = widget.listing.sizeColorCombinations!.firstWhere(
          (c) => c.size == selectedSize,
          orElse: () => SizeColorCombination(size: '', availableColors: []),
        );
        if (combo.availableColors.isNotEmpty && selectedColor == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a color')),
          );
          return;
        }
      } else if (widget.listing.availableColors != null && 
                 widget.listing.availableColors!.isNotEmpty && 
                 selectedColor == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a color')),
        );
        return;
      }
    }

    // Validation for groceries with multiple pack sizes
    if (widget.listing.hasMultiplePackSizes && selectedPackSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pack size')),
      );
      return;
    }

    try {
      await CartService.addItem(
        widget.listing,
        selectedQuantity,
        packSize: selectedPackSize,
        selectedSize: selectedSize,
        selectedColor: selectedColor,
      );

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        // Don't clear existing snackbars - seller notification should persist
        // It will be temporarily hidden but will re-appear after this notification dismisses
        
        // Store reference to dismiss timer
        Timer? dismissTimer;
        
        // Show the new snackbar - removed action button to prevent duration extension
        messenger.showSnackBar(
          SnackBar(
            content: InkWell(
              onTap: () {
                dismissTimer?.cancel();
                messenger.hideCurrentSnackBar();
                // Re-show seller notification after cart notification is dismissed
                NotificationService.reShowSellerNotificationIfNeeded();
                // Use global navigator key so navigation works from any screen
                navigatorKey.currentState?.push(
                  MaterialPageRoute(builder: (context) => const CartScreen()),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Added to cart!  Tap to view cart'),
                    Icon(Icons.shopping_cart, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5), // Exactly 5 seconds
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            // Removed action button - it was extending the duration
          ),
        );
        
        // Force dismiss after exactly 5 seconds and re-show seller notification
        dismissTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) {
            try {
              messenger.hideCurrentSnackBar();
              // Re-show seller notification after cart notification dismisses
              NotificationService.reShowSellerNotificationIfNeeded();
            } catch (e) {
              // Ignore if already dismissed, but still try to re-show seller notification
              NotificationService.reShowSellerNotificationIfNeeded();
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPrice = _getCurrentPrice();
    final isAvailable = widget.listing.quantity > 0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Product Details'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: Stack(
                children: [
                  Builder(
                    builder: (context) {
                      final imagePath = widget.listing.getImagePathForColor(selectedColor);
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                        child: Container(
                          key: ValueKey<String?>(imagePath ?? 'default'),
                          height: 350,
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
                                      ? const Center(child: Icon(Icons.image_not_supported, size: 64))
                                      : File(imagePath).existsSync()
                                          ? Image.file(File(imagePath), fit: BoxFit.cover)
                                          : const Center(child: Icon(Icons.image_not_supported, size: 64))))
                              : const Center(child: Icon(Icons.fastfood, size: 64, color: Colors.grey)),
                        ),
                      );
                    },
                  ),
                  // Food Type Badge
                  if (widget.listing.type != SellType.clothingAndApparel)
                    Positioned(
                      top: 16,
                      left: 16,
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
                  // Stock Indicator
                  if (!isAvailable)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.black.withOpacity(0.8), Colors.black.withOpacity(0.6)],
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
                              fontSize: 18,
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
              padding: const EdgeInsets.all(20),
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
                              style: AppTheme.heading2,
                            ),
                            const SizedBox(height: 6),
                            if (widget.listing.shouldHideSellerIdentity)
                              SellerNameWidget(
                                sellerName: widget.listing.sellerName,
                                shouldHideSellerIdentity: true,
                                isOrderAccepted: false,
                                style: AppTheme.bodyMedium.copyWith(color: AppTheme.lightText),
                              )
                            else
                              Text(
                                'by ${widget.listing.sellerName}',
                                style: AppTheme.bodyMedium.copyWith(color: AppTheme.lightText),
                              ),
                            const SizedBox(height: 8),
                            // Distance from seller
                            FutureBuilder<double?>(
                              future: _calculateDistance(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data != null) {
                                  return Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 16,
                                        color: Colors.blue.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Seller is ${DistanceUtils.formatDistance(snapshot.data!)} away',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.blue.shade600,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                      ),
                      if (averageFoodRating != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, color: AppTheme.warningColor, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                averageFoodRating!.toStringAsFixed(1),
                                style: TextStyle(
                                  color: AppTheme.warningColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Price Section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (widget.listing.originalPrice != null) ...[
                        Text(
                          '₹${widget.listing.originalPrice!.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.lightText,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: AppTheme.getPriceBadgeDecoration(),
                        child: Text(
                          '₹${currentPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _getUnitPrice(),
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  ),

                  if (widget.listing.originalPrice != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'You save ₹${(widget.listing.originalPrice! - widget.listing.price).toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Size Selection (for clothing)
                  if (widget.listing.type == SellType.clothingAndApparel) ...[
                    Builder(
                      builder: (context) {
                        final sizes = widget.listing.sizeColorCombinations != null && 
                            widget.listing.sizeColorCombinations!.isNotEmpty
                            ? widget.listing.sizeColorCombinations!.map((combo) => combo.size).toList()
                            : (widget.listing.availableSizes ?? []);
                        
                        if (sizes.isEmpty) return const SizedBox.shrink();
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.straighten, size: 20, color: AppTheme.darkText),
                                const SizedBox(width: 8),
                                Text(
                                  'Select Size',
                                  style: AppTheme.heading4,
                                ),
                                if (selectedSize == null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '(Required)',
                                    style: AppTheme.bodySmall.copyWith(
                                      color: AppTheme.errorColor,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: sizes.map((size) {
                                final isSelected = selectedSize == size;
                                final isFreeSize = size.toLowerCase() == 'free size';
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedSize = size;
                                      selectedColor = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                    decoration: AppTheme.getChipDecoration(
                                      isSelected: isSelected,
                                      color: isFreeSize ? AppTheme.secondaryColor : AppTheme.infoColor,
                                      isFreeSize: isFreeSize,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isFreeSize) ...[
                                          Icon(
                                            Icons.all_inclusive,
                                            size: 18,
                                            color: isSelected ? Colors.white : AppTheme.secondaryColor,
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Text(
                                          size,
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: isSelected ? Colors.white : (isFreeSize ? AppTheme.secondaryColor : AppTheme.infoColor),
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        );
                      },
                    ),
                    // Color Selection
                    Builder(
                      builder: (context) {
                        if (selectedSize == null) return const SizedBox.shrink();
                        
                        List<String> availableColorsForSize = [];
                        if (widget.listing.sizeColorCombinations != null && 
                            widget.listing.sizeColorCombinations!.isNotEmpty) {
                          final combo = widget.listing.sizeColorCombinations!.firstWhere(
                            (c) => c.size == selectedSize,
                            orElse: () => SizeColorCombination(size: '', availableColors: []),
                          );
                          availableColorsForSize = combo.availableColors;
                          if (availableColorsForSize.isEmpty && 
                              widget.listing.availableColors != null && 
                              widget.listing.availableColors!.isNotEmpty) {
                            availableColorsForSize = widget.listing.availableColors!;
                          }
                        } else if (widget.listing.availableColors != null) {
                          availableColorsForSize = widget.listing.availableColors!;
                        }
                        
                        if (availableColorsForSize.isEmpty) return const SizedBox.shrink();
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Icon(Icons.palette, size: 20, color: AppTheme.darkText),
                                const SizedBox(width: 8),
                                Text(
                                  'Select Color',
                                  style: AppTheme.heading4,
                                ),
                                if (selectedColor == null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '(Required)',
                                    style: AppTheme.bodySmall.copyWith(
                                      color: AppTheme.errorColor,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: availableColorsForSize.map((color) {
                                final isSelected = selectedColor == color;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedColor = color;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                    decoration: AppTheme.getChipDecoration(
                                      isSelected: isSelected,
                                      color: AppTheme.accentColor,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.palette,
                                          size: 18,
                                          color: isSelected ? Colors.white : AppTheme.accentColor,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          color,
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: isSelected ? Colors.white : AppTheme.accentColor,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Pack Size Selection (for groceries)
                  if (isAvailable && widget.listing.hasMultiplePackSizes && 
                      widget.listing.packSizes != null) ...[
                    Text(
                      'Select Pack Size',
                      style: AppTheme.heading4,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: widget.listing.packSizes!.map((pack) {
                        final isSelected = selectedPackSize?.quantity == pack.quantity &&
                            selectedPackSize?.price == pack.price;
                        final unitLabel = widget.listing.measurementUnit?.shortLabel ?? '';
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedPackSize = isSelected ? null : pack;
                              selectedQuantity = 1;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            decoration: AppTheme.getChipDecoration(
                              isSelected: isSelected,
                              color: AppTheme.primaryColor,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  pack.getDisplayLabel(unitLabel),
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    fontSize: 14,
                                    color: isSelected ? Colors.white : AppTheme.primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${pack.price.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Quantity Selection
                  if (isAvailable && !widget.listing.isValidBulkFood && !widget.listing.isLiveKitchen) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Quantity',
                          style: AppTheme.heading4,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.borderColor, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 22),
                                onPressed: selectedQuantity > 1
                                    ? () {
                                        setState(() {
                                          selectedQuantity--;
                                        });
                                      }
                                    : null,
                                color: selectedQuantity > 1 ? AppTheme.darkText : AppTheme.lightText,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                child: Text(
                                  selectedQuantity.toString(),
                                  style: AppTheme.heading4,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 22),
                                onPressed: selectedQuantity < widget.listing.quantity
                                    ? () {
                                        setState(() {
                                          selectedQuantity++;
                                        });
                                      }
                                    : null,
                                color: selectedQuantity < widget.listing.quantity 
                                    ? AppTheme.darkText 
                                    : AppTheme.lightText,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Stock & Category Info
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.infoColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.infoColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.listing.isLiveKitchen ? Icons.people_outline : Icons.inventory_2,
                              size: 16,
                              color: AppTheme.infoColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.listing.isLiveKitchen
                                  ? '${widget.listing.remainingCapacity} slots'
                                  : widget.listing.isValidBulkFood
                                      ? '${widget.listing.quantity} pack${widget.listing.quantity > 1 ? 's' : ''}'
                                      : '${widget.listing.quantity} left',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.infoColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.listing.type != SellType.clothingAndApparel)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.secondaryColor.withOpacity(0.1),
                                AppTheme.secondaryColor.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.listing.isLiveKitchen ? Icons.restaurant : Icons.category,
                                size: 16,
                                color: AppTheme.secondaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.listing.type.displayName,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.secondaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Description (for clothing)
                  if (widget.listing.type == SellType.clothingAndApparel && 
                      widget.listing.description != null && 
                      widget.listing.description!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Description',
                      style: AppTheme.heading4,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.listing.description!,
                      style: AppTheme.bodyMedium,
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Add to Cart Button
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: isAvailable
                          ? (widget.listing.isLiveKitchen
                              ? AppTheme.getSuccessButtonDecoration()
                              : widget.listing.isValidBulkFood
                                  ? AppTheme.getAccentButtonDecoration()
                                  : AppTheme.getPrimaryButtonDecoration())
                          : BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(14),
                            ),
                      child: ElevatedButton(
                        onPressed: isAvailable ? _addToCart : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.listing.isLiveKitchen && isAvailable) ...[
                              const Icon(Icons.restaurant, size: 22),
                              const SizedBox(width: 10),
                            ] else if (widget.listing.isValidBulkFood && isAvailable) ...[
                              const Icon(Icons.groups, size: 22),
                              const SizedBox(width: 10),
                            ],
                            Text(
                              _getButtonText(isAvailable),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

