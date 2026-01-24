import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/order.dart';
import '../models/listing.dart';

class SellerTransactionsScreen extends StatefulWidget {
  final String sellerId;

  const SellerTransactionsScreen({super.key, required this.sellerId});

  @override
  State<SellerTransactionsScreen> createState() => _SellerTransactionsScreenState();
}

class _SellerTransactionsScreenState extends State<SellerTransactionsScreen> {
  String _selectedFilter = 'This Month'; // Default: This Month
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isLoading = false;

  // Cache for filtered results
  Map<String, List<Order>> _filterCache = {};
  Map<String, Map<String, dynamic>> _summaryCache = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Transactions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          // Future: Export button
          IconButton(
            icon: const Icon(Icons.download, color: Colors.black87),
            onPressed: () {
              // TODO: Implement export functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export feature coming soon!')),
              );
            },
            tooltip: 'Export Transactions',
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Order>('ordersBox').listenable(),
        builder: (context, Box<Order> ordersBox, _) {
          return ValueListenableBuilder(
            valueListenable: Hive.box<Listing>('listingBox').listenable(),
            builder: (context, Box<Listing> listingBox, _) {
              // Get seller's orders
              final allOrders = ordersBox.values
                  .where((order) {
                    // Check sellerId field first (new orders)
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

              // Filter orders by selected time range
              final filteredOrders = _filterOrdersByDateRange(allOrders, _selectedFilter, _customStartDate, _customEndDate);
              
              // Calculate summary metrics
              final summary = _calculateSummary(filteredOrders);

              return Column(
                children: [
                  // Filter Section
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Filter Options
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('Today', _selectedFilter == 'Today'),
                              const SizedBox(width: 8),
                              _buildFilterChip('Yesterday', _selectedFilter == 'Yesterday'),
                              const SizedBox(width: 8),
                              _buildFilterChip('This Week', _selectedFilter == 'This Week'),
                              const SizedBox(width: 8),
                              _buildFilterChip('Last Week', _selectedFilter == 'Last Week'),
                              const SizedBox(width: 8),
                              _buildFilterChip('This Month', _selectedFilter == 'This Month'),
                              const SizedBox(width: 8),
                              _buildFilterChip('Last Month', _selectedFilter == 'Last Month'),
                              const SizedBox(width: 8),
                              _buildFilterChip('Custom', _selectedFilter == 'Custom'),
                            ],
                          ),
                        ),
                        
                        // Custom Date Range Picker
                        if (_selectedFilter == 'Custom') ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDatePicker(
                                  label: 'Start Date',
                                  date: _customStartDate,
                                  onDateSelected: (date) {
                                    setState(() {
                                      _customStartDate = date;
                                      // Clear cache when date changes
                                      _filterCache.clear();
                                      _summaryCache.clear();
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDatePicker(
                                  label: 'End Date',
                                  date: _customEndDate,
                                  onDateSelected: (date) {
                                    setState(() {
                                      _customEndDate = date;
                                      // Clear cache when date changes
                                      _filterCache.clear();
                                      _summaryCache.clear();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (_customStartDate != null && _customEndDate != null)
                            if (_customEndDate!.isBefore(_customStartDate!))
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'End date must be after start date',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          if (_customStartDate == null || _customEndDate == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Please select both start and end dates',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),

                  // Summary Cards
                  if (filteredOrders.isNotEmpty || _selectedFilter != 'Custom' || (_customStartDate != null && _customEndDate != null))
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(top: 8),
                      child: _buildSummaryCards(summary),
                    ),

                  // Transaction List
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : filteredOrders.isEmpty
                            ? _buildEmptyState()
                            : RefreshIndicator(
                                onRefresh: () async {
                                  setState(() {
                                    _filterCache.clear();
                                    _summaryCache.clear();
                                  });
                                },
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filteredOrders.length,
                                  itemBuilder: (context, index) {
                                    final order = filteredOrders[index];
                                    return _buildTransactionCard(order);
                                  },
                                ),
                              ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = label;
            // Clear custom dates when switching to non-custom filter
            if (label != 'Custom') {
              _customStartDate = null;
              _customEndDate = null;
            }
            // Clear cache when filter changes
            _filterCache.clear();
            _summaryCache.clear();
          });
        }
      },
      selectedColor: Colors.orange.shade100,
      checkmarkColor: Colors.orange.shade700,
      labelStyle: TextStyle(
        color: isSelected ? Colors.orange.shade700 : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
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
                    fontWeight: FontWeight.w600,
                    color: date != null ? Colors.black87 : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
            Icon(Icons.calendar_today, size: 20, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> summary) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Transactions',
            summary['totalTransactions'].toString(),
            Icons.receipt_long,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Total Revenue',
            '₹${summary['totalRevenue'].toStringAsFixed(0)}',
            Icons.currency_rupee,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Items Sold',
            summary['itemsSold'].toString(),
            Icons.shopping_bag,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Refunds',
            summary['refunds'].toString(),
            Icons.undo,
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Order order) {
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
                      'Order #${order.orderId.substring(order.orderId.length - 6)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(order.purchasedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(order.orderStatus).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  order.orderStatus,
                  style: TextStyle(
                    color: _getStatusColor(order.orderStatus),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            order.foodName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${order.quantity} × ₹${order.discountedPrice.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment: ${order.paymentMethod ?? 'N/A'}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                '₹${order.pricePaid.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    if (_selectedFilter == 'Custom' && (_customStartDate == null || _customEndDate == null)) {
      message = 'Please select a date range';
    } else {
      message = 'No transactions found for this period';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (_selectedFilter == 'Custom' && (_customStartDate == null || _customEndDate == null))
            Text(
              'Select start and end dates to view transactions',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  List<Order> _filterOrdersByDateRange(
    List<Order> orders,
    String filter,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    // Check cache first
    final cacheKey = '$filter${startDate?.toString()}${endDate?.toString()}';
    if (_filterCache.containsKey(cacheKey)) {
      return _filterCache[cacheKey]!;
    }

    List<Order> filtered;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    switch (filter) {
      case 'Today':
        filtered = orders.where((o) {
          final orderDate = DateTime(o.purchasedAt.year, o.purchasedAt.month, o.purchasedAt.day);
          return orderDate.isAtSameMomentAs(today);
        }).toList();
        break;

      case 'Yesterday':
        filtered = orders.where((o) {
          final orderDate = DateTime(o.purchasedAt.year, o.purchasedAt.month, o.purchasedAt.day);
          return orderDate.isAtSameMomentAs(yesterday);
        }).toList();
        break;

      case 'This Week':
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        filtered = orders.where((o) => o.purchasedAt.isAfter(weekStart.subtract(const Duration(seconds: 1)))).toList();
        break;

      case 'Last Week':
        final lastWeekStart = today.subtract(Duration(days: today.weekday + 6));
        final lastWeekEnd = today.subtract(Duration(days: today.weekday));
        filtered = orders.where((o) {
          return o.purchasedAt.isAfter(lastWeekStart.subtract(const Duration(seconds: 1))) &&
              o.purchasedAt.isBefore(lastWeekEnd.add(const Duration(days: 1)));
        }).toList();
        break;

      case 'This Month':
        final thisMonth = DateTime(now.year, now.month);
        filtered = orders.where((o) {
          final orderMonth = DateTime(o.purchasedAt.year, o.purchasedAt.month);
          return orderMonth.isAtSameMomentAs(thisMonth);
        }).toList();
        break;

      case 'Last Month':
        final lastMonth = DateTime(now.year, now.month - 1);
        filtered = orders.where((o) {
          final orderMonth = DateTime(o.purchasedAt.year, o.purchasedAt.month);
          return orderMonth.isAtSameMomentAs(lastMonth);
        }).toList();
        break;

      case 'Custom':
        if (startDate != null && endDate != null) {
          final start = DateTime(startDate.year, startDate.month, startDate.day);
          final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
          filtered = orders.where((o) {
            return o.purchasedAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
                o.purchasedAt.isBefore(end.add(const Duration(seconds: 1)));
          }).toList();
        } else {
          filtered = [];
        }
        break;

      default:
        filtered = orders;
    }

    // Sort by latest first
    filtered.sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));

    // Cache the result
    _filterCache[cacheKey] = filtered;

    return filtered;
  }

  Map<String, dynamic> _calculateSummary(List<Order> orders) {
    // Check cache first
    final cacheKey = orders.length.toString() + orders.map((o) => o.orderId).join(',');
    if (_summaryCache.containsKey(cacheKey)) {
      return _summaryCache[cacheKey] as Map<String, dynamic>;
    }

    final totalTransactions = orders.length;
    final totalRevenue = orders
        .where((o) => o.orderStatus != 'Cancelled' && o.orderStatus != 'RejectedBySeller')
        .fold<double>(0, (sum, o) => sum + o.pricePaid);
    final itemsSold = orders
        .where((o) => o.orderStatus != 'Cancelled' && o.orderStatus != 'RejectedBySeller')
        .fold<int>(0, (sum, o) => sum + o.quantity);
    final refunds = orders
        .where((o) => o.orderStatus == 'Cancelled' || o.orderStatus == 'RejectedBySeller')
        .length;

    final summary = {
      'totalTransactions': totalTransactions,
      'totalRevenue': totalRevenue,
      'itemsSold': itemsSold,
      'refunds': refunds,
    };

    // Cache the result
    _summaryCache[cacheKey] = summary;

    return summary;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Confirmed':
      case 'AcceptedBySeller':
        return Colors.blue;
      case 'Completed':
        return Colors.green;
      case 'Cancelled':
      case 'RejectedBySeller':
        return Colors.red;
      case 'AwaitingSellerConfirmation':
      case 'PaymentPending':
        return Colors.orange;
      case 'OrderReceived':
      case 'Preparing':
        return Colors.purple;
      case 'ReadyForPickup':
      case 'ReadyForDelivery':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
