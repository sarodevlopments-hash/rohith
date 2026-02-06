import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/item_list.dart';
import '../services/item_list_service.dart';
import '../theme/app_theme.dart';
import 'add_listing_screen.dart';

class ManageItemListsScreen extends StatefulWidget {
  const ManageItemListsScreen({super.key});

  @override
  State<ManageItemListsScreen> createState() => _ManageItemListsScreenState();
}

class _ManageItemListsScreenState extends State<ManageItemListsScreen> {
  List<ItemList> _itemLists = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadItemLists();
  }

  Future<void> _loadItemLists() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sellerId = FirebaseAuth.instance.currentUser?.uid;
      if (sellerId == null) {
        setState(() {
          _error = 'Please log in to manage item lists';
          _isLoading = false;
        });
        return;
      }

      final lists = await ItemListService.getItemLists(sellerId);
      print('📋 Loaded ${lists.length} item lists');
      for (var list in lists) {
        print('  - "${list.name}": ${list.itemCount} items');
      }
      
      setState(() {
        _itemLists = lists;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading item lists: $e');
      setState(() {
        _error = 'Failed to load item lists: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteList(ItemList list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete List?'),
        content: Text('Are you sure you want to delete "${list.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ItemListService.deleteItemList(list.sellerId, list.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${list.name}" deleted')),
          );
          _loadItemLists();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  Future<void> _renameList(ItemList list) async {
    final controller = TextEditingController(text: list.name);
    final confirmed = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename List'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'List Name',
            hintText: 'e.g., Daily Grocery List',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != null && confirmed.isNotEmpty && confirmed != list.name) {
      try {
        await ItemListService.updateItemList(
          sellerId: list.sellerId,
          listId: list.id,
          name: confirmed,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('List renamed')),
          );
          _loadItemLists();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to rename: $e')),
          );
        }
      }
    }
  }

  Future<void> _duplicateList(ItemList list) async {
    final controller = TextEditingController(text: '${list.name} (Copy)');
    final confirmed = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate List'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New List Name',
            hintText: 'e.g., Daily Grocery List (Copy)',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );

    if (confirmed != null && confirmed.isNotEmpty) {
      try {
        await ItemListService.duplicateItemList(
          sellerId: list.sellerId,
          listId: list.id,
          newName: confirmed,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"$confirmed" created')),
          );
          _loadItemLists();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to duplicate: $e')),
          );
        }
      }
    }
  }

  Future<void> _editList(ItemList list) async {
    // Navigate to add listing screen with the list items pre-loaded
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddListingScreen(
          initialItemList: list,
        ),
      ),
    );
    // Reload lists when returning
    _loadItemLists();
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage Item Lists',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                fontSize: 18,
              ),
            ),
            if (_itemLists.isNotEmpty)
              Text(
                '${_itemLists.length} ${_itemLists.length == 1 ? 'list' : 'lists'} saved',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadItemLists,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _itemLists.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.list_alt, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No saved lists yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create lists while adding items',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadItemLists,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _itemLists.length,
                        itemBuilder: (context, index) {
                          final list = _itemLists[index];
                          final isLastUsed = index == 0 && list.lastUsedAt != null;
                          final isMostUsed = list.usageCount > 0 &&
                              _itemLists.where((l) => l.usageCount > list.usageCount).isEmpty;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _editList(list),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primaryColor.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Icon(
                                                    Icons.inventory_2_rounded,
                                                    color: AppTheme.primaryColor,
                                                    size: 20,
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
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ),
                                                          if (isLastUsed)
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 4,
                                                              ),
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
                                                          if (isMostUsed && !isLastUsed)
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 4,
                                                              ),
                                                              decoration: BoxDecoration(
                                                                color: Colors.green.shade50,
                                                                borderRadius: BorderRadius.circular(12),
                                                              ),
                                                              child: Text(
                                                                'Most Used',
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: Colors.green.shade700,
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
                                                      if (list.items.isNotEmpty) ...[
                                                        const SizedBox(height: 8),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: Colors.grey.shade100,
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            list.items.take(3).map((item) => item.name).join(', ') + 
                                                            (list.items.length > 3 ? '...' : ''),
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors.grey.shade700,
                                                              fontStyle: FontStyle.italic,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                                            onSelected: (value) {
                                              switch (value) {
                                                case 'edit':
                                                  _editList(list);
                                                  break;
                                                case 'duplicate':
                                                  _duplicateList(list);
                                                  break;
                                                case 'rename':
                                                  _renameList(list);
                                                  break;
                                                case 'delete':
                                                  _deleteList(list);
                                                  break;
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit, size: 18),
                                                    SizedBox(width: 8),
                                                    Text('Edit List'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'duplicate',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.copy, size: 18),
                                                    SizedBox(width: 8),
                                                    Text('Duplicate'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'rename',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.drive_file_rename_outline, size: 18),
                                                    SizedBox(width: 8),
                                                    Text('Rename'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                                    SizedBox(width: 8),
                                                    Text('Delete', style: TextStyle(color: Colors.red)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

