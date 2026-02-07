import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/listing.dart';
import '../models/order.dart';
import '../models/rating.dart';
import 'seller_transactions_screen.dart';
import 'seller_item_insights_screen.dart';
import 'seller_reviews_screen.dart';
import 'seller_item_management_screen.dart';
import '../services/notification_service.dart';
import '../services/order_firestore_service.dart';
import '../services/web_order_broadcast.dart';
import '../services/seller_profile_service.dart';
import 'order_details_screen.dart';

class SellerDashboardScreen extends StatefulWidget {
  final String sellerId;

  const SellerDashboardScreen({super.key, required this.sellerId});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  String _selectedTimeRange = 'Daily'; // Daily, Weekly, Monthly, Custom
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
Widget build(BuildContext context) {
  return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        toolbarHeight: 44, // Reduced height for more space
        title: const Text(
          'Seller Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() {}),
          ),
          const SizedBox(width: 8),
        ],
      ),
    body: ValueListenableBuilder(
        valueListenable: Hive.box<Order>('ordersBox').listenable(),
        builder: (context, Box<Order> ordersBox, _) {
          // Check for new orders when orders box changes (immediately, not just post-frame)
          NotificationService.checkForNewOrders(context, widget.sellerId);
          
          return ValueListenableBuilder(
      valueListenable: Hive.box<Listing>('listingBox').listenable(),
            builder: (context, Box<Listing> listingBox, _) {
              final myListings = listingBox.values
                  .where((l) => l.sellerId == widget.sellerId)
                  .toList();

              // Filter orders by sellerId (new field) or by listing sellerId (backward compatibility)
              final myOrders = ordersBox.values
                  .where((order) {
                    // First check if order has sellerId field (new orders)
                    if (order.sellerId.isNotEmpty && order.sellerId == widget.sellerId) {
                      return true;
                    }
                    // Fallback: check via listing (for old orders)
                    try {
                      final listingKey = int.tryParse(order.listingId);
                      if (listingKey != null) {
                        final listing = listingBox.get(listingKey);
                        return listing?.sellerId == widget.sellerId;
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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), // Match buyer screens (16px bottom padding)
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                    // Time Range Selector
                    _buildTimeRangeSelector(),
                    if (_selectedTimeRange == 'Custom') ...[
                      const SizedBox(height: 6),
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
                            style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                          ),
                        ),
                    ],
                    const SizedBox(height: 8),

                    // Key Metrics Cards
                    _buildMetricsRow(metrics),
                    const SizedBox(height: 12),

                    // Sales Chart
                    _buildSalesChart(chartData),
                    const SizedBox(height: 12),

                    // Pending Orders (New Orders Awaiting Approval) - ALWAYS SHOW THIS SECTION
                    _buildPendingOrdersSection(myOrders),
                    const SizedBox(height: 12),
                    
                    // Show all orders that should have accept/reject buttons
                    _buildAllOrdersNeedingActionSection(myOrders),
                    const SizedBox(height: 12),
                    
                    // Live Kitchen Orders
                    _buildLiveKitchenOrdersSection(myOrders),
                    const SizedBox(height: 12),

                    // Debug: Show all orders (temporary - for troubleshooting)
                    _buildAllOrdersDebugSection(myOrders),
                    const SizedBox(height: 12),

                    // Quick Actions
                    _buildQuickActions(),
                    const SizedBox(height: 12),
                    _buildItemManagementSection(),
                    const SizedBox(height: 12),

                    // Item Insights
                    _buildItemInsightsSection(myListings, myOrders),
                    const SizedBox(height: 12),

                    // Reviews Section
                    _buildReviewsSection(),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
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
            color: isSelected ? Colors.orange : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.grey.shade700,
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

  Widget _buildMetricsRow(Map<String, dynamic> metrics) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Total Orders',
            metrics['totalOrders'].toString(),
            Icons.shopping_cart,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Total Revenue',
            '₹${metrics['totalRevenue'].toStringAsFixed(0)}',
            Icons.currency_rupee,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesChart(Map<String, List<double>> chartData) {
    if (chartData.isEmpty) {
      return Container(
        height: 200,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'No sales data available',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    final labels = chartData.keys.toList();
    final values = chartData.values.map((v) => v[0]).toList();
    final maxValue = values.isEmpty ? 100.0 : values.reduce((a, b) => a > b ? a : b) * 1.2;
    
    // Ensure horizontalInterval is never zero (fl_chart requirement)
    final horizontalInterval = maxValue > 0 ? (maxValue / 5).clamp(1.0, double.infinity) : 1.0;

    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              const Text(
            'Sales Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
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
                                fontSize: 10,
                                color: Colors.grey.shade600,
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
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '₹${value.toInt()}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
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
                ),
                borderData: FlBorderData(show: false),
                barGroups: values.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value,
                        color: Colors.orange,
                        width: 20,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
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
  }

  Widget _buildPendingOrdersSection(List<Order> orders) {
    // Debug: Print all orders received
    debugPrint('[SellerDashboard] _buildPendingOrdersSection called with ${orders.length} total orders');
    for (var order in orders) {
      debugPrint('[SellerDashboard] Order: ${order.orderId.substring(order.orderId.length - 6)}, status: ${order.orderStatus}, isLiveKitchen: ${order.isLiveKitchenOrder}');
    }
    
    // Filter for regular orders (not Live Kitchen) that are pending
    // Also exclude orders with Live Kitchen statuses (OrderReceived, Preparing, etc.) even if flag isn't set
    final liveKitchenStatuses = ['OrderReceived', 'Preparing', 'ReadyForPickup', 'ReadyForDelivery'];
    
    // Get all regular orders (not Live Kitchen)
    final allRegularOrders = orders.where((o) {
      final isLiveKitchen = (o.isLiveKitchenOrder ?? false) || liveKitchenStatuses.contains(o.orderStatus);
      return !isLiveKitchen;
    }).toList();
    
    debugPrint('[SellerDashboard] Found ${allRegularOrders.length} regular orders (not Live Kitchen)');
    
    // Filter for orders that need seller action (pending acceptance/rejection)
    final pendingOrders = allRegularOrders.where((o) => 
      // Include orders that are waiting for seller confirmation
      o.orderStatus == 'PaymentCompleted' || 
      o.orderStatus == 'AwaitingSellerConfirmation' ||
      o.orderStatus == 'PaymentPending'
    ).toList()..sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));
    
    debugPrint('[SellerDashboard] Found ${pendingOrders.length} pending orders with expected statuses');
    
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
    
    debugPrint('[SellerDashboard] Found ${ordersNeedingAction.length} orders needing action (any status)');
    
    // If no pending orders but there are orders needing action, show those instead
    final ordersToShow = pendingOrders.isNotEmpty ? pendingOrders : ordersNeedingAction;
    
    debugPrint('[SellerDashboard] Will show ${ordersToShow.length} orders in pending section');

    // ALWAYS show the section header, even if empty
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
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.pending_actions, color: Colors.orange.shade700, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Pending Orders',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${ordersToShow.length}',
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
        const SizedBox(height: 12),
        
        // Show pending orders if any
        if (ordersToShow.isNotEmpty) ...[
          if (pendingOrders.isEmpty && ordersNeedingAction.isNotEmpty) ...[
            // Show warning if showing orders that don't match expected status
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Showing ${ordersNeedingAction.length} order(s) that need seller action (status: ${ordersNeedingAction.map((o) => o.orderStatus).join(", ")})',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          ...ordersToShow.take(5).map((order) => _buildPendingOrderCard(order)),
        ] else ...[
          // Show helpful message when no pending orders
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'No Pending Orders',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Orders with status "AwaitingSellerConfirmation" will appear here with Accept/Reject buttons.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange.shade800,
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
    // Debug: Print order details
    debugPrint('[SellerDashboard] Building pending order card for: ${order.orderId}, status: ${order.orderStatus}, isLiveKitchen: ${order.isLiveKitchenOrder}');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
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
                    Row(
                      children: [
                        Text(
                          'Order ID: ${order.orderId.substring(order.orderId.length - 6)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            order.orderStatus,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Qty: ${order.quantity} × ₹${order.discountedPrice.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  Text(
                    order.purchasedAt.toLocal().toString().split(' ')[0],
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
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order)),
                );
              },
              child: const Text('View order details'),
            ),
          ),
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
                  onPressed: () => _acceptOrder(order),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Accept Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _acceptOrder(Order order) async {
    try {
      // Dismiss notification immediately before updating status
      NotificationService.dismissNotificationForOrder(order.orderId, context);
      
      order.orderStatus = 'AcceptedBySeller';
      order.sellerRespondedAt = DateTime.now();
      await order.save();
      await OrderFirestoreService.updateStatus(
        orderId: order.orderId,
        status: 'AcceptedBySeller',
        sellerRespondedAt: order.sellerRespondedAt,
      );
      
      // Ensure seller details are saved to Firestore (in case they weren't saved when order was created)
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
      
      WebOrderBroadcast.postStatus(orderId: order.orderId, status: 'AcceptedBySeller');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order accepted successfully!'),
            backgroundColor: Colors.green,
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
    
    // Debug: Print Live Kitchen orders found
    debugPrint('[SellerDashboard] Found ${liveKitchenOrders.length} Live Kitchen orders');
    for (var order in liveKitchenOrders) {
      debugPrint('[SellerDashboard] Live Kitchen Order: ${order.orderId.substring(order.orderId.length - 6)}, status: ${order.orderStatus}, isLiveKitchen: ${order.isLiveKitchenOrder}');
    }

    // Always show the section, even if empty (with helpful message)
    if (liveKitchenOrders.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'No Live Kitchen Orders',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Live Kitchen orders with status "OrderReceived", "Preparing", "ReadyForPickup", or "ReadyForDelivery" will appear here.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.green.shade800,
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
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '1. Buyer places order → Status: "OrderReceived"\n2. You accept → Status: "Preparing"\n3. Food ready → Status: "ReadyForPickup"\n4. Order completed → Status: "Completed"',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
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
                onPressed: () => _updateLiveKitchenOrderStatus(order, 'Completed'),
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Mark Completed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade600,
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
      order.orderStatus = newStatus;
      order.statusChangedAt = DateTime.now();
      await order.save();
      
      await OrderFirestoreService.updateStatus(
        orderId: order.orderId,
        status: newStatus,
        sellerRespondedAt: order.statusChangedAt,
      );
      
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
            content: Text('Order status updated to: ${order.statusDisplayText}'),
            backgroundColor: Colors.green,
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
                  builder: (_) => SellerTransactionsScreen(sellerId: widget.sellerId),
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
                  builder: (_) => SellerItemInsightsScreen(sellerId: widget.sellerId),
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
                  builder: (_) => SellerReviewsScreen(sellerId: widget.sellerId),
                            ),
                          );
                        },
                      ),
              ),
            ],
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
              builder: (_) => SellerItemManagementScreen(sellerId: widget.sellerId),
          ),
        );
      },
    ),
  );
}

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
          children: [
            const Text(
              'Top Items',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SellerItemInsightsScreen(sellerId: widget.sellerId),
                  ),
                );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...listings.take(3).map((listing) {
          final itemOrders = orders.where((o) => o.listingId == listing.key.toString()).toList();
          final totalSold = itemOrders.fold<int>(0, (sum, o) => sum + o.quantity);
          final revenue = itemOrders.fold<double>(0, (sum, o) => sum + o.pricePaid);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sold: $totalSold | Revenue: ₹${revenue.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
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
          children: [
            const Text(
              'Recent Reviews',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SellerReviewsScreen(sellerId: widget.sellerId),
                  ),
                );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder(
          valueListenable: Hive.box('ratingsBox').listenable(),
          builder: (context, Box box, _) {
            final ratings = box.values
                .where((r) => r is Rating && r.sellerId == widget.sellerId)
                .cast<Rating>()
                .toList()
              ..sort((a, b) => b.ratedAt.compareTo(a.ratedAt));

            if (ratings.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'No reviews yet',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              );
            }

            return Column(
              children: ratings.take(3).map((rating) {
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
                          index < rating.sellerRating
                              ? Icons.star
                              : Icons.star_border,
                          size: 16,
                          color: Colors.amber,
                        );
                      }),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rating.review ?? 'No review',
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
      
      // For regular orders, only count accepted or completed
      return ['AcceptedBySeller', 'Completed'].contains(o.orderStatus);
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
      
      // For regular orders, only count accepted or completed
      return ['AcceptedBySeller', 'Completed'].contains(o.orderStatus);
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
