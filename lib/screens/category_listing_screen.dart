import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/listing.dart';
import '../models/sell_type.dart';
import '../models/food_category.dart';
import '../widgets/buyer_listing_card.dart';
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
  String _sortOrder = 'default'; // 'default', 'price_low', 'price_high', 'discount'

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
                    color: (_selectedCategory != null || _minPrice > 0 || _maxPrice < 10000 || _sortOrder != 'default')
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
                                    : 'Best Discount'),
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

                if (sortedListings.isEmpty) {
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
                  itemCount: sortedListings.length,
                  itemBuilder: (context, index) {
                    return BuyerListingCard(
                      listing: sortedListings[index],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

