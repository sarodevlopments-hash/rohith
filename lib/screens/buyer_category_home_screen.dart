import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/listing.dart';
import '../models/sell_type.dart';
import '../models/order.dart';
import '../theme/app_theme.dart';
import '../widgets/compact_product_card.dart';
import '../services/most_bought_service.dart';
import '../services/recently_viewed_service.dart';
import '../services/recommendation_service.dart';
import '../services/location_based_service.dart';
import '../services/time_based_suggestions_service.dart';
import '../services/distance_filter_service.dart';
import '../config/home_features_config.dart';
import 'category_listing_screen.dart';

class BuyerCategoryHomeScreen extends StatefulWidget {
  const BuyerCategoryHomeScreen({super.key});

  @override
  State<BuyerCategoryHomeScreen> createState() => _BuyerCategoryHomeScreenState();
}

class _BuyerCategoryHomeScreenState extends State<BuyerCategoryHomeScreen> {
  double _totalSavings = 0;
  List<Listing> _mostBoughtListings = [];
  List<Listing> _recentlyViewedListings = [];
  List<Listing> _recommendedListings = [];
  List<Listing> _locationBasedListings = [];
  List<Listing> _timeBasedListings = [];
  String? _userLocation;
  Timer? _timeBasedRefreshTimer;

  @override
  void initState() {
    super.initState();
    _calculateTotalSavings();
    _loadMostBoughtItems();
    _loadRecentlyViewedItems();
    if (HomeFeaturesConfig.enableRecommendations) {
      _loadRecommendedItems();
    }
    if (HomeFeaturesConfig.enableLocationBased) {
      _loadLocationBasedItems();
    }
    if (HomeFeaturesConfig.enableTimeBased) {
      _loadTimeBasedItems();
      _startTimeBasedRefreshTimer();
    }
    Hive.box<Order>('ordersBox').listenable().addListener(_calculateTotalSavings);
    Hive.box<Listing>('listingBox').listenable().addListener(_loadProductSections);
  }

  @override
  void dispose() {
    _timeBasedRefreshTimer?.cancel();
    Hive.box<Order>('ordersBox').listenable().removeListener(_calculateTotalSavings);
    Hive.box<Listing>('listingBox').listenable().removeListener(_loadProductSections);
    super.dispose();
  }

