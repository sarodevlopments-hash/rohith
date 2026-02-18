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
import '../widgets/pickup_otp_banner.dart';
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
  List<ListingWithDistance> _recommendedListingsWithDistance = [];
  List<ListingWithDistance> _locationBasedListingsWithDistance = [];
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
      final filteredListingsWithDistance = filteredWithDistance
          .take(HomeFeaturesConfig.recommendationsLimit)
          .toList();
      final filteredListings = filteredListingsWithDistance
          .map((lwd) => lwd.listing)
          .toList();

      if (mounted) {
        setState(() {
          _recommendedListings = filteredListings;
          _recommendedListingsWithDistance = filteredListingsWithDistance;
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
    final filteredListingsWithDistance = filteredWithDistance
        .take(HomeFeaturesConfig.locationBasedLimit)
        .toList();
    final filteredListings = filteredListingsWithDistance
        .map((lwd) => lwd.listing)
        .toList();

    if (mounted) {
      setState(() {
        _locationBasedListings = filteredListings;
        _locationBasedListingsWithDistance = filteredListingsWithDistance;
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
          SellType.electronics: allListings.where((l) => l.type == SellType.electronics).length,
          SellType.electricals: allListings.where((l) => l.type == SellType.electricals).length,
          SellType.hardware: allListings.where((l) => l.type == SellType.hardware).length,
          SellType.automobiles: allListings.where((l) => l.type == SellType.automobiles).length,
          SellType.others: allListings.where((l) => l.type == SellType.others).length,
        };

        return Container(
          color: AppTheme.backgroundColor, // Premium pastel lavender/pearl white background
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Pickup OTP Banner - Shows when order is ready for pickup
              const PickupOtpBanner(),
              
              // Total Savings Banner - Premium Gradient
              if (_totalSavings > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    gradient: AppTheme.savingsGradient, // Blue → Teal → Green gradient
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.teal.withOpacity(0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: AppTheme.softGreen.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.savings_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Savings',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.95),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${_totalSavings.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 24,
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Shop by Category Section - Fixed Title with Horizontal Scrollable Grid
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fixed Section Title
                  Text(
                    'Shop by Category',
                    style: AppTheme.heading3.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Horizontal Scrollable Category Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final screenWidth = MediaQuery.of(context).size.width;
                      final cardWidth = (screenWidth - 48) / 2; // Account for padding and spacing
                      final cardHeight = cardWidth; // Maintain 1:1 aspect ratio
                      
                      // Build category list
                      final categories = <Map<String, dynamic>>[
                        {
                          'sellType': SellType.cookedFood,
                          'title': 'Food',
                          'icon': Icons.restaurant,
                          'emoji': '🍲',
                          'imagePath': 'assets/images/categories/food.jpg',
                          'color': Colors.orange,
                        },
                        {
                          'sellType': SellType.groceries,
                          'title': 'Groceries',
                          'icon': Icons.shopping_basket,
                          'emoji': '🛒',
                          'imagePath': 'assets/images/categories/groceries.jpg',
                          'color': Colors.blue,
                        },
                        {
                          'sellType': SellType.vegetables,
                          'title': 'Vegetables & Fruits',
                          'icon': Icons.eco,
                          'emoji': '🥬',
                          'imagePath': 'assets/images/categories/vegetables_fruits.jpg',
                          'color': Colors.green,
                        },
                        {
                          'sellType': SellType.clothingAndApparel,
                          'title': 'Clothing',
                          'icon': Icons.checkroom,
                          'emoji': '👕',
                          'imagePath': 'assets/images/categories/clothing.jpg',
                          'color': Colors.purple,
                        },
                        if ((categoryCounts[SellType.liveKitchen] ?? 0) > 0)
                          {
                            'sellType': SellType.liveKitchen,
                            'title': 'Live Kitchen',
                            'icon': Icons.local_dining,
                            'emoji': '🔥',
                            'imagePath': 'assets/images/categories/live kitchen.png',
                            'color': Colors.red,
                          },
                        {
                          'sellType': SellType.electronics,
                          'title': 'Electronics',
                          'icon': Icons.devices,
                          'emoji': '📱',
                          'imagePath': null,
                          'color': const Color(0xFF9B59B6),
                        },
                        {
                          'sellType': SellType.electricals,
                          'title': 'Electricals',
                          'icon': Icons.electrical_services,
                          'emoji': '⚡',
                          'imagePath': null,
                          'color': const Color(0xFFE67E22),
                        },
                        {
                          'sellType': SellType.hardware,
                          'title': 'Hardware',
                          'icon': Icons.build,
                          'emoji': '🔧',
                          'imagePath': null,
                          'color': const Color(0xFF34495E),
                        },
                        {
                          'sellType': SellType.automobiles,
                          'title': 'Automobiles',
                          'icon': Icons.directions_car,
                          'emoji': '🚗',
                          'imagePath': null,
                          'color': const Color(0xFFE74C3C),
                        },
                        {
                          'sellType': SellType.others,
                          'title': 'Others',
                          'icon': Icons.category,
                          'emoji': '📦',
                          'imagePath': null,
                          'color': const Color(0xFF95A5A6),
                        },
                      ];
                      
                      // Pair categories into rows (2 per row)
                      final pairedCategories = <List<Map<String, dynamic>>>[];
                      for (int i = 0; i < categories.length; i += 2) {
                        if (i + 1 < categories.length) {
                          pairedCategories.add([categories[i], categories[i + 1]]);
                        } else {
                          // Odd number - single item in last row
                          pairedCategories.add([categories[i]]);
                        }
                      }
                      
                      return SizedBox(
                        height: cardHeight + 32, // Card height + padding
                        child: Stack(
                          children: [
                            // Horizontal Scrollable ListView
                            ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: pairedCategories.length,
                              itemBuilder: (context, index) {
                                final pair = pairedCategories[index];
                                return Container(
                                  width: cardWidth * 2 + 16, // 2 cards + spacing
                                  margin: const EdgeInsets.only(right: 16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _buildCategoryCard(
                                          context: context,
                                          sellType: pair[0]['sellType'] as SellType,
                                          title: pair[0]['title'] as String,
                                          icon: pair[0]['icon'] as IconData,
                                          emoji: pair[0]['emoji'] as String,
                                          imagePath: pair[0]['imagePath'] as String?,
                                          color: pair[0]['color'] as Color,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      if (pair.length > 1)
                                        Expanded(
                                          child: _buildCategoryCard(
                                            context: context,
                                            sellType: pair[1]['sellType'] as SellType,
                                            title: pair[1]['title'] as String,
                                            icon: pair[1]['icon'] as IconData,
                                            emoji: pair[1]['emoji'] as String,
                                            imagePath: pair[1]['imagePath'] as String?,
                                            color: pair[1]['color'] as Color,
                                          ),
                                        )
                                      else
                                        const Spacer(),
                                    ],
                                  ),
                                );
                              },
                            ),
                            
                            // Right Fade Gradient (indicates scroll)
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              width: 40,
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.transparent,
                                        AppTheme.backgroundColor.withOpacity(0.8),
                                        AppTheme.backgroundColor,
                                      ],
                                      stops: const [0.0, 0.5, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
                        icon: Icons.thumb_up_rounded,
                        iconColor: AppTheme.badgeRecommended,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 240,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: filteredRecommended.length,
                          itemBuilder: (context, index) {
                            final listing = filteredRecommended[index];
                            final listingWithDistance = _recommendedListingsWithDistance
                                .firstWhere(
                                  (lwd) => lwd.listing.key == listing.key,
                                  orElse: () => ListingWithDistance(listing: listing),
                                );
                            return CompactProductCard(
                              listing: listing,
                              badgeText: 'Recommended',
                              listingWithDistance: listingWithDistance,
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
                            final listing = filteredLocationBased[index];
                            final listingWithDistance = _locationBasedListingsWithDistance
                                .firstWhere(
                                  (lwd) => lwd.listing.key == listing.key,
                                  orElse: () => ListingWithDistance(listing: listing),
                                );
                            return CompactProductCard(
                              listing: listing,
                              badgeText: 'Trending',
                              listingWithDistance: listingWithDistance,
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
        decoration: AppTheme.getCategoryCardDecoration(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20), // 18-22px rounded corners
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
              // Premium Dark Overlay Gradient at Bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 80, // Cover bottom portion with gradient
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.7),
                        Colors.black.withOpacity(0.85),
                      ],
                      stops: const [0.0, 0.3, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
              // White Bold Title Text with Shadow
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.3,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 3,
                          offset: Offset(0, 1),
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


