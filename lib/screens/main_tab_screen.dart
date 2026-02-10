import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/order.dart';
import '../services/notification_service.dart';
import '../services/order_sync_service.dart';
import '../services/accepted_order_notification_service.dart';
import '../services/listing_firestore_service.dart';
import '../services/firestore_verification_service.dart';
import '../services/location_service.dart';
import '../widgets/location_header_widget.dart';
import 'buyer_category_home_screen.dart';
import 'cart_screen.dart';
import 'buyer_orders_screen.dart';
import 'add_listing_screen.dart';
import 'seller_dashboard_screen.dart';
import 'location_selection_screen.dart';
import 'buyer_profile_screen.dart';
import '../theme/app_theme.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;
  bool _isSellerMode = false;
  final ValueNotifier<int> _sellPromptCounter = ValueNotifier<int>(0);
  final ValueNotifier<String?> _currentLocation = ValueNotifier<String?>(null);
  int _locationRefreshKey = 0; // Key to force home screen refresh
  late final ValueListenable<Box<Order>> _ordersListenable;
  VoidCallback? _ordersListener;

  Widget _buildCartAction(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('cartBox').listenable(),
      builder: (context, Box box, _) {
        final count = box.length;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                );
              },
              icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black87),
              label: const Text(
                'Cart',
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
              ),
            ),
            if (count > 0)
              Positioned(
                right: 6,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBottomCartShortcut(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('cartBox').listenable(),
      builder: (context, Box box, _) {
        final count = box.length;
        // Cart is always inactive in bottom nav (it navigates to separate screen)
        return Expanded(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.shopping_cart_outlined,
                          color: AppTheme.disabledText,
                          size: 22,
                        ),
                      ),
                      if (count > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cart',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.disabledText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // Keep seller/buyer SnackBars just above the custom bottom navigation bar,
    // with minimal spacing (8-12px gap).
    // Bottom inset: 15px
    NotificationService.pushBottomInset(15);
    // Start Firestore -> Hive sync for orders so buyer/seller status updates work in real time.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      OrderSyncService.start();
      
      // ✅ Verify Firestore database is accessible (diagnostic)
      Future.delayed(const Duration(milliseconds: 500), () {
        FirestoreVerificationService.printVerificationReport();
      });
      
      // ✅ Sync listings from Firestore on app start (after user is authenticated)
      // This restores listings that were saved to cloud, ensuring data persistence
      // Run in background without blocking UI
      Future.delayed(const Duration(milliseconds: 1000), () {
        ListingFirestoreService.syncListingsFromFirestore().catchError((e) {
          print('⚠️ Firestore listing sync failed (app will continue with local data): $e');
          // Don't block app if Firestore is unavailable - local Hive data will be used
        });
      });
    });
    _ordersListenable = Hive.box<Order>('ordersBox').listenable();
    _ordersListener = () {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null && mounted) {
        // Always check for seller notifications (new orders) regardless of tab
        // This ensures sellers see notifications even when browsing as buyers
        NotificationService.checkForNewOrders(context, userId);
        // Also check for buyer notifications (accepted orders) - use persistent notification
        AcceptedOrderNotificationService.checkForAcceptedOrders(context);
      }
    };
    _ordersListenable.addListener(_ordersListener!);
    // Trigger a single initial check after first frame; subsequent checks come from the Hive listener.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ordersListener?.call());
  }

  @override
  void dispose() {
    NotificationService.popBottomInset();
    if (_ordersListener != null) {
      _ordersListenable.removeListener(_ordersListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _isSellerMode ? null : _buildAppBar(), // Only show AppBar in buyer mode
      body: IndexedStack(
        index: _currentIndex,
        children: _isSellerMode ? _getSellerTabs() : _getBuyerTabs(),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                // Mode Switch - Premium Gradient Design
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderColor, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isSellerMode = false;
                              _currentIndex = 0;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              gradient: !_isSellerMode ? AppTheme.primaryGradient : null,
                              color: _isSellerMode ? Colors.transparent : null,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: !_isSellerMode
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.teal.withOpacity(0.25),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                        spreadRadius: -2,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_bag_rounded,
                                  size: 20,
                                  color: !_isSellerMode ? Colors.white : AppTheme.disabledText,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Buyer',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: !_isSellerMode ? FontWeight.w700 : FontWeight.w500,
                                    color: !_isSellerMode ? Colors.white : AppTheme.disabledText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isSellerMode = true;
                              _currentIndex = 0;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              gradient: _isSellerMode ? AppTheme.primaryGradient : null,
                              color: !_isSellerMode ? Colors.transparent : null,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _isSellerMode
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.teal.withOpacity(0.25),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                        spreadRadius: -2,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.store_rounded,
                                  size: 20,
                                  color: _isSellerMode ? Colors.white : AppTheme.disabledText,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Seller',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: _isSellerMode ? FontWeight.w700 : FontWeight.w500,
                                    color: _isSellerMode ? Colors.white : AppTheme.disabledText,
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
                const SizedBox(height: 4),
                // Tab Navigation
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: _isSellerMode
                      ? _buildSellerTabs()
                      : [
                          ..._buildBuyerTabs(),
                          _buildBottomCartShortcut(context),
                        ],
                ),
              ],
            ),
          ),
        ),
      );
  }


  List<Widget> _getBuyerTabs() {
    return [
      _buildBuyerHomeTab(),
      _buildBuyerOrdersTab(),
      _buildBuyerProfileTab(),
    ];
  }

  Widget _buildBuyerOrdersTab() {
    return Builder(
      builder: (context) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          return const Center(child: Text('Please log in to view orders'));
        }
        // Return just the body content, not the Scaffold
        return const BuyerOrdersContent();
      },
    );
  }

  Widget _buildBuyerProfileTab() {
    return const BuyerProfileScreen();
  }

  PreferredSizeWidget? _buildAppBar() {
    if (_isSellerMode) {
      // Seller mode - screens have their own AppBars, so return null
      return null;
    } else {
      // Buyer mode
      if (_currentIndex == 0) {
        // Home screen
        return AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Food Marketplace",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 2),
              LocationHeaderWidget(
                onLocationChanged: (address) {
                  _currentLocation.value = address;
                  // Trigger product refresh when location changes
                  LocationService.clearCache();
                  // Force home screen refresh by updating key
                  if (mounted) {
                    setState(() {
                      _locationRefreshKey++;
                    });
                  }
                },
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LocationSelectionScreen(),
                    ),
                  );
                  if (result != null && mounted) {
                    _currentLocation.value = result;
                    LocationService.clearCache();
                    // Force home screen refresh by updating key
                    setState(() {
                      _locationRefreshKey++;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            _buildCartAction(context),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black87),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
            ),
          ],
        );
      } else if (_currentIndex == 1) {
        // Orders screen
        return AppBar(
          elevation: 0,
          backgroundColor: AppTheme.cardColor,
          title: Text(
            'My Orders',
            style: AppTheme.heading3.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            _buildCartAction(context),
          ],
        );
      } else {
        // Profile screen - no AppBar needed (has its own)
        return null;
      }
    }
  }

  Widget _buildBuyerHomeTab() {
    // Use key to force rebuild when location changes
    return BuyerCategoryHomeScreen(key: ValueKey('home_$_locationRefreshKey'));
  }

  List<Widget> _getSellerTabs() {
    final currentUser = FirebaseAuth.instance.currentUser;
    return [
      _buildSellerDashboardTab(currentUser?.uid ?? ''),
      _buildSellerAddListingTab(),
    ];
  }

  Widget _buildSellerAddListingTab() {
    // No wrapper padding - match buyer screens structure
    // Internal padding in AddListingScreen handles spacing
    return AddListingScreen(
      promptCounter: _sellPromptCounter,
      onBackToDashboard: () {
        setState(() {
          _currentIndex = 0; // Switch to Dashboard tab
        });
      },
    );
  }

  Widget _buildSellerDashboardTab(String sellerId) {
    // No wrapper padding - match buyer screens structure
    // Internal padding in SellerDashboardScreen handles spacing
    return SellerDashboardScreen(sellerId: sellerId);
  }

  List<Widget> _buildBuyerTabs() {
    return [
      _buildTabButton(
        icon: Icons.home,
        label: 'Home',
        isActive: _currentIndex == 0,
        onTap: () => setState(() => _currentIndex = 0),
      ),
      _buildTabButton(
        icon: Icons.shopping_bag,
        label: 'Orders',
        isActive: _currentIndex == 1,
        onTap: () => setState(() => _currentIndex = 1),
      ),
      _buildTabButton(
        icon: Icons.person_outline,
        label: 'Profile',
        isActive: _currentIndex == 2,
        onTap: () => setState(() => _currentIndex = 2),
      ),
    ];
  }

  List<Widget> _buildSellerTabs() {
    return [
      _buildTabButton(
        icon: Icons.dashboard,
        label: 'Dashboard',
        isActive: _currentIndex == 0,
        onTap: () => setState(() => _currentIndex = 0),
      ),
      _buildTabButton(
        icon: Icons.add_circle_outline,
        label: 'Start Selling',
        isActive: _currentIndex == 1,
        onTap: () {
          setState(() => _currentIndex = 1);
          _sellPromptCounter.value++;
        },
      ),
    ];
  }

  Widget _buildTabButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: isActive ? AppTheme.primaryGradient : null,
                  color: isActive ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppTheme.teal.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                            spreadRadius: -1,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  icon,
                  color: isActive ? Colors.white : AppTheme.disabledText,
                  size: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppTheme.teal : AppTheme.disabledText,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

