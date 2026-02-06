import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/item_list.dart';
import '../models/pending_listing_item.dart';

class ItemListService {
  // Use the correct database ID: 'reqfood' (not the default)
  static FirebaseFirestore get _firestore => FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'reqfood',
  );
  
  /// Get the collection reference for a seller's item lists
  static CollectionReference _getItemListsCollection(String sellerId) {
    return _firestore
        .collection('userProfiles')
        .doc(sellerId)
        .collection('itemLists');
  }

  /// Save a new item list
  static Future<String> saveItemList({
    required String sellerId,
    required String name,
    required List<PendingListingItem> items,
  }) async {
    if (items.isEmpty) {
      throw Exception('Cannot save an empty item list');
    }

    if (name.trim().isEmpty) {
      throw Exception('List name cannot be empty');
    }

    try {
      final id = _getItemListsCollection(sellerId).doc().id;
      final now = DateTime.now();

      final itemList = ItemList(
        id: id,
        sellerId: sellerId,
        name: name.trim(),
        items: items,
        createdAt: now,
        updatedAt: now,
        usageCount: 0,
      );

      final itemMap = itemList.toMap();
      print('📦 Saving item list: "$name" with ${items.length} items');
      print('📂 Collection path: userProfiles/$sellerId/itemLists');
      print('🆔 Document ID: $id');
      print('👤 Seller ID: $sellerId');
      final currentAuthUid = FirebaseAuth.instance.currentUser?.uid;
      print('🔑 Current Auth UID: $currentAuthUid');
      if (currentAuthUid != sellerId) {
        print('⚠️ WARNING: sellerId ($sellerId) != auth.uid ($currentAuthUid)');
      }
      
      // Verify data structure
      print('📋 Data keys: ${itemMap.keys.toList()}');
      print('📋 Items count in map: ${(itemMap['items'] as List?)?.length ?? 0}');
      print('📋 sellerId in map: ${itemMap['sellerId']}');
      print('📋 sellerId type: ${itemMap['sellerId'].runtimeType}');
      
      // Verify auth before attempting write
      final auth = FirebaseAuth.instance.currentUser;
      if (auth == null) {
        throw Exception('Not authenticated. Please log in first.');
      }
      if (auth.uid != sellerId) {
        throw Exception('Seller ID mismatch. Expected ${auth.uid}, got $sellerId');
      }
      
      // Verify sellerId matches auth.uid (required by rules)
      if (itemMap['sellerId'] != auth.uid) {
        print('⚠️ WARNING: sellerId in data (${itemMap['sellerId']}) != auth.uid (${auth.uid})');
        print('⚠️ Rules require: request.resource.data.sellerId == request.auth.uid');
        // Fix it
        itemMap['sellerId'] = auth.uid;
        print('✅ Fixed sellerId in data to match auth.uid');
      }
      
      print('🔄 Attempting Firestore write to: userProfiles/$sellerId/itemLists/$id');
      print('📝 Data being written:');
      print('   - sellerId: ${itemMap['sellerId']} (must match auth.uid: ${auth.uid})');
      print('   - name: ${itemMap['name']}');
      print('   - items count: ${(itemMap['items'] as List).length}');
      print('✅ Auth verified: ${auth.uid}');
      print('🗄️ Using database: reqfood (matching other services)');
      
      // Use proper subcollection reference
      final itemListsCollection = _getItemListsCollection(sellerId);
      print('🔄 Writing to Firestore subcollection...');
      print('📡 Collection reference: ${itemListsCollection.path}');
      print('📡 Database ID: reqfood');
      
      await itemListsCollection
          .doc(id)
          .set(itemMap, SetOptions(merge: false))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              print('');
              print('⏱️⏱️⏱️ FIRESTORE WRITE TIMEOUT ⏱️⏱️⏱️');
              print('');
              print('💡 This timeout usually means:');
              print('   1. Rules are blocking the write (most common)');
              print('   2. Rules not published or missing itemLists section');
              print('   3. Network connectivity issues');
              print('   4. Rules propagation delay (wait 2-3 minutes)');
              print('');
              print('🔍 Debug info:');
              print('   Path: userProfiles/$sellerId/itemLists/$id');
              print('   Auth UID: ${auth.uid}');
              print('   Seller ID: $sellerId');
              print('   Expected rule: userProfiles/{userId}/itemLists/{listId}');
              print('   Rule should match: userId=$sellerId, listId=$id');
              print('');
              print('📋 ACTION REQUIRED:');
              print('   1. Go to: https://console.firebase.google.com/project/resqfood-66b5f/firestore/rules');
              print('   2. Copy ENTIRE firestore.rules file (all 78 lines)');
              print('   3. Paste into Firebase Console Rules editor');
              print('   4. Click "Publish" (NOT just Save)');
              print('   5. Wait for "Rules published successfully"');
              print('   6. Check "Last published" timestamp is recent');
              print('   7. Wait 2-3 minutes after publishing');
              print('   8. Restart your Flutter app completely');
              print('');
              throw TimeoutException('Save operation timed out. Please verify Firestore rules are published and include itemLists subcollection.');
            },
          );

      print('✅ Item list saved successfully: $id');
      return id;
    } on FirebaseException catch (e) {
      print('🔥 Firestore exception caught:');
      print('   Code: ${e.code}');
      print('   Message: ${e.message}');
      print('   Stack: ${e.stackTrace}');
      
      if (e.code == 'permission-denied' || e.message?.contains('Missing or insufficient') == true) {
        print('🚫 PERMISSION DENIED - Rules are blocking!');
        print('   Verify in Firebase Console that itemLists rules exist:');
        print('   match /userProfiles/{userId} {');
        print('     match /itemLists/{listId} { ... }');
        print('   }');
        throw Exception('Permission denied. Please verify Firestore rules include the itemLists subcollection section (lines 52-61).');
      } else if (e.code == 'unavailable' || e.message?.contains('offline') == true) {
        throw Exception('Firestore unavailable. Please check your internet connection and try again.');
      } else if (e.code == 'deadline-exceeded') {
        throw Exception('Request deadline exceeded. This may indicate network issues or rules not propagated yet.');
      }
      throw Exception('Firestore error (${e.code}): ${e.message}');
    } on TimeoutException catch (e) {
      print('⏱️ TimeoutException: ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ Unexpected error saving item list: $e');
      print('   Type: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Get all item lists for a seller
  static Future<List<ItemList>> getItemLists(String sellerId) async {
    try {
      final snapshot = await _getItemListsCollection(sellerId)
          .orderBy('updatedAt', descending: true)
          .get();

      final lists = snapshot.docs
          .map((doc) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              return ItemList.fromMap(data);
            } catch (e) {
              print('Error parsing item list ${doc.id}: $e');
              return null;
            }
          })
          .where((list) => list != null)
          .cast<ItemList>()
          .toList();
      
      // Sort by lastUsedAt manually (nulls go to end)
      lists.sort((a, b) {
        if (a.lastUsedAt == null && b.lastUsedAt == null) return 0;
        if (a.lastUsedAt == null) return 1;
        if (b.lastUsedAt == null) return -1;
        return b.lastUsedAt!.compareTo(a.lastUsedAt!);
      });
      
      return lists;
    } catch (e) {
      print('Error loading item lists: $e');
      return [];
    }
  }

  /// Get a specific item list by ID
  static Future<ItemList?> getItemList(String sellerId, String listId) async {
    final doc = await _getItemListsCollection(sellerId)
        .doc(listId)
        .get();

    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>;
    return ItemList.fromMap(data);
  }

  /// Update an existing item list
  static Future<void> updateItemList({
    required String sellerId,
    required String listId,
    String? name,
    List<PendingListingItem>? items,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': DateTime.now().toIso8601String(),
    };

    if (name != null) {
      updates['name'] = name;
    }

    if (items != null) {
      updates['items'] = items.map((item) => ItemList.itemToMap(item)).toList();
    }

    await _getItemListsCollection(sellerId)
        .doc(listId)
        .update(updates);
  }

  /// Delete an item list
  static Future<void> deleteItemList(String sellerId, String listId) async {
    await _getItemListsCollection(sellerId)
        .doc(listId)
        .delete();
  }

  /// Mark an item list as used (increment usage count and update lastUsedAt)
  static Future<void> markListAsUsed(String sellerId, String listId) async {
    final list = await getItemList(sellerId, listId);
    if (list == null) return;

    await _getItemListsCollection(sellerId)
        .doc(listId)
        .update({
      'lastUsedAt': DateTime.now().toIso8601String(),
      'usageCount': list.usageCount + 1,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Duplicate an item list with a new name
  static Future<String> duplicateItemList({
    required String sellerId,
    required String listId,
    required String newName,
  }) async {
    final originalList = await getItemList(sellerId, listId);
    if (originalList == null) {
      throw Exception('Item list not found');
    }

    return await saveItemList(
      sellerId: sellerId,
      name: newName,
      items: originalList.items,
    );
  }

  /// Get the most used item list
  static Future<ItemList?> getMostUsedList(String sellerId) async {
    final lists = await getItemLists(sellerId);
    if (lists.isEmpty) return null;

    lists.sort((a, b) => b.usageCount.compareTo(a.usageCount));
    return lists.first;
  }

  /// Get the last used item list
  static Future<ItemList?> getLastUsedList(String sellerId) async {
    final lists = await getItemLists(sellerId);
    if (lists.isEmpty) return null;

    // Filter lists that have been used at least once
    final usedLists = lists.where((list) => list.lastUsedAt != null).toList();
    if (usedLists.isEmpty) return null;

    usedLists.sort((a, b) {
      final aTime = a.lastUsedAt ?? DateTime(1970);
      final bTime = b.lastUsedAt ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });

    return usedLists.first;
  }
}

