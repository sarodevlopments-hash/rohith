import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/listing.dart';
import '../models/sell_type.dart';
import '../models/food_category.dart';
import '../widgets/buyer_listing_card.dart';
import '../services/distance_filter_service.dart';
import '../theme/app_theme.dart';

class CategoryListingScreen extends StatefulWidget {
  final SellType sellType;
  final String categoryTitle;

  const CategoryListingScreen({
    super.key,
    required this.sellType,
    required this.categoryTitle,
  });

  @override
  State<CategoryListingScreen> createState() => _CategoryListingScreenState();
}

class _CategoryListingScreenState extends State<CategoryListingScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  FoodCategory? _selectedCategory;
  double _minPrice = 0;
  double _maxPrice = 10000;
  bool _showOnlyAvailable = true;
  bool _sortByDiscount = false;
  String _sortOrder = 'default'; // 'default', 'price_low', 'price_high', 'discount', 'nearest', 'rating'
  bool _useLocationFilter = true; // Enable location-based filtering by default
  double? _selectedDistanceKm = 5.0; // Selected distance in kilometers (default: 5 km, null = no limit)
  static const List<double> _distanceOptions = [1, 3, 5, 10, 20]; // Distance options in km

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Listing> _filterListings(List<Listing> listings) {
    return listings.where((listing) {
      // Only show items from the selected category type
      if (listing.type != widget.sellType) {
        return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!listing.name.toLowerCase().contains(query) &&
            !listing.sellerName.toLowerCase().contains(query) &&
            (listing.description?.toLowerCase().contains(query) ?? false) == false) {
          return false;
        }
      }

      // Food category filter (only for food items)
      if (widget.sellType == SellType.cookedFood || widget.sellType == SellType.liveKitchen) {
        if (_selectedCategory != null && listing.category != _selectedCategory) {
          return false;
        }
      }

      // Price filter
      final currentPrice = listing.price;
      if (currentPrice < _minPrice || currentPrice > _maxPrice) {
        return false;
      }

      // Availability filter
      if (_showOnlyAvailable) {
        final isAvailable = listing.isLiveKitchen
            ? listing.isLiveKitchenAvailable
            : listing.quantity > 0;
        if (!isAvailable) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  List<Listing> _sortListings(List<Listing> listings) {
    final sorted = List<Listing>.from(listings);
    
    switch (_sortOrder) {
      case 'price_low':
        sorted.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_high':
        sorted.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'discount':
        sorted.sort((a, b) {
          final discountA = a.originalPrice != null
              ? ((a.originalPrice! - a.price) / a.originalPrice!) * 100
              : 0;
          final discountB = b.originalPrice != null
              ? ((b.originalPrice! - b.price) / b.originalPrice!) * 100
              : 0;
          return discountB.compareTo(discountA);
        });
        break;
      case 'rating':
        sorted.sort((a, b) {
          // Sort by rating (descending), then by review count
          final ratingCompare = b.averageRating.compareTo(a.averageRating);
          if (ratingCompare != 0) return ratingCompare;
          return b.reviewCount.compareTo(a.reviewCount);
        });
        break;
      default:
        // Default: sort by discount if enabled, otherwise keep original order
        if (_sortByDiscount) {
          sorted.sort((a, b) {
            final discountA = a.originalPrice != null
                ? ((a.originalPrice! - a.price) / a.originalPrice!) * 100
                : 0;
            final discountB = b.originalPrice != null
                ? ((b.originalPrice! - b.price) / b.originalPrice!) * 100
                : 0;
            return discountB.compareTo(discountA);
          });
        }
        break;
    }
    
    return sorted;
  }

  /// Sort listings with distance, prioritizing featured listings first
  List<ListingWithDistance> _sortListingsWithDistance(List<ListingWithDistance> listingsWithDistance) {
    final sorted = List<ListingWithDistance>.from(listingsWithDistance);
    
    // Separate featured and normal listings
    final featured = <ListingWithDistance>[];
    final normal = <ListingWithDistance>[];
    
    for (final item in sorted) {
      // Use null-safe check with default value for existing listings
      final isFeatured = item.listing.isFeatured ?? false;
      if (isFeatured) {
        featured.add(item);
      } else {
        normal.add(item);
      }
    }
    
    // Sort featured by priority (higher first), then by distance
    featured.sort((a, b) {
      final priorityA = a.listing.featuredPriority ?? 0;
      final priorityB = b.listing.featuredPriority ?? 0;
      final priorityCompare = priorityB.compareTo(priorityA);
      if (priorityCompare != 0) return priorityCompare;
      
      // Then by distance (nearest first)
      if (a.distanceInMeters == null && b.distanceInMeters == null) return 0;
      if (a.distanceInMeters == null) return 1;
      if (b.distanceInMeters == null) return -1;
      return a.distanceInMeters!.compareTo(b.distanceInMeters!);
    });
    
    // Sort normal listings based on sort order
    switch (_sortOrder) {
      case 'nearest':
        // Sort by distance (nearest first)
        normal.sort((a, b) {
          if (a.distanceInMeters == null && b.distanceInMeters == null) return 0;
          if (a.distanceInMeters == null) return 1;
          if (b.distanceInMeters == null) return -1;
          return a.distanceInMeters!.compareTo(b.distanceInMeters!);
        });
        break;
      case 'rating':
        // Sort by rating (descending), then by distance
        normal.sort((a, b) {
          final ratingCompare = b.listing.averageRating.compareTo(a.listing.averageRating);
          if (ratingCompare != 0) return ratingCompare;
          if (a.distanceInMeters == null && b.distanceInMeters == null) return 0;
          if (a.distanceInMeters == null) return 1;
          if (b.distanceInMeters == null) return -1;
          return a.distanceInMeters!.compareTo(b.distanceInMeters!);
        });
        break;
      case 'price_low':
        normal.sort((a, b) {
          final priceCompare = a.listing.price.compareTo(b.listing.price);
          if (priceCompare != 0) return priceCompare;
          if (a.distanceInMeters == null && b.distanceInMeters == null) return 0;
          if (a.distanceInMeters == null) return 1;
          if (b.distanceInMeters == null) return -1;
          return a.distanceInMeters!.compareTo(b.distanceInMeters!);
        });
        break;
      case 'price_high':
        normal.sort((a, b) {
          final priceCompare = b.listing.price.compareTo(a.listing.price);
          if (priceCompare != 0) return priceCompare;
          if (a.distanceInMeters == null && b.distanceInMeters == null) return 0;
          if (a.distanceInMeters == null) return 1;
          if (b.distanceInMeters == null) return -1;
          return a.distanceInMeters!.compareTo(b.distanceInMeters!);
        });
        break;
      default:
        // Default: sort by distance (nearest first)
        normal.sort((a, b) {
          if (a.distanceInMeters == null && b.distanceInMeters == null) return 0;
          if (a.distanceInMeters == null) return 1;
          if (b.distanceInMeters == null) return -1;
          return a.distanceInMeters!.compareTo(b.distanceInMeters!);
        });
        break;
    }
    
    // Combine: featured first, then normal
    return [...featured, ...normal];
  }

  Widget _buildListingList(
    List<Listing> listings,
    List<ListingWithDistance>? listingsWithDistance,
  ) {
    // Create a map for quick lookup
    final distanceMap = <String, ListingWithDistance>{};
    if (listingsWithDistance != null) {
      for (final lwd in listingsWithDistance) {
        distanceMap[lwd.listing.key.toString()] = lwd;
      }
    }

    if (listings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _selectedCategory != null
                  ? "No items found"
                  : "No ${widget.categoryTitle.toLowerCase()} available right now",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: listings.length,
      itemBuilder: (context, index) {
        final listing = listings[index];
        final listingWithDistance = distanceMap[listing.key.toString()];
        return BuyerListingCard(
          listing: listing,
          listingWithDistance: listingWithDistance,
        );
      },
    );
  }

  void _showFiltersDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters & Sort',
                  style: AppTheme.heading3,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Food Type Filter (only for food items)
            if (widget.sellType == SellType.cookedFood || widget.sellType == SellType.liveKitchen) ...[
              Text(
                'Food Type',
                style: AppTheme.heading4.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFilterChip('All', null, _selectedCategory == null, (v) {
                    setState(() => _selectedCategory = null);
                  }),
                  ...FoodCategory.values.map((cat) => _buildFilterChip(
                        cat.label,
                        cat,
                        _selectedCategory == cat,
                        (v) {
                          setState(() => _selectedCategory = cat);
                        },
                      )),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // Price Range
            Text(
              'Price Range',
              style: AppTheme.heading4.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Min',
                      prefixText: '₹',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (v) {
                      setState(() => _minPrice = double.tryParse(v) ?? 0);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Max',
                      prefixText: '₹',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (v) {
                      setState(() => _maxPrice = double.tryParse(v) ?? 10000);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Distance Filter
            Text(
              '📍 Distance Filter',
              style: AppTheme.heading4.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip('No Limit', null, _selectedDistanceKm == null, (v) {
                  setState(() => _selectedDistanceKm = null);
                }),
                ..._distanceOptions.map((distance) => _buildFilterChip(
                      '${distance.toStringAsFixed(0)} km',
                      distance,
                      _selectedDistanceKm == distance,
                      (v) {
                        setState(() => _selectedDistanceKm = distance);
                      },
                    )),
              ],
            ),
            const SizedBox(height: 12),
            // Custom Distance Slider
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Custom Distance: ${_selectedDistanceKm != null && _selectedDistanceKm! > 20 ? _selectedDistanceKm!.toStringAsFixed(1) : (_selectedDistanceKm?.toStringAsFixed(0) ?? "No limit")} km',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                Slider(
                  value: _selectedDistanceKm ?? 5.0,
                  min: 0.5,
                  max: 50.0,
                  divisions: 99,
                  label: _selectedDistanceKm != null
                      ? '${_selectedDistanceKm!.toStringAsFixed(1)} km'
                      : 'No limit',
                  onChanged: (value) {
                    setState(() {
                      _selectedDistanceKm = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Availability Filter
            SwitchListTile(
              title: const Text('Show only available items'),
              value: _showOnlyAvailable,
              onChanged: (value) {
                setState(() => _showOnlyAvailable = value);
              },
            ),
            const SizedBox(height: 8),

            // Sort Options
            Text(
              'Sort By',
              style: AppTheme.heading4.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip('Default', 'default', _sortOrder == 'default', (v) {
                  setState(() => _sortOrder = 'default');
                }),
                _buildFilterChip('Price: Low to High', 'price_low', _sortOrder == 'price_low', (v) {
                  setState(() => _sortOrder = 'price_low');
                }),
                _buildFilterChip('Price: High to Low', 'price_high', _sortOrder == 'price_high', (v) {
                  setState(() => _sortOrder = 'price_high');
                }),
                _buildFilterChip('Best Discount', 'discount', _sortOrder == 'discount', (v) {
                  setState(() => _sortOrder = 'discount');
                }),
                _buildFilterChip('Nearest', 'nearest', _sortOrder == 'nearest', (v) {
                  setState(() => _sortOrder = 'nearest');
                }),
                _buildFilterChip('Rating', 'rating', _sortOrder == 'rating', (v) {
                  setState(() => _sortOrder = 'rating');
                }),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Apply Filters'),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, dynamic value, bool selected, Function(dynamic) onSelected) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (s) => onSelected(value),
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: selected ? AppTheme.primaryColor : AppTheme.darkText,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryTitle),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search ${widget.categoryTitle.toLowerCase()}...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(
                    Icons.tune,
                    color: (_selectedCategory != null || _minPrice > 0 || _maxPrice < 10000 || _sortOrder != 'default' || _selectedDistanceKm != null)
                        ? AppTheme.primaryColor
                        : Colors.grey,
                  ),
                  onPressed: _showFiltersDialog,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),

          // Distance Filter Indicator
          if (_selectedDistanceKm != null && _useLocationFilter)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Within ${_selectedDistanceKm!.toStringAsFixed(0)} km',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() => _selectedDistanceKm = null);
                    },
                    child: Text(
                      'Remove',
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),

          // Active Filters
          if (_selectedCategory != null || _minPrice > 0 || _maxPrice < 10000 || _sortOrder != 'default')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.primaryColor.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.filter_alt, size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        if (_selectedCategory != null)
                          Chip(
                            label: Text(_selectedCategory!.label),
                            onDeleted: () {
                              setState(() => _selectedCategory = null);
                            },
                            deleteIcon: const Icon(Icons.close, size: 16),
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                          ),
                        if (_minPrice > 0 || _maxPrice < 10000)
                          Chip(
                            label: Text('₹$_minPrice - ₹$_maxPrice'),
                            onDeleted: () {
                              setState(() {
                                _minPrice = 0;
                                _maxPrice = 10000;
                              });
                            },
                            deleteIcon: const Icon(Icons.close, size: 16),
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                          ),
                        if (_sortOrder != 'default')
                          Chip(
                            label: Text(_sortOrder == 'price_low' 
                                ? 'Price: Low to High'
                                : _sortOrder == 'price_high'
                                    ? 'Price: High to Low'
                                    : _sortOrder == 'discount'
                                        ? 'Best Discount'
                                        : _sortOrder == 'nearest'
                                            ? 'Nearest'
                                            : _sortOrder == 'rating'
                                                ? 'Rating'
                                                : _sortOrder),
                            onDeleted: () {
                              setState(() => _sortOrder = 'default');
                            },
                            deleteIcon: const Icon(Icons.close, size: 16),
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Listings
          Expanded(
            child: ValueListenableBuilder<Box<Listing>>(
              valueListenable: Hive.box<Listing>('listingBox').listenable(),
              builder: (context, Box<Listing> box, _) {
                final allListings = box.values.toList();
                final filteredListings = _filterListings(allListings);
                final sortedListings = _sortListings(filteredListings);

                // Apply distance filtering if enabled
                if (_useLocationFilter && sortedListings.isNotEmpty) {
                  return FutureBuilder<List<ListingWithDistance>>(
                    future: DistanceFilterService.filterByDistance(
                      sortedListings,
                      customRadius: _selectedDistanceKm != null ? _selectedDistanceKm! * 1000 : null, // Convert km to meters
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        debugPrint('[CategoryListingScreen] Distance filter error: ${snapshot.error}');
                        // Fallback to showing all listings without distance
                        return _buildListingList(sortedListings, null);
                      }

                      final listingsWithDistance = snapshot.data ?? [];
                      
                      // Apply distance-based sorting with featured priority
                      final sortedWithDistance = _sortListingsWithDistance(listingsWithDistance);
                      
                      if (sortedWithDistance.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_off,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _selectedDistanceKm != null
                                    ? "No items found within ${_selectedDistanceKm!.toStringAsFixed(0)} km. Try increasing distance."
                                    : "No products nearby",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedDistanceKm = null;
                                  });
                                },
                                child: const Text('Remove distance filter'),
                              ),
                            ],
                          ),
                        );
                      }

                      return _buildListingList(
                        sortedWithDistance.map((lwd) => lwd.listing).toList(),
                        sortedWithDistance,
                      );
                    },
                  );
                }

                // No location filter - show all filtered listings
                return _buildListingList(sortedListings, null);
              },
            ),
          ),
        ],
      ),
    );
  }
}

