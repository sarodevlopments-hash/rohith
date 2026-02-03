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
import 'buyer_category_home_screen.dart';
import 'cart_screen.dart';
import 'buyer_orders_screen.dart';
import 'add_listing_screen.dart';
import 'seller_dashboard_screen.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;
  bool _isSellerMode = false;
  final ValueNotifier<int> _sellPromptCounter = ValueNotifier<int>(0);
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
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(Icons.shopping_cart_outlined, color: Colors.grey.shade700, size: 24),
                          if (count > 0)
                            Positioned(
                              right: -6,
                              top: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
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
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
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
    // with a minimal, professional-looking gap.
    NotificationService.pushBottomInset(32);
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
      backgroundColor: Colors.grey.shade50,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                // Mode Switch - More Prominent
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
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
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_isSellerMode ? Colors.orange : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: !_isSellerMode
                                  ? [
                                      BoxShadow(
                                        color: Colors.orange.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_bag,
                                  size: 20,
                                  color: !_isSellerMode ? Colors.white : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Buyer',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: !_isSellerMode ? FontWeight.bold : FontWeight.normal,
                                    color: !_isSellerMode ? Colors.white : Colors.grey.shade600,
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
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _isSellerMode ? Colors.orange : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _isSellerMode
                                  ? [
                                      BoxShadow(
                                        color: Colors.orange.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.store,
                                  size: 20,
                                  color: _isSellerMode ? Colors.white : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Seller',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: _isSellerMode ? FontWeight.bold : FontWeight.normal,
                                    color: _isSellerMode ? Colors.white : Colors.grey.shade600,
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
                const SizedBox(height: 12),
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
          title: const Text(
            "Food Marketplace",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
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
      } else {
        // Orders screen
        return AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          title: const Text(
            'My Orders',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          actions: [
            _buildCartAction(context),
          ],
        );
      }
    }
  }

  Widget _buildBuyerHomeTab() {
    return const BuyerCategoryHomeScreen();
  }

  List<Widget> _getSellerTabs() {
    final currentUser = FirebaseAuth.instance.currentUser;
    return [
      _buildSellerDashboardTab(currentUser?.uid ?? ''),
      _buildSellerAddListingTab(),
    ];
  }

  Widget _buildSellerAddListingTab() {
    // Wrap with bottom padding to avoid overlap with bottom nav
    return Padding(
      padding: const EdgeInsets.only(bottom: 120), // Space for bottom nav
      child: AddListingScreen(
        promptCounter: _sellPromptCounter,
        onBackToDashboard: () {
          setState(() {
            _currentIndex = 0; // Switch to Dashboard tab
          });
        },
      ),
    );
  }

  Widget _buildSellerDashboardTab(String sellerId) {
    // Wrap with bottom padding to avoid overlap with bottom nav
    return Padding(
      padding: const EdgeInsets.only(bottom: 120), // Space for bottom nav
      child: SellerDashboardScreen(sellerId: sellerId),
    );
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [Color(0xFF4A90E2), Color(0xFF7B68EE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isActive ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFF4A90E2).withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  icon,
                  color: isActive ? Colors.white : Colors.grey.shade500,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? const Color(0xFF4A90E2) : Colors.grey.shade600,
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

