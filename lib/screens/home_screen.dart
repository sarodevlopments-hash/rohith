import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/listing.dart';
import '../models/sell_type.dart';
import '../models/food_category.dart';
import '../models/order.dart';
import '../widgets/buyer_listing_card.dart';
import 'add_listing_screen.dart';
import 'seller_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  FoodCategory? _selectedCategory;
  SellType? _selectedType;
  double _minPrice = 0;
  double _maxPrice = 10000;
  double _totalSavings = 0;

  @override
  void initState() {
    super.initState();
    _calculateTotalSavings();
    // Listen to orders box for savings updates
    Hive.box<Order>('ordersBox').listenable().addListener(_calculateTotalSavings);
  }

  @override
  void dispose() {
    Hive.box<Order>('ordersBox').listenable().removeListener(_calculateTotalSavings);
    _searchController.dispose();
    super.dispose();
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
      // Only count orders for the current user
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

  void _showFoodSafetyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Food Safety Policy",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Important Guidelines:",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 12),
                _buildPolicyItem(
                  Icons.check_circle,
                  Colors.green,
                  "All posted items must be in edible and safe condition",
                ),
                const SizedBox(height: 8),
                _buildPolicyItem(
                  Icons.check_circle,
                  Colors.green,
                  "Items should not cause any harm when consumed",
                ),
                const SizedBox(height: 8),
                _buildPolicyItem(
                  Icons.check_circle,
                  Colors.green,
                  "Comply with FSSAI (Food Safety and Standards Authority of India) regulations",
                ),
                const SizedBox(height: 8),
                _buildPolicyItem(
                  Icons.check_circle,
                  Colors.green,
                  "Follow proper food handling and storage guidelines",
                ),
                const SizedBox(height: 8),
                _buildPolicyItem(
                  Icons.check_circle,
                  Colors.green,
                  "Ensure accurate labeling and information disclosure",
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Text(
                    "By proceeding, you acknowledge that you have read and agree to comply with all food safety policies and government regulations.",
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddListingScreen(),
                  ),
                );
              },
              child: const Text("I Agree & Continue"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPolicyItem(IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  List<Listing> _filterListings(List<Listing> listings) {
    return listings.where((listing) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!listing.name.toLowerCase().contains(query) &&
            !listing.sellerName.toLowerCase().contains(query) &&
            !listing.type.name.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Category filter
      if (_selectedCategory != null && listing.category != _selectedCategory) {
        return false;
      }

      // Type filter
      if (_selectedType != null && listing.type != _selectedType) {
        return false;
      }

      // Price filter
      if (listing.price < _minPrice || listing.price > _maxPrice) {
        return false;
      }

      // Only show available items
      if (listing.quantity <= 0) {
        return false;
      }

      return true;
    }).toList();
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filters',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            // Category Filter
            const Text(
              'Food Type',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
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
            // Type Filter
            const Text(
              'Category',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildFilterChip('All', null, _selectedType == null, (v) {
                  setState(() => _selectedType = null);
                }),
                ...SellType.values.map((type) => _buildFilterChip(
                      type.name,
                      type,
                      _selectedType == type,
                      (v) {
                        setState(() => _selectedType = type);
                      },
                    )),
              ],
            ),
            const SizedBox(height: 20),
            // Price Range
            const Text(
              'Price Range',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Apply Filters'),
              ),
            ),
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
      selectedColor: Colors.orange.shade100,
      checkmarkColor: Colors.orange,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          "Food Marketplace",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Savings Banner
          if (_totalSavings > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.savings, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Total Savings",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          "₹${_totalSavings.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

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
                      hintText: 'Search food, groceries...',
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
                    color: (_selectedCategory != null || _selectedType != null)
                        ? Colors.orange
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
          if (_selectedCategory != null || _selectedType != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange.shade50,
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, size: 16, color: Colors.orange),
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
                          ),
                        if (_selectedType != null)
                          Chip(
                            label: Text(_selectedType!.name),
                            onDeleted: () {
                              setState(() => _selectedType = null);
                            },
                            deleteIcon: const Icon(Icons.close, size: 16),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Listings
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Hive.box<Listing>('listingBox').listenable(),
              builder: (context, Box<Listing> box, _) {
                final allListings = box.values.toList();
                final filteredListings = _filterListings(allListings);

                // Sort: nearby first (for now, just show all), then by discount
                filteredListings.sort((a, b) {
                  final discountA = a.originalPrice != null
                      ? ((a.originalPrice! - a.price) / a.originalPrice!) * 100
                      : 0;
                  final discountB = b.originalPrice != null
                      ? ((b.originalPrice! - b.price) / b.originalPrice!) * 100
                      : 0;
                  return discountB.compareTo(discountA); // Higher discount first
                });

                if (filteredListings.isEmpty) {
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
                          _searchQuery.isNotEmpty || _selectedCategory != null || _selectedType != null
                              ? "No items found"
                              : "No food available right now 🍽️",
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
                  itemCount: filteredListings.length,
                  itemBuilder: (context, index) {
                    return BuyerListingCard(
                      listing: filteredListings[index],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_circle_outline, size: 22),
                    label: const Text(
                      "Sell Food",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () {
                      _showFoodSafetyPolicyDialog(context);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.dashboard_outlined, size: 22),
                    label: const Text(
                      "Seller Dashboard",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () {
                      final currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SellerDashboardScreen(
                              sellerId: currentUser.uid,
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please log in to access dashboard')),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
