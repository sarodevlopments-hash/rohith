import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/listing.dart';
import '../models/order.dart';
import '../models/seller_review.dart';
import '../services/seller_review_service.dart';
import 'seller_transactions_screen.dart';
import 'seller_item_insights_screen.dart';
import 'seller_reviews_screen.dart';
import 'seller_item_management_screen.dart';
import 'grocery_onboarding_screen.dart';
import '../services/notification_service.dart';
import '../services/order_firestore_service.dart';
import '../services/web_order_broadcast.dart';
import '../services/seller_profile_service.dart';
import '../services/otp_service.dart';
import '../theme/app_theme.dart';
import '../models/sell_type.dart';
import '../models/seller_profile.dart';

class SellerDashboardScreen extends StatefulWidget {
  final String sellerId;
  final void Function(SellType type)? onSwitchToSelling;

  const SellerDashboardScreen({super.key, required this.sellerId, this.onSwitchToSelling});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  String _selectedTimeRange = 'Daily'; // Daily, Weekly, Monthly, Custom
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  /// Get the effective seller ID, falling back to FirebaseAuth if widget.sellerId is empty
  String get _effectiveSellerId {
    if (widget.sellerId.isNotEmpty) {
      return widget.sellerId;
    }
    // Fallback to FirebaseAuth
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser?.uid ?? '';
  }

