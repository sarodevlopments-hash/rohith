import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/admin_metrics_service.dart';
import '../theme/app_theme.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  DateRange _selectedDateRange = DateRange.last30Days;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isLoading = true;
  bool _isAuthorized = false;

  // Metrics data
  Map<String, dynamic> _kpiMetrics = {};
  List<Map<String, dynamic>> _newUsersPerDay = [];
  List<Map<String, dynamic>> _ordersPerDay = [];
  List<Map<String, dynamic>> _revenuePerDay = [];
  Map<String, dynamic> _sellerInsights = {};
  Map<String, dynamic> _buyerInsights = {};
  Map<String, dynamic> _productPerformance = {};
  Map<String, dynamic> _platformHealth = {};

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
  }

  Future<void> _checkAuthorization() async {
    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) {
        // Not logged in - show login screen
        setState(() {
          _isAuthorized = false;
          _isLoading = false;
        });
        return;
      }

      // User is logged in - check role
      await _verifyOwnerRole(user.uid);
    });

    // Check current user immediately
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _isAuthorized = false;
        _isLoading = false;
      });
      return;
    }

    await _verifyOwnerRole(currentUser.uid);
  }

  Future<void> _verifyOwnerRole(String uid) async {
    try {
      // For web, use Firestore directly (no Hive)
      final db = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'reqfood',
      );
      
      print('DEBUG: Checking owner role for UID: $uid');
      
      final userDoc = await db.collection('userProfiles').doc(uid).get();
      
      if (userDoc.exists) {
        final data = userDoc.data();
        // Convert LinkedMap to Map<String, dynamic> for web compatibility
        Map<String, dynamic> dataMap = {};
        if (data != null) {
          try {
            // Handle LinkedMap<dynamic, dynamic> from web
            dataMap = Map<String, dynamic>.fromEntries(
              (data as Map).entries.map((e) => MapEntry(e.key.toString(), e.value)),
            );
          } catch (e) {
            print('Error converting user data: $e');
            dataMap = {};
          }
        }
        final role = dataMap['role'] as String?;
        
        print('DEBUG: User role found: $role');
        print('DEBUG: User data: $dataMap');
        
        if (role == 'owner') {
          print('DEBUG: Owner role confirmed, loading metrics...');
          setState(() {
            _isAuthorized = true;
          });
          await _loadMetrics();
        } else {
          print('DEBUG: User does not have owner role. Current role: $role');
          print('DEBUG: To fix: Go to Firestore Console → userProfiles → $uid → Add field: role = "owner"');
          setState(() {
            _isAuthorized = false;
            _isLoading = false;
          });
        }
      } else {
        print('DEBUG: User profile does not exist in Firestore!');
        print('DEBUG: UID: $uid');
        print('DEBUG: To fix: Create userProfiles/$uid document in Firestore with role: "owner"');
        setState(() {
          _isAuthorized = false;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('ERROR: Failed to check authorization: $e');
      print('Stack trace: $stackTrace');
      if (e.toString().contains('permission-denied')) {
        print('ERROR: Permission denied! This means:');
        print('  1. Firestore rules are not published, OR');
        print('  2. Your user profile does not exist, OR');
        print('  3. Rules are blocking access');
        print('SOLUTION: See FIX_FIRESTORE_PERMISSIONS.md for steps');
      }
      setState(() {
        _isAuthorized = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _login() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Login Required'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                if (isLoading) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading
                  ? null
                  : () {
                      Navigator.of(context).pop();
                    },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() {
                          isLoading = true;
                        });

                        try {
                          await FirebaseAuth.instance.signInWithEmailAndPassword(
                            email: emailController.text.trim(),
                            password: passwordController.text,
                          );
                          Navigator.of(context).pop();
                          // Auth state listener will automatically check role
                        } on FirebaseAuthException catch (e) {
                          setDialogState(() {
                            isLoading = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.message ?? 'Login failed'),
                              backgroundColor: AppTheme.errorColor,
                            ),
                          );
                        } catch (e) {
                          setDialogState(() {
                            isLoading = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Login failed: $e'),
                              backgroundColor: AppTheme.errorColor,
                            ),
                          );
                        }
                      }
                    },
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadMetrics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        AdminMetricsService.getKPIMetrics(
          dateRange: _selectedDateRange,
          customStart: _customStartDate,
          customEnd: _customEndDate,
        ),
        AdminMetricsService.getNewUsersPerDay(
          dateRange: _selectedDateRange,
          customStart: _customStartDate,
          customEnd: _customEndDate,
        ),
        AdminMetricsService.getOrdersPerDay(
          dateRange: _selectedDateRange,
          customStart: _customStartDate,
          customEnd: _customEndDate,
        ),
        AdminMetricsService.getRevenuePerDay(
          dateRange: _selectedDateRange,
          customStart: _customStartDate,
          customEnd: _customEndDate,
        ),
        AdminMetricsService.getSellerInsights(),
        AdminMetricsService.getBuyerInsights(),
        AdminMetricsService.getProductPerformance(),
        AdminMetricsService.getPlatformHealth(),
      ]);

      // Helper to convert LinkedMap to Map<String, dynamic> recursively
      Map<String, dynamic> convertMap(dynamic data) {
        if (data == null) return {};
        if (data is Map) {
          return Map<String, dynamic>.fromEntries(
            data.entries.map((e) {
              final key = e.key.toString();
              var value = e.value;
              // Recursively convert nested maps
              if (value is Map) {
                value = convertMap(value);
              } else if (value is List) {
                value = value.map((item) => item is Map ? convertMap(item) : item).toList();
              }
              return MapEntry(key, value);
            }),
          );
        }
        return {};
      }

      setState(() {
        _kpiMetrics = convertMap(results[0]);
        _newUsersPerDay = (results[1] as List).map((e) => convertMap(e)).toList().cast<Map<String, dynamic>>();
        _ordersPerDay = (results[2] as List).map((e) => convertMap(e)).toList().cast<Map<String, dynamic>>();
        _revenuePerDay = (results[3] as List).map((e) => convertMap(e)).toList().cast<Map<String, dynamic>>();
        _sellerInsights = convertMap(results[4]);
        _buyerInsights = convertMap(results[5]);
        _productPerformance = convertMap(results[6]);
        _platformHealth = convertMap(results[7]);
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('Error loading metrics: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
      });
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading dashboard data: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedDateRange = DateRange.custom;
      });
      await _loadMetrics();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (!_isAuthorized) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppTheme.cardColor,
          title: Text(
            'Owner Dashboard',
            style: AppTheme.heading3.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (currentUser == null) ...[
                  // Not logged in - show login prompt
                  Icon(Icons.login, size: 64, color: AppTheme.primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Login Required',
                    style: AppTheme.heading2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please log in to access the Owner Dashboard.',
                    style: AppTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _login,
                    icon: const Icon(Icons.login),
                    label: const Text('Login'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                  ),
                ] else ...[
                  // Logged in but not owner - show access denied
                  Icon(Icons.lock_outline, size: 64, color: AppTheme.errorColor),
                  const SizedBox(height: 16),
                  Text(
                    'Access Denied',
                    style: AppTheme.heading2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This dashboard is only accessible to app owners.',
                    style: AppTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'To gain access, set your role to "owner" in Firestore.',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.lightText),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () {
                      FirebaseAuth.instance.signOut();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 1024;
          final isTablet = constraints.maxWidth > 768 && constraints.maxWidth <= 1024;
          
          return CustomScrollView(
            slivers: [
              // Top Navigation
              SliverAppBar(
                expandedHeight: isDesktop ? 120 : 100,
                floating: false,
                pinned: true,
                backgroundColor: AppTheme.cardColor,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: EdgeInsets.only(
                    left: isDesktop ? 32 : 16,
                    bottom: 16,
                  ),
                  title: Row(
                    children: [
                      Text(
                        'Owner Dashboard',
                        style: AppTheme.heading2.copyWith(
                          fontSize: isDesktop ? 28 : 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (isDesktop) ...[
                        _buildDateRangeSelector(),
                        const SizedBox(width: 16),
                      ],
                    ],
                  ),
                ),
                actions: [
                  if (!isDesktop)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'custom') {
                          _selectCustomDateRange();
                        } else {
                          setState(() {
                            _selectedDateRange = DateRange.values.firstWhere(
                              (e) => e.toString().split('.').last == value,
                            );
                            _customStartDate = null;
                            _customEndDate = null;
                          });
                          _loadMetrics();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'today', child: Text('Today')),
                        const PopupMenuItem(value: 'last7Days', child: Text('Last 7 Days')),
                        const PopupMenuItem(value: 'last30Days', child: Text('Last 30 Days')),
                        const PopupMenuItem(value: 'custom', child: Text('Custom Range')),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Icon(Icons.date_range, color: AppTheme.darkText),
                      ),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'logout') {
                        FirebaseAuth.instance.signOut();
                        Navigator.of(context).pushReplacementNamed('/login');
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, color: AppTheme.errorColor),
                            const SizedBox(width: 8),
                            const Text('Logout'),
                          ],
                        ),
                      ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        child: Icon(Icons.person, color: AppTheme.primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // Content
              SliverPadding(
                padding: EdgeInsets.all(isDesktop ? 32 : 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (!isDesktop) ...[
                      _buildDateRangeSelector(),
                      const SizedBox(height: 24),
                    ],

                    // SECTION 1: KPI Overview Cards
                    _buildKPISection(isDesktop, isTablet),
                    const SizedBox(height: 32),

                    // SECTION 2: Growth & Activity Charts
                    _buildChartsSection(isDesktop, isTablet),
                    const SizedBox(height: 32),

                    // SECTION 3: Seller Insights
                    _buildSellerInsightsSection(isDesktop, isTablet),
                    const SizedBox(height: 32),

                    // SECTION 4: Buyer Insights
                    _buildBuyerInsightsSection(isDesktop, isTablet),
                    const SizedBox(height: 32),

                    // SECTION 5: Product & Category Performance
                    _buildProductPerformanceSection(isDesktop, isTablet),
                    const SizedBox(height: 32),

                    // SECTION 6: Platform Health & Alerts
                    _buildPlatformHealthSection(isDesktop, isTablet),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.date_range, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
            DropdownButton<DateRange>(
            value: _selectedDateRange,
            underline: const SizedBox(),
            items: [
              DropdownMenuItem(
                value: DateRange.today,
                child: const Text('Today'),
              ),
              DropdownMenuItem(
                value: DateRange.last7Days,
                child: const Text('Last 7 Days'),
              ),
              DropdownMenuItem(
                value: DateRange.last30Days,
                child: const Text('Last 30 Days'),
              ),
              DropdownMenuItem(
                value: DateRange.custom,
                child: const Text('Custom'),
              ),
            ],
            onChanged: (value) {
              if (value == DateRange.custom) {
                _selectCustomDateRange();
              } else {
                setState(() {
                  _selectedDateRange = value!;
                  _customStartDate = null;
                  _customEndDate = null;
                });
                _loadMetrics();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKPISection(bool isDesktop, bool isTablet) {
    final crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 2);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📊 KPI Overview',
          style: AppTheme.heading2.copyWith(fontSize: 24),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isDesktop ? 1.5 : 1.3,
          children: [
            _buildKPICard(
              icon: Icons.people,
              title: 'Total Users',
              value: '${_kpiMetrics['totalUsers'] ?? 0}',
              gradient: [AppTheme.primaryColor, AppTheme.secondaryColor],
            ),
            _buildKPICard(
              icon: Icons.store,
              title: 'Total Sellers',
              value: '${_kpiMetrics['totalSellers'] ?? 0}',
              gradient: [AppTheme.secondaryColor, AppTheme.accentColor],
            ),
            _buildKPICard(
              icon: Icons.shopping_cart,
              title: 'Total Buyers',
              value: '${_kpiMetrics['totalBuyers'] ?? 0}',
              gradient: [AppTheme.accentColor, AppTheme.primaryColor],
            ),
            _buildKPICard(
              icon: Icons.trending_up,
              title: 'Active Users (Today)',
              value: '${_kpiMetrics['activeUsersToday'] ?? 0}',
              gradient: [AppTheme.successColor, AppTheme.accentColor],
            ),
            _buildKPICard(
              icon: Icons.receipt_long,
              title: 'Total Orders',
              value: '${_kpiMetrics['totalOrders'] ?? 0}',
              change: _kpiMetrics['ordersChange'] != null
                  ? '${(_kpiMetrics['ordersChange'] as double).toStringAsFixed(1)}%'
                  : null,
              gradient: [AppTheme.infoColor, AppTheme.primaryColor],
            ),
            _buildKPICard(
              icon: Icons.attach_money,
              title: 'Total Revenue',
              value: '₹${(_kpiMetrics['totalRevenue'] ?? 0.0).toStringAsFixed(0)}',
              change: _kpiMetrics['revenueChange'] != null
                  ? '${(_kpiMetrics['revenueChange'] as double).toStringAsFixed(1)}%'
                  : null,
              gradient: [AppTheme.successColor, AppTheme.accentColor],
            ),
            _buildKPICard(
              icon: Icons.today,
              title: 'Orders Today',
              value: '${_kpiMetrics['ordersToday'] ?? 0}',
              gradient: [AppTheme.primaryColor, AppTheme.infoColor],
            ),
            _buildKPICard(
              icon: Icons.cancel,
              title: 'Cancelled Orders',
              value: '${_kpiMetrics['cancelledOrders'] ?? 0}',
              gradient: [AppTheme.errorColor, AppTheme.warningColor],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKPICard({
    required IconData icon,
    required String title,
    required String value,
    String? change,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              if (change != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    change,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection(bool isDesktop, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📈 Growth & Activity',
          style: AppTheme.heading2.copyWith(fontSize: 24),
        ),
        const SizedBox(height: 20),
        if (isDesktop)
          Row(
            children: [
              Expanded(child: _buildLineChart('New Users', _newUsersPerDay, 'count')),
              const SizedBox(width: 16),
              Expanded(child: _buildLineChart('Orders', _ordersPerDay, 'count')),
            ],
          )
        else
          Column(
            children: [
              _buildLineChart('New Users', _newUsersPerDay, 'count'),
              const SizedBox(height: 16),
              _buildLineChart('Orders', _ordersPerDay, 'count'),
            ],
          ),
        const SizedBox(height: 16),
        _buildBarChart('Revenue', _revenuePerDay),
      ],
    );
  }

  Widget _buildLineChart(String title, List<Map<String, dynamic>> data, String valueKey) {
    if (data.isEmpty) {
      return _buildEmptyChart(title);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.getCardDecoration(elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.heading3,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        (entry.value[valueKey] as num).toDouble(),
                      );
                    }).toList(),
                    isCurved: true,
                    color: AppTheme.primaryColor,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primaryColor.withOpacity(0.1),
                    ),
                  ),
                ],
                minY: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(String title, List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return _buildEmptyChart(title);
    }

    final maxRevenue = data.map((e) => e['revenue'] as double).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.getCardDecoration(elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.heading3,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: data.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value['revenue'] as double,
                        color: AppTheme.successColor,
                        width: 12,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
                maxY: maxRevenue * 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChart(String title) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: AppTheme.getCardDecoration(elevated: true),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 48, color: AppTheme.lightText),
            const SizedBox(height: 8),
            Text(
              'No data available for $title',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.lightText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerInsightsSection(bool isDesktop, bool isTablet) {
    final sellerList = _sellerInsights['sellerList'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🧑‍💼 Seller Insights',
          style: AppTheme.heading2.copyWith(fontSize: 24),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildMetricCard(
              'Active Sellers (7d)',
              '${_sellerInsights['activeSellers'] ?? 0}',
              AppTheme.successColor,
            ),
            _buildMetricCard(
              'Inactive Sellers',
              '${_sellerInsights['inactiveSellers'] ?? 0}',
              AppTheme.lightText,
            ),
            _buildMetricCard(
              'New Sellers Pending',
              '${_sellerInsights['newSellersPending'] ?? 0}',
              AppTheme.warningColor,
            ),
            _buildMetricCard(
              'Regular Sellers',
              '${_sellerInsights['regularSellers'] ?? 0}',
              AppTheme.primaryColor,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.getCardDecoration(elevated: true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top Sellers',
                style: AppTheme.heading3,
              ),
              const SizedBox(height: 16),
              if (sellerList.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(
                      'No seller data available',
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.lightText),
                    ),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Seller Name')),
                      DataColumn(label: Text('Type')),
                      DataColumn(label: Text('Items')),
                      DataColumn(label: Text('Orders')),
                      DataColumn(label: Text('Revenue')),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: sellerList.take(10).map((seller) {
                      return DataRow(
                        cells: [
                          DataCell(Text(seller['sellerName'] ?? 'Unknown')),
                          DataCell(Text(seller['sellerType'] ?? 'Regular')),
                          DataCell(Text('${seller['totalItems'] ?? 0}')),
                          DataCell(Text('${seller['totalOrders'] ?? 0}')),
                          DataCell(Text('₹${(seller['revenue'] ?? 0.0).toStringAsFixed(0)}')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (seller['status'] == 'active'
                                        ? AppTheme.successColor
                                        : AppTheme.lightText)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                seller['status'] ?? 'inactive',
                                style: TextStyle(
                                  color: seller['status'] == 'active'
                                      ? AppTheme.successColor
                                      : AppTheme.lightText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBuyerInsightsSection(bool isDesktop, bool isTablet) {
    final newBuyers = _buyerInsights['newBuyers'] ?? 0;
    final repeatBuyers = _buyerInsights['repeatBuyers'] ?? 0;
    final total = newBuyers + repeatBuyers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🛍 Buyer Insights',
          style: AppTheme.heading2.copyWith(fontSize: 24),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildMetricCard(
                    'Repeat Buyers',
                    '${_buyerInsights['repeatBuyers'] ?? 0}',
                    AppTheme.successColor,
                  ),
                  _buildMetricCard(
                    'Avg Orders/Buyer',
                    '${(_buyerInsights['avgOrdersPerBuyer'] ?? 0.0).toStringAsFixed(1)}',
                    AppTheme.primaryColor,
                  ),
                  _buildMetricCard(
                    'New Buyers Today',
                    '${_buyerInsights['newBuyersToday'] ?? 0}',
                    AppTheme.infoColor,
                  ),
                  _buildMetricCard(
                    'Buyers (No Orders)',
                    '${_buyerInsights['buyersWithNoOrders'] ?? 0}',
                    AppTheme.lightText,
                  ),
                ],
              ),
            ),
            if (isDesktop) ...[
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.getCardDecoration(elevated: true),
                  child: Column(
                    children: [
                      Text('New vs Returning', style: AppTheme.heading3),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 200,
                        child: total > 0
                            ? PieChart(
                                PieChartData(
                                  sections: [
                                    PieChartSectionData(
                                      value: newBuyers.toDouble(),
                                      title: 'New\n$newBuyers',
                                      color: AppTheme.primaryColor,
                                      radius: 80,
                                    ),
                                    PieChartSectionData(
                                      value: repeatBuyers.toDouble(),
                                      title: 'Returning\n$repeatBuyers',
                                      color: AppTheme.successColor,
                                      radius: 80,
                                    ),
                                  ],
                                ),
                              )
                            : Center(
                                child: Text(
                                  'No data',
                                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.lightText),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        if (!isDesktop) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.getCardDecoration(elevated: true),
            child: Column(
              children: [
                Text('New vs Returning', style: AppTheme.heading3),
                const SizedBox(height: 20),
                SizedBox(
                  height: 200,
                  child: total > 0
                      ? PieChart(
                          PieChartData(
                            sections: [
                              PieChartSectionData(
                                value: newBuyers.toDouble(),
                                title: 'New\n$newBuyers',
                                color: AppTheme.primaryColor,
                                radius: 80,
                              ),
                              PieChartSectionData(
                                value: repeatBuyers.toDouble(),
                                title: 'Returning\n$repeatBuyers',
                                color: AppTheme.successColor,
                                radius: 80,
                              ),
                            ],
                          ),
                        )
                      : Center(
                          child: Text(
                            'No data',
                            style: AppTheme.bodyMedium.copyWith(color: AppTheme.lightText),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProductPerformanceSection(bool isDesktop, bool isTablet) {
    final topProducts = _productPerformance['topProducts'] as List<dynamic>? ?? [];
    
    // topCategories should already be converted by convertMap
    final topCategories = _productPerformance['topCategories'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🍅 Product & Category Performance',
          style: AppTheme.heading2.copyWith(fontSize: 24),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildMetricCard(
              'Peak Ordering Time',
              _productPerformance['peakOrderingTime'] ?? 'Unknown',
              AppTheme.warningColor,
            ),
            ...topCategories.entries.take(4).map((entry) {
              return _buildMetricCard(
                entry.key,
                '${entry.value}',
                AppTheme.primaryColor,
              );
            }),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.getCardDecoration(elevated: true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top 10 Selling Products',
                style: AppTheme.heading3,
              ),
              const SizedBox(height: 16),
              if (topProducts.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(
                      'No product data available',
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.lightText),
                    ),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Units Sold')),
                      DataColumn(label: Text('Revenue')),
                      DataColumn(label: Text('Seller')),
                    ],
                    rows: topProducts.map((product) {
                      return DataRow(
                        cells: [
                          DataCell(Text(product['name'] ?? 'Unknown')),
                          DataCell(Text(product['category'] ?? 'Unknown')),
                          DataCell(Text('${product['unitsSold'] ?? 0}')),
                          DataCell(Text('₹${(product['revenue'] ?? 0.0).toStringAsFixed(0)}')),
                          DataCell(Text(product['sellerName'] ?? 'Unknown')),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformHealthSection(bool isDesktop, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '⚠️ Platform Health & Alerts',
          style: AppTheme.heading2.copyWith(fontSize: 24),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildAlertCard(
              'Failed Payments Today',
              '${_platformHealth['failedPaymentsToday'] ?? 0}',
              AppTheme.errorColor,
              Icons.payment,
            ),
            _buildAlertCard(
              'High Cancellation Sellers',
              '${_platformHealth['highCancellationSellers'] ?? 0}',
              AppTheme.warningColor,
              Icons.warning,
            ),
            _buildAlertCard(
              'Reported Products',
              '${_platformHealth['reportedProducts'] ?? 0}',
              AppTheme.errorColor,
              Icons.flag,
            ),
            _buildAlertCard(
              'Out of Stock Alerts',
              '${_platformHealth['outOfStockAlerts'] ?? 0}',
              AppTheme.warningColor,
              Icons.inventory_2,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.lightText),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTheme.heading3.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(String title, String value, Color color, IconData icon) {
    return InkWell(
      onTap: () {
        // Handle alert click
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Viewing details for: $title')),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: AppTheme.heading2.copyWith(
                      color: color,
                      fontSize: 28,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

