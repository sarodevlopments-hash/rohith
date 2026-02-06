import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import '../models/listing.dart';
import '../models/scheduled_listing.dart';
import '../services/scheduled_listing_service.dart';
import '../models/measurement_unit.dart';
import '../models/item_list.dart';
import '../services/item_list_service.dart';
import '../theme/app_theme.dart';
import 'manage_item_lists_screen.dart';
import 'add_listing_screen.dart';
import '../models/pending_listing_item.dart';

class SellerItemManagementScreen extends StatefulWidget {
  final String sellerId;

  const SellerItemManagementScreen({super.key, required this.sellerId});

  @override
  State<SellerItemManagementScreen> createState() => _SellerItemManagementScreenState();
}

class _SellerItemManagementScreenState extends State<SellerItemManagementScreen> {
  List<ItemList> _savedItemLists = [];
  bool _isLoadingLists = false;
  final Set<String> _expandedListIds = {}; // Track which lists are expanded

  @override
  void initState() {
    super.initState();
    _loadSavedItemLists();
  }

  Future<void> _loadSavedItemLists() async {
    setState(() => _isLoadingLists = true);
    try {
      final lists = await ItemListService.getItemLists(widget.sellerId);
      setState(() {
        _savedItemLists = lists;
        _isLoadingLists = false;
      });
    } catch (e) {
      setState(() => _isLoadingLists = false);
      print('Failed to load item lists: $e');
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Items'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Listing>('listingBox').listenable(),
        builder: (context, Box<Listing> box, _) {
          return ValueListenableBuilder(
            valueListenable: Hive.box<ScheduledListing>('scheduledListingsBox').listenable(),
            builder: (context, Box<ScheduledListing> scheduledBox, _) {
              final myListings = box.values
                  .where((l) => l.sellerId == widget.sellerId)
                  .toList()
                ..sort((a, b) => b.key.toString().compareTo(a.key.toString()));

              final scheduledListings = ScheduledListingService.getScheduledListings(widget.sellerId);

              if (myListings.isEmpty && scheduledListings.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No items posted yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Saved Item Lists Section
                  if (_isLoadingLists)
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_savedItemLists.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader('Saved Item Lists', Icons.inventory_2_rounded, AppTheme.primaryColor),
                        TextButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ManageItemListsScreen(),
                              ),
                            );
                            if (result == true) {
                              _loadSavedItemLists();
                            }
                          },
                          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                          label: const Text('Manage All'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._savedItemLists.take(3).map((list) => _buildItemListCard(context, list)),
                    if (_savedItemLists.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(
                          child: TextButton(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ManageItemListsScreen(),
                                ),
                              );
                              if (result == true) {
                                _loadSavedItemLists();
                              }
                            },
                            child: Text(
                              'View All ${_savedItemLists.length} Lists',
                              style: TextStyle(color: AppTheme.primaryColor),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Active Listings Section
                  if (myListings.isNotEmpty) ...[
                    _buildSectionHeader('Active Listings', Icons.check_circle, Colors.green),
                    const SizedBox(height: 12),
                    ...myListings.map((listing) => _buildItemCard(context, listing)),
                    const SizedBox(height: 24),
                  ],
                  
                  // Scheduled Listings Section
                  if (scheduledListings.isNotEmpty) ...[
                    _buildSectionHeader('Scheduled Listings', Icons.schedule, Colors.blue),
                    const SizedBox(height: 12),
                    ...scheduledListings.map((scheduled) => _buildScheduledItemCard(context, scheduled)),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color is MaterialColor ? color.shade700 : color,
          ),
        ),
      ],
    );
  }

  Widget _buildItemListCard(BuildContext context, ItemList list) {
    // Ensure list has a valid ID
    if (list.id.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final isLastUsed = _savedItemLists.isNotEmpty && 
        _savedItemLists.first.lastUsedAt != null && 
        list.id == _savedItemLists.first.id;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              list.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isLastUsed)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Last Used',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${list.itemCount} ${list.itemCount == 1 ? 'item' : 'items'} • Updated ${_formatDate(list.updatedAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Show items if expanded, or show View button if collapsed
            if (list.items.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              if (list.id.isNotEmpty && _expandedListIds.contains(list.id)) ...[
                // Expanded view - show all items
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Items in this list:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          if (list.id.isNotEmpty) {
                            _expandedListIds.remove(list.id);
                          }
                        });
                      },
                      icon: const Icon(Icons.expand_less, size: 18),
                      label: const Text('Hide'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...list.items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return _buildListItemRow(context, list, item, index);
                }),
              ] else ...[
                // Collapsed view - show View button
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        if (list.id.isNotEmpty) {
                          _expandedListIds.add(list.id);
                        }
                      });
                    },
                    icon: const Icon(Icons.visibility, size: 18),
                    label: Text('View ${list.itemCount} ${list.itemCount == 1 ? 'item' : 'items'}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            // Edit and Delete buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Navigate to Start Selling page to edit the list
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddListingScreen(
                            initialItemList: list,
                          ),
                        ),
                      ).then((_) => _loadSavedItemLists()); // Reload after editing
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDeleteListConfirmation(context, list),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListItemRow(BuildContext context, ItemList list, PendingListingItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '₹${item.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Qty: ${item.quantity}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => _showDeleteItemConfirmation(context, list, item, index),
            tooltip: 'Delete item',
          ),
        ],
      ),
    );
  }

  void _showDeleteItemConfirmation(BuildContext context, ItemList list, PendingListingItem item, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text('Are you sure you want to delete "${item.name}" from "${list.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Create updated items list without the deleted item
                final updatedItems = List<PendingListingItem>.from(list.items);
                updatedItems.removeAt(index);

                // If no items left, delete the entire list
                if (updatedItems.isEmpty) {
                  await ItemListService.deleteItemList(list.sellerId, list.id);
                  Navigator.pop(context);
                  _loadSavedItemLists();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('List deleted (no items remaining)'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  // Update list with remaining items
                  await ItemListService.updateItemList(
                    sellerId: list.sellerId,
                    listId: list.id,
                    items: updatedItems,
                  );
                  Navigator.pop(context);
                  _loadSavedItemLists();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('"${item.name}" deleted from list'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete item: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, Listing listing) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: listing.imagePath != null
                      ? (kIsWeb
                          ? Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.fastfood),
                            )
                          : File(listing.imagePath!).existsSync()
                              ? Image.file(
                                  File(listing.imagePath!),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.fastfood),
                                ))
                      : Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.fastfood, size: 40),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Price: ₹${listing.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      if (listing.isLiveKitchen) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              listing.isKitchenOpen ? Icons.restaurant : Icons.restaurant_outlined,
                              size: 14,
                              color: listing.isKitchenOpen ? Colors.green.shade700 : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              listing.isKitchenOpen 
                                  ? 'Kitchen Open • ${listing.remainingCapacity} slots'
                                  : 'Kitchen Closed',
                              style: TextStyle(
                                fontSize: 13,
                                color: listing.isKitchenOpen ? Colors.green.shade700 : Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        if (listing.preparationTimeMinutes != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.timer, size: 12, color: Colors.orange.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'Prep: ${listing.preparationTimeMinutes} mins',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ] else ...[
                        Text(
                          'Available: ${listing.quantity} ${listing.measurementUnit?.shortLabel ?? "units"}',
                          style: TextStyle(
                            fontSize: 14,
                            color: listing.quantity > 0 ? Colors.green.shade700 : Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            // Live Kitchen Toggle (if applicable)
            if (listing.isLiveKitchen) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: listing.isKitchenOpen ? Colors.green.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: listing.isKitchenOpen ? Colors.green.shade300 : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          listing.isKitchenOpen ? Icons.restaurant : Icons.restaurant_outlined,
                          color: listing.isKitchenOpen ? Colors.green.shade700 : Colors.grey.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              listing.isKitchenOpen ? '🔥 Kitchen is Open' : 'Kitchen is Closed',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: listing.isKitchenOpen ? Colors.green.shade800 : Colors.grey.shade700,
                              ),
                            ),
                            if (listing.isKitchenOpen) ...[
                              Text(
                                '${listing.remainingCapacity} order slots available',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: listing.isKitchenOpen,
                      onChanged: (value) {
                        listing.isKitchenOpen = value;
                        listing.save();
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value 
                                  ? 'Kitchen opened! Orders can now be placed.' 
                                  : 'Kitchen closed. No new orders will be accepted.',
                            ),
                            backgroundColor: value ? Colors.green : Colors.orange,
                          ),
                        );
                      },
                      activeColor: Colors.green,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditDialog(context, listing),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDeleteConfirmation(context, listing),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduledItemCard(BuildContext context, ScheduledListing scheduled) {
    final listing = scheduled.listingData;
    final nextPostTime = scheduled.getNextPostingTime(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: listing.imagePath != null
                      ? (kIsWeb
                          ? Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.fastfood),
                            )
                          : File(listing.imagePath!).existsSync()
                              ? Image.file(
                                  File(listing.imagePath!),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.fastfood),
                                ))
                      : Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.fastfood, size: 40),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              listing.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: scheduled.isActive ? Colors.green.shade100 : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              scheduled.isActive ? 'Active' : 'Paused',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: scheduled.isActive ? Colors.green.shade700 : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Price: ₹${listing.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Schedule Info
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.repeat, size: 16, color: Colors.blue.shade700),
                                const SizedBox(width: 6),
                                Text(
                                  'Frequency: ${scheduled.scheduleType.name.toUpperCase()}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 16, color: Colors.green.shade700),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Opens at: ${_formatTime(scheduled.scheduleTime)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (scheduled.scheduleCloseTime != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.schedule, size: 16, color: Colors.red.shade700),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Closes at: ${_formatTime(scheduled.scheduleCloseTime!)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (nextPostTime != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 16, color: Colors.orange.shade700),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Next post: ${_formatDateTime(nextPostTime)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditDialogForScheduled(context, scheduled),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        if (scheduled.isActive) {
                          ScheduledListingService.pauseScheduledListing(scheduled.scheduledId);
                        } else {
                          ScheduledListingService.resumeScheduledListing(scheduled.scheduledId);
                        }
                      });
                    },
                    icon: Icon(
                      scheduled.isActive ? Icons.pause : Icons.play_arrow,
                      size: 18,
                    ),
                    label: Text(scheduled.isActive ? 'Pause' : 'Resume'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDeleteScheduledConfirmation(context, scheduled),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  String _formatDateTime(DateTime dateTime) {
    return "${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  void _showEditDialog(BuildContext context, Listing listing) {
    final quantityController = TextEditingController(text: listing.quantity.toString());
    final priceController = TextEditingController(text: listing.price.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Item: ${listing.name}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  hintText: 'Enter quantity',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.inventory_2),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Price (₹)',
                  hintText: 'Enter price',
                  prefixText: '₹',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.currency_rupee),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newQuantity = int.tryParse(quantityController.text);
              final newPrice = double.tryParse(priceController.text);
              
              bool hasError = false;
              String errorMessage = '';
              
              if (newQuantity == null || newQuantity < 0) {
                hasError = true;
                errorMessage = 'Please enter a valid quantity (≥ 0)';
              } else if (newPrice == null || newPrice <= 0) {
                hasError = true;
                errorMessage = 'Please enter a valid price (> 0)';
              }
              
              if (hasError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(errorMessage)),
                );
                return;
              }
              
              // Update quantity (can be updated directly)
              listing.quantity = newQuantity!;
              
              // Update price (need to create new listing since price is final)
              if (newPrice != listing.price) {
                final updatedListing = Listing(
                  name: listing.name,
                  sellerName: listing.sellerName,
                  price: newPrice!,
                  originalPrice: listing.originalPrice,
                  quantity: newQuantity,
                  initialQuantity: listing.initialQuantity,
                  sellerId: listing.sellerId,
                  type: listing.type,
                  fssaiLicense: listing.fssaiLicense,
                  preparedAt: listing.preparedAt,
                  expiryDate: listing.expiryDate,
                  category: listing.category,
                  cookedFoodSource: listing.cookedFoodSource,
                  imagePath: listing.imagePath,
                  measurementUnit: listing.measurementUnit,
                  packSizes: listing.packSizes,
                  isBulkFood: listing.isBulkFood,
                  servesCount: listing.servesCount,
                  portionDescription: listing.portionDescription,
                  isKitchenOpen: listing.isKitchenOpen,
                  preparationTimeMinutes: listing.preparationTimeMinutes,
                  maxCapacity: listing.maxCapacity,
                );
                
                final listingBox = Hive.box<Listing>('listingBox');
                final oldKey = listing.key;
                listing.delete();
                if (oldKey != null) {
                  listingBox.put(oldKey, updatedListing);
                } else {
                  listingBox.add(updatedListing);
                }
              } else {
                listing.save();
              }
              
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Item updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditDialogForScheduled(BuildContext context, ScheduledListing scheduled) {
    final listing = scheduled.listingData;
    final quantityController = TextEditingController(text: listing.quantity.toString());
    final priceController = TextEditingController(text: listing.price.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Scheduled Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Item: ${listing.name}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  hintText: 'Enter quantity',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.inventory_2),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Price (₹)',
                  hintText: 'Enter price',
                  prefixText: '₹',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.currency_rupee),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newQuantity = int.tryParse(quantityController.text);
              final newPrice = double.tryParse(priceController.text);
              
              bool hasError = false;
              String errorMessage = '';
              
              if (newQuantity == null || newQuantity < 0) {
                hasError = true;
                errorMessage = 'Please enter a valid quantity (≥ 0)';
              } else if (newPrice == null || newPrice <= 0) {
                hasError = true;
                errorMessage = 'Please enter a valid price (> 0)';
              }
              
              if (hasError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(errorMessage)),
                );
                return;
              }
              
              // Check if any changes were made
              final quantityChanged = newQuantity != listing.quantity;
              final priceChanged = newPrice != listing.price;
              
              if (!quantityChanged && !priceChanged) {
                Navigator.pop(context);
                return;
              }
              
              // Create updated listing with new values
              final updatedListing = Listing(
                name: listing.name,
                sellerName: listing.sellerName,
                price: newPrice!,
                originalPrice: listing.originalPrice,
                quantity: newQuantity!,
                initialQuantity: listing.initialQuantity,
                sellerId: listing.sellerId,
                type: listing.type,
                fssaiLicense: listing.fssaiLicense,
                preparedAt: listing.preparedAt,
                expiryDate: listing.expiryDate,
                category: listing.category,
                cookedFoodSource: listing.cookedFoodSource,
                imagePath: listing.imagePath,
                measurementUnit: listing.measurementUnit,
                packSizes: listing.packSizes,
                isBulkFood: listing.isBulkFood,
                servesCount: listing.servesCount,
                portionDescription: listing.portionDescription,
                isKitchenOpen: listing.isKitchenOpen,
                preparationTimeMinutes: listing.preparationTimeMinutes,
                maxCapacity: listing.maxCapacity,
              );
              
              // Create new ScheduledListing with updated listing data
              final updatedScheduled = ScheduledListing(
                scheduledId: scheduled.scheduledId,
                listingData: updatedListing,
                scheduleType: scheduled.scheduleType,
                scheduleStartDate: scheduled.scheduleStartDate,
                scheduleEndDate: scheduled.scheduleEndDate,
                scheduleTime: scheduled.scheduleTime,
                scheduleCloseTime: scheduled.scheduleCloseTime,
                dayOfWeek: scheduled.dayOfWeek,
                sellerId: scheduled.sellerId,
                lastPostedAt: scheduled.lastPostedAt,
                isActive: scheduled.isActive,
                createdAt: scheduled.createdAt,
              );
              
              // Replace the old scheduled listing
              final scheduledBox = Hive.box<ScheduledListing>('scheduledListingsBox');
              final oldKey = scheduled.key;
              scheduled.delete();
              if (oldKey != null) {
                scheduledBox.put(oldKey, updatedScheduled);
              } else {
                scheduledBox.add(updatedScheduled);
              }
              
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Scheduled item updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Listing listing) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text('Are you sure you want to delete "${listing.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              listing.delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Item deleted successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }


  void _showDeleteListConfirmation(BuildContext context, ItemList list) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete List?'),
        content: Text('Are you sure you want to delete "${list.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ItemListService.deleteItemList(list.sellerId, list.id);
                Navigator.pop(context);
                _loadSavedItemLists();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('List deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete list: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteScheduledConfirmation(BuildContext context, ScheduledListing scheduled) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Scheduled Item?'),
        content: Text('Are you sure you want to delete the scheduled item "${scheduled.listingData.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ScheduledListingService.deleteScheduledListing(scheduled.scheduledId);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Scheduled item deleted successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