  @override
Widget build(BuildContext context) {
  // Validate sellerId
  if (_effectiveSellerId.isEmpty) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.cardColor,
        title: Text(
          'Seller Dashboard',
          style: AppTheme.heading3.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
              const SizedBox(height: 16),
              Text(
                'Seller ID is missing',
                style: AppTheme.heading3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please log in again to access the seller dashboard.',
                style: AppTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  // Force rebuild to check auth state again
                  setState(() {});
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  return Scaffold(
      backgroundColor: AppTheme.backgroundColor, // Premium pastel background
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.cardColor,
        toolbarHeight: 44,
        title: Text(
          'Seller Dashboard',
          style: AppTheme.heading3.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppTheme.darkText, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() {}),
          ),
          const SizedBox(width: 8),
        ],
      ),
    body: Builder(
      builder: (context) {
        try {
          final ordersBox = Hive.box<Order>('ordersBox');
          final listingBox = Hive.box<Listing>('listingBox');
          
          return ValueListenableBuilder(
            valueListenable: ordersBox.listenable(),
        builder: (context, Box<Order> ordersBox, _) {
          // Check for new orders when orders box changes (immediately, not just post-frame)
          NotificationService.checkForNewOrders(context, _effectiveSellerId);
          
          return ValueListenableBuilder(
                valueListenable: listingBox.listenable(),
            builder: (context, Box<Listing> listingBox, _) {
                  try {
              final myListings = listingBox.values
.where((l) => l.sellerId == _effectiveSellerId)
                  .toList();

              // Filter orders by sellerId (new field) or by listing sellerId (backward compatibility)
              final myOrders = ordersBox.values
                  .where((order) {
                    // First check if order has sellerId field (new orders)
                    if (order.sellerId.isNotEmpty && order.sellerId == _effectiveSellerId) {
                      return true;
                    }
                    // Fallback: check via listing (for old orders)
                    try {
                      final listingKey = int.tryParse(order.listingId);
                      if (listingKey != null) {
                        final listing = listingBox.get(listingKey);
                        return listing?.sellerId == _effectiveSellerId;
                      }
                    } catch (e) {
                      return false;
                    }
                    return false;
                  })
                  .toList();

              final metrics = _calculateMetrics(myOrders, myListings, _selectedTimeRange, _customStartDate, _customEndDate);
              final chartData = _getChartData(myOrders, _selectedTimeRange, _customStartDate, _customEndDate);

              return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), // Generous padding for professional layout
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
            children: [
                          // Key Metrics Cards - 2x2 Grid
                          _buildKPIGrid(metrics, myOrders),
                          const SizedBox(height: 28),

                          // Orders Section
                    _buildPendingOrdersSection(myOrders),
                    const SizedBox(height: 24),
                    
                    // Live Kitchen Orders
                    _buildLiveKitchenOrdersSection(myOrders),
                          const SizedBox(height: 28),

                          // Sales Overview Chart (with time range selector)
                          _buildSalesChart(chartData),
                          const SizedBox(height: 28),

                          // Top Items Section
                    _buildItemInsightsSection(myListings, myOrders),
                          const SizedBox(height: 28),

                    // Reviews Section
                    _buildReviewsSection(),
                          const SizedBox(height: 24),

                          // Quick Actions (at bottom)
                          _buildQuickActions(),
                          const SizedBox(height: 16),
                          _buildGroceryOnboardingCard(),
                          const SizedBox(height: 16),
                          _buildItemManagementSection(),
                  ],
                ),
              );
                  } catch (e) {
                    debugPrint('Error building seller dashboard content: $e');
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading dashboard',
                              style: AppTheme.heading3,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Error: $e',
                              style: AppTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
              );
            },
          );
        } catch (e) {
          debugPrint('Error accessing Hive boxes: $e');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                  const SizedBox(height: 16),
                  Text(
                    'Unable to load dashboard',
                    style: AppTheme.heading3,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please restart the app. Error: $e',
                    style: AppTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        },
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: AppTheme.getCardDecoration(elevated: true),
      child: Row(
        children: [
          _buildTimeRangeChip('Daily', _selectedTimeRange == 'Daily'),
          _buildTimeRangeChip('Weekly', _selectedTimeRange == 'Weekly'),
          _buildTimeRangeChip('Monthly', _selectedTimeRange == 'Monthly'),
          _buildTimeRangeChip('Custom', _selectedTimeRange == 'Custom'),
        ],
      ),
    );
  }

  Widget _buildTimeRangeChip(String label, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTimeRange = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected ? AppTheme.primaryGradient : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.teal.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : AppTheme.lightText,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? date,
    required Function(DateTime) onDateSelected,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          onDateSelected(picked);
        }
      },
      child: Container(
                  padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 20),
            const SizedBox(width: 12),
            Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                      Text(
                    date != null
                        ? '${date.day}/${date.month}/${date.year}'
                        : 'Select date',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: date != null ? FontWeight.w600 : FontWeight.normal,
                      color: date != null ? Colors.black87 : Colors.grey.shade400,
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

  // Premium 2x2 KPI Grid Layout
  Widget _buildKPIGrid(Map<String, dynamic> metrics, List<Order> orders) {
    // Count pending orders
    final pendingCount = orders.where((o) {
      if (o.isLiveKitchenOrder ?? false) return false;
      return o.orderStatus == 'PaymentCompleted' || 
             o.orderStatus == 'AwaitingSellerConfirmation' ||
             o.orderStatus == 'PaymentPending';
    }).length;
    
    // Count live kitchen orders
    final liveKitchenCount = orders.where((o) => 
      (o.isLiveKitchenOrder ?? false) || 
      ['OrderReceived', 'Preparing', 'ReadyForPickup', 'ReadyForDelivery'].contains(o.orderStatus)
    ).length;
    
    // Get time range text for subtext
    String timeRangeText = 'This ${_selectedTimeRange.toLowerCase()}';
    if (_selectedTimeRange == 'Custom' && _customStartDate != null && _customEndDate != null) {
      timeRangeText = 'Custom range';
    }
    
    return Column(
      children: [
        // Row 1: Total Orders & Total Revenue
        Row(
      children: [
        Expanded(
              child: _buildKPICard(
                icon: Icons.shopping_cart_rounded,
                title: 'Total Orders',
                value: metrics['totalOrders'].toString(),
                subtext: timeRangeText,
                iconGradient: LinearGradient(
                  colors: [AppTheme.teal, AppTheme.softGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
              child: _buildKPICard(
                icon: Icons.currency_rupee_rounded,
                title: 'Total Revenue',
                value: '₹${metrics['totalRevenue'].toStringAsFixed(0)}',
                subtext: timeRangeText,
                iconGradient: LinearGradient(
                  colors: [AppTheme.badgeRecommended, AppTheme.teal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 2: Pending Orders & Live Kitchen
        Row(
          children: [
            Expanded(
              child: _buildKPICard(
                icon: Icons.pending_actions_rounded,
                title: 'Pending Orders',
                value: pendingCount.toString(),
                subtext: pendingCount == 0 ? 'No action required' : 'Need your attention',
                iconGradient: LinearGradient(
                  colors: [AppTheme.badgeOffer, AppTheme.badgeOffer.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKPICard(
                icon: Icons.local_dining_rounded,
                title: 'Live Kitchen',
                value: liveKitchenCount.toString(),
                subtext: liveKitchenCount == 0 ? 'No active orders' : 'Active orders',
                iconGradient: LinearGradient(
                  colors: [AppTheme.softGreen, AppTheme.aqua],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Professional KPI Card - Circular Icon Container, Clean Design
  Widget _buildKPICard({
    required IconData icon,
    required String title,
    required String value,
    String? subtext,
    required LinearGradient iconGradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular icon container with soft colored background
              Container(
            width: 48,
            height: 48,
                decoration: BoxDecoration(
              gradient: iconGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.teal.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
              ),
            ],
          ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 16),
          // KPI Title (small, muted text)
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: const Color(0xFF6B7280), // Muted gray
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 8),
          // KPI Value (large, bold)
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2937), // Dark gray
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          // Optional subtext (helper/status text)
          if (subtext != null) ...[
            const SizedBox(height: 6),
            Text(
              subtext,
              style: TextStyle(
                fontSize: 11,
                color: const Color(0xFF9CA3AF), // Light muted gray
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSalesChart(Map<String, List<double>> chartData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time Range Selector (above chart)
        _buildTimeRangeSelector(),
        if (_selectedTimeRange == 'Custom') ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDatePicker(
                  label: 'From Date',
                  date: _customStartDate,
                  onDateSelected: (date) => setState(() => _customStartDate = date),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDatePicker(
                  label: 'To Date',
                  date: _customEndDate,
                  onDateSelected: (date) => setState(() => _customEndDate = date),
                ),
              ),
            ],
          ),
          if (_customStartDate == null || _customEndDate == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Please select both start and end dates',
                style: TextStyle(
                  color: const Color(0xFFFFB703),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
        const SizedBox(height: 20),
        // Chart Container
        if (chartData.isEmpty)
          Container(
        height: 200,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
        ),
        child: Center(
          child: Text(
            'No sales data available',
                style: TextStyle(
                  fontSize: 14,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ),
          )
        else
          Builder(
            builder: (context) {
    final labels = chartData.keys.toList();
    final values = chartData.values.map((v) => v[0]).toList();
    final maxValue = values.isEmpty ? 100.0 : values.reduce((a, b) => a > b ? a : b) * 1.2;
    
    // Ensure horizontalInterval is never zero (fl_chart requirement)
    final horizontalInterval = maxValue > 0 ? (maxValue / 5).clamp(1.0, double.infinity) : 1.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
          ),
        ],
      ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // Section Title
                    Text(
            'Sales Overview',
            style: TextStyle(
              fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1F2937), // Dark gray
            ),
          ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValue,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < labels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              labels[index],
                              style: TextStyle(
                                          fontSize: 11,
                                          color: const Color(0xFF6B7280), // Muted gray
                                          fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                                reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Text(
                          '₹${value.toInt()}',
                          style: TextStyle(
                            fontSize: 10,
                                        color: const Color(0xFF9CA3AF), // Light muted gray
                                        fontWeight: FontWeight.w500,
                                      ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: horizontalInterval,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: const Color(0xFFE5E7EB), // Light gray grid lines
                                strokeWidth: 1,
                              );
                            },
                ),
                borderData: FlBorderData(show: false),
                barGroups: values.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value,
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.teal, // Teal/Mint accent
                                      AppTheme.aqua,
                                    ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                  width: 24,
                        borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildPendingOrdersSection(List<Order> orders) {
    // Debug: Print all orders received
    // Filter for regular orders (not Live Kitchen) that are pending
    // Also exclude orders with Live Kitchen statuses (OrderReceived, Preparing, etc.) even if flag isn't set
    final liveKitchenStatuses = ['OrderReceived', 'Preparing', 'ReadyForPickup', 'ReadyForDelivery'];
    
    // Get all regular orders (not Live Kitchen)
    final allRegularOrders = orders.where((o) {
      final isLiveKitchen = (o.isLiveKitchenOrder ?? false) || liveKitchenStatuses.contains(o.orderStatus);
      return !isLiveKitchen;
    }).toList();
    
    // Filter for orders that need seller action (pending acceptance/rejection)
    final pendingOrders = allRegularOrders.where((o) => 
      // Include orders that are waiting for seller confirmation
      o.orderStatus == 'PaymentCompleted' || 
      o.orderStatus == 'AwaitingSellerConfirmation' ||
      o.orderStatus == 'PaymentPending'
    ).toList()..sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));
    
    // Also show orders that might have been created with wrong status but need action
    // This is a fallback to catch any edge cases
    final ordersNeedingAction = allRegularOrders.where((o) =>
      // Show orders that haven't been accepted/rejected yet
      o.orderStatus != 'AcceptedBySeller' &&
      o.orderStatus != 'RejectedBySeller' &&
      o.orderStatus != 'Confirmed' &&
      o.orderStatus != 'Completed' &&
      o.orderStatus != 'Cancelled'
    ).toList();
    
    // If no pending orders but there are orders needing action, show those instead
    final ordersToShow = pendingOrders.isNotEmpty ? pendingOrders : ordersNeedingAction;

    // ALWAYS show the section header, even if empty
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTheme.buildSectionHeader(
          title: 'Pending Orders',
          subtitle: ordersToShow.isEmpty ? 'No orders awaiting approval' : '${ordersToShow.length} order(s) need your attention',
          icon: Icons.pending_actions_rounded,
          iconColor: AppTheme.badgeOffer, // Amber for pending
        ),
        const SizedBox(height: 12),
        
        // Show pending orders if any
        if (ordersToShow.isNotEmpty) ...[
          if (pendingOrders.isEmpty && ordersNeedingAction.isNotEmpty) ...[
            // Premium warning card with accent strip
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: AppTheme.getCardDecoration(elevated: true),
              child: Stack(
                children: [
                  // Amber accent strip at left
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 4,
              decoration: BoxDecoration(
                        color: AppTheme.badgeOffer,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(18),
                          bottomLeft: Radius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.badgeOffer.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.info_outline_rounded, color: AppTheme.badgeOffer, size: 20),
                        ),
                        const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                            'Showing ${ordersNeedingAction.length} order(s) that need seller action',
                            style: AppTheme.bodySmall.copyWith(
                              fontSize: 12,
                              color: AppTheme.darkText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          ...ordersToShow.take(5).map((order) => _buildPendingOrderCard(order)),
        ] else ...[
          // Professional Empty State - Informative, not blank
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB), // Light amber tint for pending section
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFFFE4B5).withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB703).withOpacity(0.15), // Amber
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.info_outline_rounded,
                        color: const Color(0xFFFFB703), // Amber
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                      'No Pending Orders',
                      style: TextStyle(
                        fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2937), // Dark gray
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'All orders have been processed. When new orders arrive, they will appear here with Accept/Reject buttons for quick action.',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF6B7280), // Muted gray
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'To test Accept/Reject buttons:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '1. Create a REGULAR listing (not Live Kitchen)\n2. Place an order from that listing\n3. The order will appear here with Accept/Reject buttons',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Show count of regular orders that aren't pending
                      Builder(
                        builder: (context) {
                          final allRegularOrders = orders.where((o) {
                            final liveKitchenStatuses = ['OrderReceived', 'Preparing', 'ReadyForPickup', 'ReadyForDelivery'];
                            return !(o.isLiveKitchenOrder ?? false) && !liveKitchenStatuses.contains(o.orderStatus);
                          }).toList();
                          if (allRegularOrders.isNotEmpty) {
                            final statusCounts = <String, int>{};
                            for (var order in allRegularOrders) {
                              statusCounts[order.orderStatus] = (statusCounts[order.orderStatus] ?? 0) + 1;
                            }
                            return Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'You have ${allRegularOrders.length} regular order(s) with these statuses:',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ...statusCounts.entries.map((e) => Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      '• ${e.key}: ${e.value}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  )),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPendingOrderCard(Order order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFB703).withOpacity(0.2), // Amber border for pending
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.foodName,
                        style: TextStyle(
                        fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2937), // Dark gray
                      ),
                    ),
                      const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Order ID: ${order.orderId.substring(order.orderId.length - 6)}',
                          style: TextStyle(
                            fontSize: 12,
                              color: const Color(0xFF6B7280), // Muted gray
                            ),
                          ),
                          const SizedBox(width: 10),
                          _buildStatusBadge(order.orderStatus),
                        ],
                      ),
                      const SizedBox(height: 8),
                    Text(
                      'Qty: ${order.quantity} × ₹${order.discountedPrice.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${order.pricePaid.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.teal, // Teal accent
                      ),
                    ),
                    const SizedBox(height: 6),
                  Text(
                    order.purchasedAt.toLocal().toString().split(' ')[0],
                    style: TextStyle(
                        fontSize: 11,
                        color: const Color(0xFF9CA3AF), // Light muted gray
                    ),
                  ),
                ],
              ),
            ],
          ),
            const SizedBox(height: 20),
            Divider(
              height: 1,
              thickness: 1,
              color: const Color(0xFFE5E7EB), // Light gray divider
            ),
            const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildSecondaryButton(
                    icon: Icons.close_rounded,
                    label: 'Reject',
                  onPressed: () => _rejectOrder(order),
                    isDanger: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                  child: _buildPrimaryButton(
                    icon: Icons.check_rounded,
                    label: 'Accept Order',
                  onPressed: () => _acceptOrder(order),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Premium Status Badge Helper
  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    String displayText;
    
    switch (status) {
      case 'Completed':
        badgeColor = const Color(0xFF6BCF9E); // Soft green
        displayText = 'Completed';
        break;
      case 'AcceptedBySeller':
      case 'Confirmed':
        badgeColor = AppTheme.softGreen;
        displayText = 'Accepted';
        break;
      case 'Pending':
      case 'PaymentPending':
      case 'AwaitingSellerConfirmation':
      case 'PaymentCompleted':
        badgeColor = AppTheme.badgeOffer; // Amber
        displayText = 'Pending';
        break;
      case 'Cancelled':
      case 'RejectedBySeller':
        badgeColor = AppTheme.badgeDiscount; // Soft coral
        displayText = status == 'Cancelled' ? 'Cancelled' : 'Rejected';
        break;
      default:
        badgeColor = AppTheme.lightText;
        displayText = status;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: badgeColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 10,
          color: badgeColor,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // Premium Primary Button with Gradient
  Widget _buildPrimaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: AppTheme.getPrimaryButtonDecoration(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Premium Secondary Button with Gradient Border
  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isDanger = false,
  }) {
    final borderColor = isDanger ? AppTheme.badgeDiscount : AppTheme.teal;
    final textColor = isDanger ? AppTheme.badgeDiscount : AppTheme.teal;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _acceptOrder(Order order) async {
    try {
      // Dismiss notification immediately before updating status
      NotificationService.dismissNotificationForOrder(order.orderId, context);
      
      // Generate OTP for pickup verification
      final otp = OtpService.generateOtp();
      
      // For non-Live Kitchen orders: Accepted → ReadyForPickup (with OTP)
      // For Live Kitchen orders: Accepted → Preparing (no OTP yet, OTP generated when ReadyForPickup)
      final isLiveKitchen = order.isLiveKitchenOrder ?? false;
      final newStatus = isLiveKitchen ? 'Preparing' : 'ReadyForPickup';
      
      order.orderStatus = newStatus;
      order.sellerRespondedAt = DateTime.now();
      
      // Set OTP fields only for non-Live Kitchen (Live Kitchen gets OTP when moving to ReadyForPickup)
      if (!isLiveKitchen) {
        // Note: Order model fields are final, so we need to update via Firestore
        // We'll update the order in Hive and Firestore separately
        await order.save();
        
        // Update Firestore with status and OTP
        await OrderFirestoreService.updateMeta(order.orderId, {
          'orderStatus': newStatus,
          'sellerRespondedAt': order.sellerRespondedAt?.toUtc(),
          'pickupOtp': otp,
          'otpStatus': 'pending',
        });
      } else {
        // Live Kitchen: just update status to Preparing
        await order.save();
        await OrderFirestoreService.updateStatus(
          orderId: order.orderId,
          status: newStatus,
          sellerRespondedAt: order.sellerRespondedAt,
        );
      }
      
      // Ensure seller details are saved to Firestore
      try {
        final sellerProfile = await SellerProfileService.getProfile(order.sellerId);
        if (sellerProfile != null) {
          await OrderFirestoreService.updateMeta(order.orderId, {
            'sellerPhone': sellerProfile.phoneNumber,
            'sellerPickupLocation': sellerProfile.pickupLocation,
          });
        }
      } catch (e) {
        // Non-critical error, continue anyway
        print('Failed to update seller details: $e');
      }
      
      WebOrderBroadcast.postStatus(orderId: order.orderId, status: newStatus);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isLiveKitchen 
              ? 'Order accepted! Start preparing...'
              : 'Order accepted! OTP generated: $otp'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildLiveKitchenOrdersSection(List<Order> orders) {
    // Live Kitchen statuses
    final liveKitchenStatuses = ['OrderReceived', 'Preparing', 'ReadyForPickup', 'ReadyForDelivery'];
    
    // Filter for Live Kitchen orders: either has the flag set OR has a Live Kitchen status
    // This ensures orders show up even if the flag wasn't set correctly
    final liveKitchenOrders = orders.where((o) {
      final hasLiveKitchenFlag = o.isLiveKitchenOrder ?? false;
      final hasLiveKitchenStatus = liveKitchenStatuses.contains(o.orderStatus);
      // Include if either flag is set OR status indicates Live Kitchen
      return hasLiveKitchenFlag || hasLiveKitchenStatus;
    }).toList()..sort((a, b) {
      // Sort by status priority, then by time
      final statusPriority = {
        'OrderReceived': 1,
        'Preparing': 2,
        'ReadyForPickup': 3,
        'ReadyForDelivery': 3,
      };
      final aPriority = statusPriority[a.orderStatus] ?? 99;
      final bPriority = statusPriority[b.orderStatus] ?? 99;
      if (aPriority != bPriority) return aPriority.compareTo(bPriority);
      return b.purchasedAt.compareTo(a.purchasedAt);
    });

    // Always show the section, even if empty (with helpful message)
    if (liveKitchenOrders.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTheme.buildSectionHeader(
            title: 'Live Kitchen Orders',
            subtitle: liveKitchenOrders.isEmpty ? 'No active Live Kitchen orders' : '${liveKitchenOrders.length} active order(s)',
            icon: Icons.local_dining_rounded,
            iconColor: AppTheme.softGreen, // Soft green for Live Kitchen
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4), // Light green tint for Live Kitchen section
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFBBF7D0).withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15), // Soft green
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.info_outline_rounded,
                        color: const Color(0xFF10B981), // Soft green
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                      'No Live Kitchen Orders',
                      style: TextStyle(
                        fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2937), // Dark gray
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Live Kitchen orders will appear here when buyers place orders on your Live Kitchen listings. You can track their progress from OrderReceived → Preparing → ReadyForPickup.',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF6B7280), // Muted gray
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Kitchen Order Flow:',
                        style: AppTheme.bodySmall.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '1. Buyer places order → Status: "OrderReceived"\n2. You accept → Status: "Preparing"\n3. Food ready → Status: "ReadyForPickup"\n4. Order completed → Status: "Completed"',
                        style: AppTheme.bodySmall.copyWith(
                          fontSize: 11,
                          color: AppTheme.lightText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Calculate metrics - only count accepted Live Kitchen orders (not 'OrderReceived')
    // Include orders with Live Kitchen statuses even if flag isn't set
    final totalLiveKitchenOrders = orders.where((o) {
      final hasLiveKitchenFlag = o.isLiveKitchenOrder ?? false;
      final hasLiveKitchenStatus = ['Preparing', 'ReadyForPickup', 'ReadyForDelivery', 'Completed'].contains(o.orderStatus);
      return (hasLiveKitchenFlag || hasLiveKitchenStatus) && hasLiveKitchenStatus;
    }).length;
    final totalLiveKitchenEarnings = orders
        .where((o) {
          final hasLiveKitchenFlag = o.isLiveKitchenOrder ?? false;
          final hasLiveKitchenStatus = o.orderStatus == 'Completed';
          // For completed orders, check if it was a Live Kitchen order by flag or by checking if it had Live Kitchen statuses before
          return (hasLiveKitchenFlag || hasLiveKitchenStatus) && o.orderStatus == 'Completed';
        })
        .fold<double>(0, (sum, o) => sum + o.pricePaid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade400, Colors.green.shade600],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.restaurant, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  '🔥 Live Kitchen Orders',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${liveKitchenOrders.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Summary cards
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Orders',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                    Text(
                      '$totalLiveKitchenOrders',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Earnings',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    Text(
                      '₹${totalLiveKitchenEarnings.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...liveKitchenOrders.take(5).map((order) => _buildLiveKitchenOrderCard(order)),
      ],
    );
  }

  Widget _buildLiveKitchenOrderCard(Order order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: order.statusColor.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: order.statusColor.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.foodName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Order ID: ${order.orderId.substring(order.orderId.length - 6)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: order.statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            order.statusDisplayText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: order.statusColor,
                            ),
                          ),
                        ),
                        if (order.preparationTimeMinutes != null) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.timer, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            '${order.preparationTimeMinutes} mins',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${order.pricePaid.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: order.statusColor,
                    ),
                  ),
                  Text(
                    _formatTime(order.purchasedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Debug info (temporary - can be removed later)
          if (order.orderStatus == 'OrderReceived') ...[
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'New order received! Accept to start preparing.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Accept/Reject buttons for new Live Kitchen orders
          if (order.orderStatus == 'OrderReceived') ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectOrder(order),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _updateLiveKitchenOrderStatus(order, 'Preparing'),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accept & Start Preparing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (order.orderStatus == 'Preparing') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _updateLiveKitchenOrderStatus(order, 'ReadyForPickup'),
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text('Mark Ready for Pickup'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ] else if (order.orderStatus == 'ReadyForPickup' || order.orderStatus == 'ReadyForDelivery') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showOtpVerificationDialog(order),
                icon: const Icon(Icons.verified_user, size: 18),
                label: const Text('Verify Pickup OTP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _updateLiveKitchenOrderStatus(Order order, String newStatus) async {
    try {
      // Generate OTP when moving to ReadyForPickup
      String? otp;
      if (newStatus == 'ReadyForPickup') {
        otp = OtpService.generateOtp();
      }
      
      order.orderStatus = newStatus;
      order.statusChangedAt = DateTime.now();
      await order.save();
      
      // Update Firestore with status and OTP (if applicable)
      if (otp != null) {
        await OrderFirestoreService.updateMeta(order.orderId, {
          'orderStatus': newStatus,
          'sellerRespondedAt': order.statusChangedAt?.toUtc(),
          'pickupOtp': otp,
          'otpStatus': 'pending',
        });
      } else {
        await OrderFirestoreService.updateStatus(
          orderId: order.orderId,
          status: newStatus,
          sellerRespondedAt: order.statusChangedAt,
        );
      }
      
      WebOrderBroadcast.postStatus(orderId: order.orderId, status: newStatus);

      // If order is completed, free up capacity
      if (newStatus == 'Completed') {
        final listingBox = Hive.box<Listing>('listingBox');
        final listingKey = int.tryParse(order.listingId);
        if (listingKey != null) {
          final listing = listingBox.get(listingKey);
          if (listing != null && listing.isLiveKitchen) {
            listing.completeLiveKitchenOrder();
            await listing.save();
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(otp != null 
              ? 'Order ready! OTP generated: $otp'
              : 'Order status updated to: ${order.statusDisplayText}'),
            backgroundColor: Colors.green,
            duration: otp != null ? const Duration(seconds: 4) : const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update order status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return dateTime.toLocal().toString().split(' ')[0];
  }

  /// Show OTP verification dialog for seller to verify buyer's OTP
  Future<void> _showOtpVerificationDialog(Order order) async {
    final otpController = TextEditingController();
    bool isVerifying = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.verified_user, color: AppTheme.teal),
              SizedBox(width: 8),
              Text('Verify Pickup OTP'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the OTP shown by the buyer to verify pickup:',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'OTP',
                  hintText: 'Enter 6-digit OTP',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                enabled: !isVerifying,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isVerifying ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isVerifying ? null : () async {
                final enteredOtp = otpController.text.trim();
                if (enteredOtp.length != 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid 6-digit OTP'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setState(() => isVerifying = true);

                try {
                  // First, verify that OTP exists in Firestore
                  final orderDoc = await OrderFirestoreService.doc(order.orderId).get();
                  if (!orderDoc.exists) {
                    if (mounted) {
                      setState(() => isVerifying = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('❌ Order not found in database.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  final orderData = orderDoc.data();
                  final storedOtp = orderData?['pickupOtp'] as String?;
                  
                  if (storedOtp == null || storedOtp.isEmpty) {
                    if (mounted) {
                      setState(() => isVerifying = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('❌ No OTP found for this order. Please contact support.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  print('🔐 Verifying OTP - Stored: $storedOtp, Provided: $enteredOtp');

                  // Verify OTP via Firestore service
                  final isValid = await OrderFirestoreService.verifyOtp(
                    orderId: order.orderId,
                    providedOtp: enteredOtp,
                  ).timeout(
                    const Duration(seconds: 10),
                    onTimeout: () {
                      print('OTP verification timed out');
                      return false;
                    },
                  );

                  if (!mounted) return;

                  if (isValid) {
                    // Update local order in Hive box (if it exists)
                    try {
                      final ordersBox = Hive.box<Order>('ordersBox');
                      final orderKey = ordersBox.keys.firstWhere(
                        (key) {
                          final o = ordersBox.get(key);
                          return o?.orderId == order.orderId;
                        },
                        orElse: () => null,
                      );
                      
                      if (orderKey != null) {
                        final localOrder = ordersBox.get(orderKey);
                        if (localOrder != null) {
                          localOrder.orderStatus = 'Completed';
                          localOrder.statusChangedAt = DateTime.now();
                          await localOrder.save();
                        }
                      }
                    } catch (e) {
                      print('⚠️ Could not update local order in Hive: $e');
                      // Continue anyway - Firestore is the source of truth
                    }

                    // Sync to Firestore (already done by verifyOtp, but ensure status is synced)
                    await OrderFirestoreService.updateStatus(
                      orderId: order.orderId,
                      status: 'Completed',
                      sellerRespondedAt: DateTime.now(),
                    );

                    // Free up Live Kitchen capacity if applicable
                    if (order.isLiveKitchenOrder ?? false) {
                      final listingBox = Hive.box<Listing>('listingBox');
                      final listingKey = int.tryParse(order.listingId);
                      if (listingKey != null) {
                        final listing = listingBox.get(listingKey);
                        if (listing != null && listing.isLiveKitchen) {
                          listing.completeLiveKitchenOrder();
                          await listing.save();
                        }
                      }
                    }

                    WebOrderBroadcast.postStatus(orderId: order.orderId, status: 'Completed');

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ OTP verified! Order marked as completed.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    if (mounted) {
                      setState(() => isVerifying = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('❌ Invalid OTP. Please try again.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  print('Error during OTP verification: $e');
                  if (mounted) {
                    setState(() => isVerifying = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error verifying OTP: ${e.toString()}'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.teal,
                foregroundColor: Colors.white,
              ),
              child: isVerifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }

  // Debug section to show all orders (temporary - for troubleshooting)
  Widget _buildAllOrdersNeedingActionSection(List<Order> orders) {
    // Show ALL regular orders (not Live Kitchen) that haven't been accepted/rejected
    final liveKitchenStatuses = ['OrderReceived', 'Preparing', 'ReadyForPickup', 'ReadyForDelivery'];
    final allRegularOrders = orders.where((o) {
      final isLiveKitchen = (o.isLiveKitchenOrder ?? false) || liveKitchenStatuses.contains(o.orderStatus);
      return !isLiveKitchen;
    }).toList();
    
    // Show orders that need action (not yet accepted/rejected/completed/cancelled)
    final ordersNeedingAction = allRegularOrders.where((o) =>
      o.orderStatus != 'AcceptedBySeller' &&
      o.orderStatus != 'RejectedBySeller' &&
      o.orderStatus != 'Confirmed' &&
      o.orderStatus != 'Completed' &&
      o.orderStatus != 'Cancelled'
    ).toList()..sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));
    
    if (ordersNeedingAction.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.red.shade700, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'All Orders Needing Action (${ordersNeedingAction.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'These orders should have Accept/Reject buttons. If they don\'t appear above, check their status:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          ...ordersNeedingAction.take(3).map((order) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.foodName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Status: ${order.orderStatus}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Order ID: ${order.orderId.substring(order.orderId.length - 6)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _acceptOrder(order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Accept'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _rejectOrder(order),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Reject'),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildAllOrdersDebugSection(List<Order> orders) {
    // Group orders by status
    final ordersByStatus = <String, List<Order>>{};
    for (final order in orders) {
      final status = order.orderStatus;
      ordersByStatus.putIfAbsent(status, () => []).add(order);
    }

    if (ordersByStatus.isEmpty) {
      return const SizedBox.shrink();
    }

    return ExpansionTile(
      title: Row(
        children: [
          Icon(Icons.bug_report, color: Colors.purple.shade700, size: 20),
          const SizedBox(width: 8),
          Text(
            'Debug: All Orders (${orders.length})',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.purple.shade700,
            ),
          ),
        ],
      ),
      children: [
        ...ordersByStatus.entries.map((entry) {
          final status = entry.key;
          final statusOrders = entry.value;
          final isLiveKitchen = statusOrders.first.isLiveKitchenOrder ?? false;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isLiveKitchen ? Colors.green.shade50 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isLiveKitchen ? Colors.green.shade200 : Colors.blue.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isLiveKitchen ? Colors.green.shade800 : Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isLiveKitchen ? Colors.green : Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${statusOrders.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isLiveKitchen) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Live Kitchen',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                ...statusOrders.take(3).map((order) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Text(
                          '• ${order.foodName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isLiveKitchen ? Colors.green.shade700 : Colors.blue.shade700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '₹${order.pricePaid.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isLiveKitchen ? Colors.green.shade700 : Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (statusOrders.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '... and ${statusOrders.length - 3} more',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: isLiveKitchen ? Colors.green.shade600 : Colors.blue.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<void> _rejectOrder(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Order?'),
        content: const Text('Are you sure you want to reject this order? The buyer will be notified.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Dismiss notification immediately before updating status
        NotificationService.dismissNotificationForOrder(order.orderId, context);
        
        order.orderStatus = 'RejectedBySeller';
        order.sellerRespondedAt = DateTime.now();
        await order.save();
        await OrderFirestoreService.updateStatus(
          orderId: order.orderId,
          status: 'RejectedBySeller',
          sellerRespondedAt: order.sellerRespondedAt,
        );
        WebOrderBroadcast.postStatus(orderId: order.orderId, status: 'RejectedBySeller');

        // If this is a Live Kitchen order, free up the capacity
        // Check by flag OR by status (in case flag wasn't set)
        final liveKitchenStatuses = ['OrderReceived', 'Preparing', 'ReadyForPickup', 'ReadyForDelivery'];
        final isLiveKitchen = (order.isLiveKitchenOrder ?? false) || liveKitchenStatuses.contains(order.orderStatus);
        
        if (isLiveKitchen) {
          final listingBox = Hive.box<Listing>('listingBox');
          final listingKey = int.tryParse(order.listingId);
          if (listingKey != null) {
            final listing = listingBox.get(listingKey);
            if (listing != null && listing.isLiveKitchen) {
              listing.completeLiveKitchenOrder(); // This decrements currentOrders
              await listing.save();
            }
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order rejected. Buyer will be notified.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            'Transactions',
            Icons.receipt_long,
            Colors.blue,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SellerTransactionsScreen(sellerId: _effectiveSellerId),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            'Item Insights',
            Icons.analytics,
            Colors.purple,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SellerItemInsightsScreen(sellerId: _effectiveSellerId),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            'Reviews',
            Icons.star,
            Colors.amber,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SellerReviewsScreen(sellerId: _effectiveSellerId),
                            ),
                          );
                        },
                      ),
              ),
            ],
    );
  }

  Widget _buildGroceryOnboardingCard() {
    return FutureBuilder<SellerProfile?>(
      future: SellerProfileService.getProfile(_effectiveSellerId),
      builder: (context, snapshot) {
        final hasCompletedOnboarding = snapshot.data?.groceryOnboardingCompleted ?? false;

        return Container(
          margin: const EdgeInsets.only(top: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                print('🛒 Navigating to Grocery Onboarding Screen');
                final result = await Navigator.push<SellType>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const GroceryOnboardingScreen(),
                  ),
                );
                
                // If onboarding completed successfully, switch to Start Selling tab with groceries
                if (result == SellType.groceries && mounted) {
                  print('✅ Grocery onboarding completed, switching to Start Selling tab');
                  // Notify the parent MainTabScreen to switch to Start Selling tab
                  if (widget.onSwitchToSelling != null) {
                    widget.onSwitchToSelling!(SellType.groceries);
                  }
                }
              },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF50C878).withOpacity(0.1),
                  const Color(0xFF50C878).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF50C878).withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF50C878).withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF50C878).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    hasCompletedOnboarding ? Icons.edit_rounded : Icons.shopping_bag,
                    color: const Color(0xFF50C878),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              hasCompletedOnboarding 
                                  ? 'Manage Grocery Documents'
                                  : 'Sell Groceries',
                              style: AppTheme.heading4.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkText,
                              ),
                            ),
                          ),
                          if (hasCompletedOnboarding) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF50C878),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Active',
                                style: AppTheme.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasCompletedOnboarding
                            ? 'Update documents or seller type'
                            : 'Start selling fresh produce, grains & more',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.lightText,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: const Color(0xFF50C878),
                  size: 20,
                ),
              ],
            ),
          ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemManagementSection() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: _buildActionCard(
        'Manage Items',
        Icons.inventory_2,
        Colors.brown,
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SellerItemManagementScreen(sellerId: _effectiveSellerId),
          ),
        );
      },
    ),
  );
}

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
      onTap: onTap,
        borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
          decoration: AppTheme.getCardDecoration(elevated: true),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.15),
                      color.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withOpacity(0.2),
                    width: 1,
                  ),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
              const SizedBox(height: 10),
            Text(
              title,
                style: AppTheme.bodySmall.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                  color: AppTheme.darkText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemInsightsSection(List<Listing> listings, List<Order> orders) {
    if (listings.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppTheme.buildSectionHeader(
              title: 'Top Items',
              subtitle: 'Best performing products',
              icon: Icons.trending_up_rounded,
              iconColor: AppTheme.teal,
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SellerItemInsightsScreen(sellerId: _effectiveSellerId),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.teal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Text(
                'View All',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.teal,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...listings.take(3).map((listing) {
          final itemOrders = orders.where((o) => o.listingId == listing.key.toString()).toList();
          final totalSold = itemOrders.fold<int>(0, (sum, o) => sum + o.quantity);
          final revenue = itemOrders.fold<double>(0, (sum, o) => sum + o.pricePaid);
          final avgRating = listing.averageRating > 0 ? listing.averageRating : 0.0;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SellerItemInsightsScreen(sellerId: _effectiveSellerId),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              listing.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1F2937), // Dark gray
                              ),
                            ),
                          ),
                          // Show Live Kitchen badge if applicable
                          if (listing.isLiveKitchen) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.restaurant,
                                    size: 12,
                                    color: Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Live',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                      Text(
                                  'Units sold: ',
                        style: TextStyle(
                                    fontSize: 13,
                                    color: const Color(0xFF6B7280), // Muted gray
                                  ),
                                ),
                                Text(
                                  '$totalSold',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Revenue: ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                                Text(
                                  '₹${revenue.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1F2937),
                        ),
                      ),
                      if (avgRating > 0) ...[
                        const SizedBox(width: 16),
                        Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          avgRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ],
                  ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: const Color(0xFF9CA3AF), // Light muted gray
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppTheme.buildSectionHeader(
              title: 'Reviews',
              subtitle: 'Customer feedback',
              icon: Icons.star_outline_rounded,
              iconColor: AppTheme.badgeOffer, // Amber for reviews
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SellerReviewsScreen(sellerId: _effectiveSellerId),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.teal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Text(
                'View All',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.teal,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<SellerReview>>(
          future: SellerReviewService.getSellerReviews(
            sellerId: _effectiveSellerId,
            limit: 3,
            approvedOnly: true,
          ),
          builder: (context, snapshot) {
            print('[SellerDashboard] Builder called - ConnectionState: ${snapshot.connectionState}, HasError: ${snapshot.hasError}, HasData: ${snapshot.hasData}');
            
            if (snapshot.connectionState == ConnectionState.waiting) {
              print('[SellerDashboard] ⏳ Showing loading indicator');
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              print('[SellerDashboard] ❌ Error loading reviews: ${snapshot.error}');
              print('[SellerDashboard] Error details: ${snapshot.error.toString()}');
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Error loading reviews',
                      style: TextStyle(color: Colors.red.shade700, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${snapshot.error}',
                      style: TextStyle(color: Colors.red.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'SellerId: ${_effectiveSellerId}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                    ),
                  ],
                ),
              );
            }

            final reviews = snapshot.data ?? [];
            print('[SellerDashboard] ✅ Loaded ${reviews.length} reviews for seller ${_effectiveSellerId}');
            if (reviews.isNotEmpty) {
              print('[SellerDashboard] First review: sellerId=${reviews.first.sellerId}, rating=${reviews.first.rating}');
            }

            if (reviews.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB703).withOpacity(0.15), // Amber
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.star_outline_rounded,
                        color: const Color(0xFFFFB703),
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No reviews yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Customer reviews will appear here once buyers rate your products.',
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF6B7280),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: reviews.map((review) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      ...List.generate(5, (index) {
                        return Icon(
                          index < review.rating.round()
                              ? Icons.star
                              : Icons.star_border,
                          size: 16,
                          color: Colors.amber,
                        );
                      }),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          review.reviewText ?? 'No review',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  List<Order> _filterOrdersByDateRange(List<Order> orders, String timeRange, DateTime? startDate, DateTime? endDate) {
    if (timeRange == 'Custom' && startDate != null && endDate != null) {
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      return orders.where((o) {
        final orderDate = DateTime(o.purchasedAt.year, o.purchasedAt.month, o.purchasedAt.day);
        return orderDate.isAfter(start.subtract(const Duration(days: 1))) && orderDate.isBefore(end.add(const Duration(days: 1)));
      }).toList();
    } else if (timeRange == 'Daily') {
      final today = DateTime.now();
      return orders.where((o) {
        return o.purchasedAt.year == today.year &&
            o.purchasedAt.month == today.month &&
            o.purchasedAt.day == today.day;
      }).toList();
    } else if (timeRange == 'Weekly') {
      final weekStart = DateTime.now().subtract(const Duration(days: 7));
      return orders.where((o) => o.purchasedAt.isAfter(weekStart)).toList();
    } else if (timeRange == 'Monthly') {
      final thisMonth = DateTime(DateTime.now().year, DateTime.now().month);
      return orders.where((o) {
        final orderMonth = DateTime(o.purchasedAt.year, o.purchasedAt.month);
        return orderMonth.isAtSameMomentAs(thisMonth);
      }).toList();
    }
    return orders;
  }

  Map<String, dynamic> _calculateMetrics(List<Order> orders, List<Listing> listings, String timeRange, DateTime? startDate, DateTime? endDate) {
    final filteredOrders = _filterOrdersByDateRange(orders, timeRange, startDate, endDate);
    
    // Only count accepted orders (not pending, rejected, or cancelled)
    // Regular orders: must be 'AcceptedBySeller' or 'Completed'
    // Live Kitchen orders: must be 'Preparing', 'ReadyForPickup', 'ReadyForDelivery', or 'Completed' (NOT 'OrderReceived')
    final acceptedOrders = filteredOrders.where((o) {
      // Exclude rejected and cancelled orders
      if (o.orderStatus == 'RejectedBySeller' || o.orderStatus == 'Cancelled') {
        return false;
      }
      
      // For Live Kitchen orders, exclude 'OrderReceived' (not yet accepted)
      if (o.isLiveKitchenOrder ?? false) {
        return ['Preparing', 'ReadyForPickup', 'ReadyForDelivery', 'Completed'].contains(o.orderStatus);
      }
      
      // For regular orders, count accepted, ready for pickup, or completed
      return ['AcceptedBySeller', 'ReadyForPickup', 'Completed'].contains(o.orderStatus);
    }).toList();
    
    final totalOrders = acceptedOrders.length;
    final totalRevenue = acceptedOrders.fold<double>(0, (sum, o) => sum + o.pricePaid);
    
    final today = DateTime.now();
    final todayOrders = acceptedOrders.where((o) {
      return o.purchasedAt.year == today.year &&
          o.purchasedAt.month == today.month &&
          o.purchasedAt.day == today.day;
    }).toList();
    final todaySales = todayOrders.fold<double>(0, (sum, o) => sum + o.pricePaid);

    final thisMonth = DateTime(today.year, today.month);
    final monthlyOrders = acceptedOrders.where((o) {
      final orderMonth = DateTime(o.purchasedAt.year, o.purchasedAt.month);
      return orderMonth.isAtSameMomentAs(thisMonth);
    }).toList();
    final monthlySales = monthlyOrders.fold<double>(0, (sum, o) => sum + o.pricePaid);

    // Pending orders are those waiting for seller acceptance
    final pendingOrders = filteredOrders.where((o) {
      if (o.isLiveKitchenOrder ?? false) {
        return o.orderStatus == 'OrderReceived'; // Live Kitchen orders waiting for acceptance
      }
      return o.orderStatus == 'AwaitingSellerConfirmation' || 
             o.orderStatus == 'PaymentCompleted' ||
             o.orderStatus == 'PaymentPending';
    }).length;
    
    final completedOrders = acceptedOrders.where((o) => o.orderStatus == 'Completed').length;

    return {
      'totalOrders': totalOrders,
      'totalRevenue': totalRevenue,
      'todaySales': todaySales,
      'monthlySales': monthlySales,
      'pendingOrders': pendingOrders,
      'completedOrders': completedOrders,
    };
  }

  Map<String, List<double>> _getChartData(List<Order> orders, String timeRange, DateTime? startDate, DateTime? endDate) {
    final Map<String, List<double>> data = {};
    final filteredOrders = _filterOrdersByDateRange(orders, timeRange, startDate, endDate);
    
    // Only count accepted orders (same logic as _calculateMetrics)
    final acceptedOrders = filteredOrders.where((o) {
      // Exclude rejected and cancelled orders
      if (o.orderStatus == 'RejectedBySeller' || o.orderStatus == 'Cancelled') {
        return false;
      }
      
      // For Live Kitchen orders, exclude 'OrderReceived' (not yet accepted)
      if (o.isLiveKitchenOrder ?? false) {
        return ['Preparing', 'ReadyForPickup', 'ReadyForDelivery', 'Completed'].contains(o.orderStatus);
      }
      
      // For regular orders, count accepted, ready for pickup, or completed
      return ['AcceptedBySeller', 'ReadyForPickup', 'Completed'].contains(o.orderStatus);
    }).toList();

    if (timeRange == 'Daily') {
      // Last 7 days
      for (int i = 6; i >= 0; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        final dateStr = '${date.day}/${date.month}';
        final dayOrders = acceptedOrders.where((o) {
          return o.purchasedAt.year == date.year &&
              o.purchasedAt.month == date.month &&
              o.purchasedAt.day == date.day;
        }).toList();
        final revenue = dayOrders.fold<double>(0, (sum, o) => sum + o.pricePaid);
        data[dateStr] = [revenue, dayOrders.length.toDouble()];
      }
    } else if (timeRange == 'Weekly') {
      // Last 4 weeks
      for (int i = 3; i >= 0; i--) {
        final weekStart = DateTime.now().subtract(Duration(days: i * 7));
        final weekStr = 'Week ${4 - i}';
        final weekOrders = acceptedOrders.where((o) {
          final diff = weekStart.difference(o.purchasedAt).inDays;
          return diff >= 0 && diff < 7;
        }).toList();
        final revenue = weekOrders.fold<double>(0, (sum, o) => sum + o.pricePaid);
        data[weekStr] = [revenue, weekOrders.length.toDouble()];
      }
    } else if (timeRange == 'Monthly') {
      // Last 6 months
      for (int i = 5; i >= 0; i--) {
        final month = DateTime.now().subtract(Duration(days: i * 30));
        final monthStr = '${month.month}/${month.year.toString().substring(2)}';
        final monthOrders = acceptedOrders.where((o) {
          return o.purchasedAt.year == month.year &&
              o.purchasedAt.month == month.month;
        }).toList();
        final revenue = monthOrders.fold<double>(0, (sum, o) => sum + o.pricePaid);
        data[monthStr] = [revenue, monthOrders.length.toDouble()];
      }
    } else if (timeRange == 'Custom' && startDate != null && endDate != null) {
      // Custom date range - show daily breakdown
      final daysDiff = endDate.difference(startDate).inDays;
      final maxDays = daysDiff > 30 ? 30 : daysDiff + 1; // Limit to 30 days for chart
      final interval = (daysDiff / maxDays).ceil();
      
      for (int i = 0; i <= daysDiff; i += interval) {
        final date = startDate.add(Duration(days: i));
        final dateStr = '${date.day}/${date.month}';
        final dayOrders = acceptedOrders.where((o) {
          return o.purchasedAt.year == date.year &&
              o.purchasedAt.month == date.month &&
              o.purchasedAt.day == date.day;
        }).toList();
        final revenue = dayOrders.fold<double>(0, (sum, o) => sum + o.pricePaid);
        data[dateStr] = [revenue, dayOrders.length.toDouble()];
      }
    }

    return data;
  }
}