  void _startTimeBasedRefreshTimer() {
    // Refresh time-based suggestions every hour
    _timeBasedRefreshTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      if (mounted && HomeFeaturesConfig.enableTimeBased) {
        _loadTimeBasedItems();
      }
    });
  }

  void _calculateTotalSavings() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        setState(() {
          _totalSavings = 0;
        });
      }
      return;
    }

    final ordersBox = Hive.box<Order>('ordersBox');
    double total = 0;
    for (var order in ordersBox.values) {
      if (order.userId == currentUser.uid) {
        total += order.savedAmount;
      }
    }
    if (mounted) {
      setState(() {
        _totalSavings = total;
      });
    }
  }

  void _loadProductSections() {
    _loadMostBoughtItems();
    _loadRecentlyViewedItems();
    if (HomeFeaturesConfig.enableRecommendations) {
      _loadRecommendedItems();
    }
    if (HomeFeaturesConfig.enableLocationBased) {
      _loadLocationBasedItems();
    }
    if (HomeFeaturesConfig.enableTimeBased) {
      _loadTimeBasedItems();
    }
  }

  Future<void> _loadMostBoughtItems() async {
    final listingBox = Hive.box<Listing>('listingBox');
    final mostBoughtIds = MostBoughtService.getPopularListingIds(limit: 20); // Get more to account for distance filtering
    
    final listings = mostBoughtIds
        .map((id) {
          try {
            final key = int.tryParse(id);
            if (key == null) return null;
            return listingBox.get(key);
          } catch (e) {
            return null;
          }
        })
        .whereType<Listing>()
        .where((l) => l.quantity > 0 || (l.isLiveKitchen && l.isLiveKitchenAvailable))
        .toList();

    // Apply distance filtering to most bought items
    final filteredWithDistance = await DistanceFilterService.filterByDistance(
      listings,
      expandRadiusIfEmpty: true,
      includeWithoutLocation: false,
    );

    // Take only the filtered listings within distance limit
    final filteredListings = filteredWithDistance
        .map((lwd) => lwd.listing)
        .take(10)
        .toList();

    if (mounted) {
      setState(() {
        _mostBoughtListings = filteredListings;
      });
    }
  }

  Future<void> _loadRecentlyViewedItems() async {
    final listingBox = Hive.box<Listing>('listingBox');
    final recentlyViewedIds = await RecentlyViewedService.getRecentlyViewedIds();
    
    final listings = recentlyViewedIds
        .map((id) {
          try {
            final key = int.tryParse(id);
            if (key == null) return null;
            return listingBox.get(key);
          } catch (e) {
            return null;
          }
        })
        .whereType<Listing>()
        .where((l) => l.quantity > 0 || (l.isLiveKitchen && l.isLiveKitchenAvailable))
        .take(10)
        .toList();

    if (mounted) {
      setState(() {
        _recentlyViewedListings = listings;
      });
    }
  }

  Future<void> _loadRecommendedItems() async {
    try {
      if (!Hive.isBoxOpen('listingBox')) return;
      
      final listingBox = Hive.box<Listing>('listingBox');
      final recommendedIds = await RecommendationService.getRecommendedListingIds(
        limit: HomeFeaturesConfig.recommendationsLimit * 2, // Get more to account for distance filtering
      );
      
      if (recommendedIds.isEmpty) {
        if (mounted) {
          setState(() {
            _recommendedListings = [];
          });
        }
        return;
      }
      
      final listings = recommendedIds
          .map((id) {
            try {
              final key = int.tryParse(id);
              if (key == null) return null;
              return listingBox.get(key);
            } catch (e) {
              return null;
            }
          })
          .whereType<Listing>()
          .where((l) => l.quantity > 0 || (l.isLiveKitchen && l.isLiveKitchenAvailable))
          .toList();

      // Apply distance filtering to recommended items
      final filteredWithDistance = await DistanceFilterService.filterByDistance(
        listings,
        expandRadiusIfEmpty: true,
        includeWithoutLocation: false,
      );

      // Take only the filtered listings within distance limit
      final filteredListings = filteredWithDistance
          .map((lwd) => lwd.listing)
          .take(HomeFeaturesConfig.recommendationsLimit)
          .toList();

      if (mounted) {
        setState(() {
          _recommendedListings = filteredListings;
        });
      }
    } catch (e) {
      // Silently handle errors - don't show recommendations if there's an issue
      if (mounted) {
        setState(() {
          _recommendedListings = [];
        });
      }
    }
  }

  Future<void> _loadLocationBasedItems() async {
    final listingBox = Hive.box<Listing>('listingBox');
    final locationBasedIds = LocationBasedService.getPopularNearYouListingIds(
      limit: HomeFeaturesConfig.locationBasedLimit * 2, // Get more to account for distance filtering
    );
    
    // Get user location
    _userLocation = await LocationBasedService.getUserLocation();
    
    final listings = locationBasedIds
        .map((id) {
          try {
            final key = int.tryParse(id);
            if (key == null) return null;
            return listingBox.get(key);
          } catch (e) {
            return null;
          }
        })
        .whereType<Listing>()
        .where((l) => l.quantity > 0 || (l.isLiveKitchen && l.isLiveKitchenAvailable))
        .toList();

    // Apply distance filtering to "Popular Near You" items
    final filteredWithDistance = await DistanceFilterService.filterByDistance(
      listings,
      expandRadiusIfEmpty: true,
      includeWithoutLocation: false,
    );

    // Take only the filtered listings within distance limit
    final filteredListings = filteredWithDistance
        .map((lwd) => lwd.listing)
        .take(HomeFeaturesConfig.locationBasedLimit)
        .toList();

    if (mounted) {
      setState(() {
        _locationBasedListings = filteredListings;
      });
    }
  }

  void _loadTimeBasedItems() {
    try {
      final timeCategory = TimeBasedSuggestionsService.getCurrentTimeCategory();
      final listings = TimeBasedSuggestionsService.getTimeBasedListings(timeCategory)
          .take(HomeFeaturesConfig.timeBasedLimit)
          .toList();

      if (mounted) {
        setState(() {
          _timeBasedListings = listings;
        });
      }
    } catch (e) {
      // Silently handle errors - don't show time-based suggestions if there's an issue
      if (mounted) {
        setState(() {
          _timeBasedListings = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<Listing>>(
      valueListenable: Hive.box<Listing>('listingBox').listenable(),
      builder: (context, box, _) {
        final allListings = box.values.toList();
        
        // Count items per category
        final categoryCounts = {
          SellType.cookedFood: allListings.where((l) => l.type == SellType.cookedFood).length,
          SellType.groceries: allListings.where((l) => l.type == SellType.groceries).length,
          SellType.vegetables: allListings.where((l) => l.type == SellType.vegetables).length,
          SellType.clothingAndApparel: allListings.where((l) => l.type == SellType.clothingAndApparel).length,
          SellType.liveKitchen: allListings.where((l) => l.type == SellType.liveKitchen).length,
        };

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total Savings Banner
              if (_totalSavings > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.successGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.successColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.savings, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Savings',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '₹${_totalSavings.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Shop by Category Section - Minimal Clean Header
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Custom engaging icon - Shopping basket with category hints
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          // Hero-badge treatment (CTA cue)
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF7CB9FF).withOpacity(0.25), // soft blue
                              const Color(0xFF7FE3B1).withOpacity(0.25), // soft green
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/categories/shop_by_category_header.png',
                            // Fill the available area (no extra padding / no downscaling)
                            fit: BoxFit.cover,
                            alignment: const Alignment(0, -0.15),
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Shop by Category',
                              style: AppTheme.heading3.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Browse products by category',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.lightText,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Subtle divider
                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.grey.shade200,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Category Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
                children: [
                  _buildCategoryCard(
                    context: context,
                    sellType: SellType.cookedFood,
                    title: 'Food',
                    icon: Icons.restaurant,
                    emoji: '🍲',
                    imagePath: 'assets/images/categories/food.jpg',
                    color: Colors.orange,
                  ),
                  _buildCategoryCard(
                    context: context,
                    sellType: SellType.groceries,
                    title: 'Groceries',
                    icon: Icons.shopping_basket,
                    emoji: '🛒',
                    imagePath: 'assets/images/categories/groceries.jpg',
                    color: Colors.blue,
                  ),
                  _buildCategoryCard(
                    context: context,
                    sellType: SellType.vegetables,
                    title: 'Vegetables & Fruits',
                    icon: Icons.eco,
                    emoji: '🥬',
                    imagePath: 'assets/images/categories/vegetables_fruits.jpg',
                    color: Colors.green,
                  ),
                  _buildCategoryCard(
                    context: context,
                    sellType: SellType.clothingAndApparel,
                    title: 'Clothing',
                    icon: Icons.checkroom,
                    emoji: '👕',
                    imagePath: 'assets/images/categories/clothing.jpg',
                    color: Colors.purple,
                  ),
                  if ((categoryCounts[SellType.liveKitchen] ?? 0) > 0)
                    _buildCategoryCard(
                      context: context,
                      sellType: SellType.liveKitchen,
                      title: 'Live Kitchen',
                      icon: Icons.local_dining,
                      emoji: '🔥',
                      imagePath: 'assets/images/categories/live_kitchen.jpg',
                      color: Colors.red,
                    ),
                ],
              ),

              const SizedBox(height: 32),

              // Recommended for You Section
              // Filter out products that use category images to avoid duplicates
              Builder(
                builder: (context) {
                  if (!HomeFeaturesConfig.enableRecommendations) {
                    return const SizedBox.shrink();
                  }
                  
                  final filteredRecommended = _recommendedListings.where((listing) {
                    if (listing.imagePath == null) return true;
                    final imagePath = listing.imagePath!.toLowerCase();
                    // Exclude category images
                    return !imagePath.contains('categories/food') &&
                           !imagePath.contains('categories/groceries') &&
                           !imagePath.contains('categories/vegetables') &&
                           !imagePath.contains('categories/clothing') &&
                           !imagePath.contains('categories/live_kitchen');
                  }).toList();
                  
                  if (filteredRecommended.isEmpty) return const SizedBox.shrink();
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        title: 'Recommended for You',
                        subtitle: 'Based on your preferences',
                        icon: Icons.thumb_up,
                        iconColor: AppTheme.primaryColor,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 240,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: filteredRecommended.length,
                          itemBuilder: (context, index) {
                            return CompactProductCard(
                              listing: filteredRecommended[index],
                              badgeText: 'Recommended',
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  );
                },
              ),

              // Location-Based Popular Items Section
              // Filter out products that use category images to avoid duplicates
              Builder(
                builder: (context) {
                  if (!HomeFeaturesConfig.enableLocationBased) {
                    return const SizedBox.shrink();
                  }
                  
                  final filteredLocationBased = _locationBasedListings.where((listing) {
                    if (listing.imagePath == null) return true;
                    final imagePath = listing.imagePath!.toLowerCase();
                    // Exclude category images
                    return !imagePath.contains('categories/food') &&
                           !imagePath.contains('categories/groceries') &&
                           !imagePath.contains('categories/vegetables') &&
                           !imagePath.contains('categories/clothing') &&
                           !imagePath.contains('categories/live_kitchen');
                  }).toList();
                  
                  if (filteredLocationBased.isEmpty) return const SizedBox.shrink();
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        title: 'Popular Near You',
                        subtitle: _userLocation != null ? 'Trending in $_userLocation' : 'Trending in your area',
                        icon: Icons.location_on,
                        iconColor: AppTheme.warningColor,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 240,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: filteredLocationBased.length,
                          itemBuilder: (context, index) {
                            return CompactProductCard(
                              listing: filteredLocationBased[index],
                              badgeText: 'Trending',
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  );
                },
              ),

              // Time-Based Suggestions Section
              // Filter out products that use category images to avoid duplicates
              Builder(
                builder: (context) {
                  if (!HomeFeaturesConfig.enableTimeBased) {
                    return const SizedBox.shrink();
                  }
                  
                  final filteredTimeBased = _timeBasedListings.where((listing) {
                    if (listing.imagePath == null) return true;
                    final imagePath = listing.imagePath!.toLowerCase();
                    // Exclude category images
                    return !imagePath.contains('categories/food') &&
                           !imagePath.contains('categories/groceries') &&
                           !imagePath.contains('categories/vegetables') &&
                           !imagePath.contains('categories/clothing') &&
                           !imagePath.contains('categories/live_kitchen');
                  }).toList();
                  
                  if (filteredTimeBased.isEmpty) return const SizedBox.shrink();
                  
                  final timeCategory = TimeBasedSuggestionsService.getCurrentTimeCategory();
                  final emoji = TimeBasedSuggestionsService.getSectionEmoji(timeCategory);
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        title: '${emoji} ${TimeBasedSuggestionsService.getSectionTitle(timeCategory)}',
                        subtitle: TimeBasedSuggestionsService.getSectionSubtitle(timeCategory),
                        icon: Icons.access_time,
                        iconColor: AppTheme.secondaryColor,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 240,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: filteredTimeBased.length,
                          itemBuilder: (context, index) {
                            return CompactProductCard(
                              listing: filteredTimeBased[index],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  );
                },
              ),


              // Most Bought Items Section (after categories)
              // Filter out products that use category images to avoid duplicates
              Builder(
                builder: (context) {
                  final filteredMostBought = _mostBoughtListings.where((listing) {
                    if (listing.imagePath == null) return true;
                    final imagePath = listing.imagePath!.toLowerCase();
                    // Exclude category images
                    return !imagePath.contains('categories/food') &&
                           !imagePath.contains('categories/groceries') &&
                           !imagePath.contains('categories/vegetables') &&
                           !imagePath.contains('categories/clothing') &&
                           !imagePath.contains('categories/live_kitchen');
                  }).toList();
                  
                  if (filteredMostBought.isEmpty) return const SizedBox.shrink();
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      _buildSectionHeader(
                        title: 'Most Bought',
                        subtitle: 'Popular items near you',
                        icon: Icons.trending_up,
                        iconColor: AppTheme.accentColor,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 240,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: filteredMostBought.length,
                          itemBuilder: (context, index) {
                            return CompactProductCard(
                              listing: filteredMostBought[index],
                              badgeText: 'Popular',
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),

              // Recently Viewed Section
              // Filter out products that use category images to avoid duplicates
              Builder(
                builder: (context) {
                  final filteredRecentlyViewed = _recentlyViewedListings.where((listing) {
                    if (listing.imagePath == null) return true;
                    final imagePath = listing.imagePath!.toLowerCase();
                    // Exclude category images
                    return !imagePath.contains('categories/food') &&
                           !imagePath.contains('categories/groceries') &&
                           !imagePath.contains('categories/vegetables') &&
                           !imagePath.contains('categories/clothing') &&
                           !imagePath.contains('categories/live_kitchen');
                  }).toList();
                  
                  if (filteredRecentlyViewed.isEmpty) return const SizedBox.shrink();
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      _buildSectionHeader(
                        title: 'Recently Viewed',
                        subtitle: 'Continue shopping',
                        icon: Icons.history,
                        iconColor: AppTheme.secondaryColor,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 240,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: filteredRecentlyViewed.length,
                          itemBuilder: (context, index) {
                            return CompactProductCard(
                              listing: filteredRecentlyViewed[index],
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? subtitle,
    IconData? icon,
    Color? iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      (iconColor ?? AppTheme.primaryColor).withOpacity(0.15),
                      (iconColor ?? AppTheme.primaryColor).withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (iconColor ?? AppTheme.primaryColor).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? AppTheme.primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.heading3,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.lightText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryCard({
    required BuildContext context,
    required SellType sellType,
    required String title,
    required IconData icon,
    required String emoji,
    required Color color,
    String? imagePath,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CategoryListingScreen(
              sellType: sellType,
              categoryTitle: title,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Image with better styling
              imagePath != null
                    ? Image.asset(
                        imagePath,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback to shopping basket illustration
                          return Image.asset(
                            'assets/images/categories/shopping_basket_illustration.png',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              // Final fallback to gradient with emoji
                              return Container(
                                width: double.infinity,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      color.withOpacity(0.4),
                                      color.withOpacity(0.2),
                                      color.withOpacity(0.3),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    stops: const [0.0, 0.5, 1.0],
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 56),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      )
                    : Image.asset(
                        'assets/images/categories/shopping_basket_illustration.png',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          // Final fallback to gradient with emoji
                          return Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  color.withOpacity(0.4),
                                  color.withOpacity(0.2),
                                  color.withOpacity(0.3),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                            child: Center(
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 56),
                              ),
                            ),
                          );
                        },
                      ),
              // Gradient overlay for better text readability
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.4),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    title,
                    style: AppTheme.heading4.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// (Removed unused custom icon painter; we now force the real basket illustration for visibility.)


