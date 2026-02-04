import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/buyer_address.dart';

/// Service to manage buyer delivery addresses in Firestore
class BuyerAddressService {
  static FirebaseFirestore get _db => FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'reqfood',
  );

  static String _getCollectionPath(String userId) {
    return 'userProfiles/$userId/addresses';
  }

  /// Get all addresses for a user
  static Future<List<BuyerAddress>> getAddresses(String userId) async {
    try {
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        throw Exception('Unauthorized: User ID mismatch');
      }

      final snapshot = await _db
          .collection(_getCollectionPath(userId))
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => BuyerAddress.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('❌ Error fetching addresses: $e');
      return [];
    }
  }

  /// Add a new address
  static Future<String?> addAddress(String userId, BuyerAddress address) async {
    try {
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        throw Exception('Unauthorized: User ID mismatch');
      }

      // If this is set as default, unset all other defaults
      if (address.isDefault) {
        await _unsetAllDefaults(userId);
      }

      final docRef = await _db.collection(_getCollectionPath(userId)).add(address.toMap());
      return docRef.id;
    } catch (e) {
      print('❌ Error adding address: $e');
      return null;
    }
  }

  /// Update an existing address
  static Future<bool> updateAddress(String userId, BuyerAddress address) async {
    try {
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        throw Exception('Unauthorized: User ID mismatch');
      }

      // If this is set as default, unset all other defaults
      if (address.isDefault) {
        await _unsetAllDefaults(userId, excludeId: address.id);
      }

      await _db
          .collection(_getCollectionPath(userId))
          .doc(address.id)
          .update({
            ...address.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      return true;
    } catch (e) {
      print('❌ Error updating address: $e');
      return false;
    }
  }

  /// Delete an address
  static Future<bool> deleteAddress(String userId, String addressId) async {
    try {
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        throw Exception('Unauthorized: User ID mismatch');
      }

      await _db.collection(_getCollectionPath(userId)).doc(addressId).delete();
      return true;
    } catch (e) {
      print('❌ Error deleting address: $e');
      return false;
    }
  }

  /// Set an address as default (unset all others)
  static Future<bool> setDefaultAddress(String userId, String addressId) async {
    try {
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        throw Exception('Unauthorized: User ID mismatch');
      }

      // Unset all defaults first
      await _unsetAllDefaults(userId, excludeId: addressId);

      // Set this one as default
      await _db
          .collection(_getCollectionPath(userId))
          .doc(addressId)
          .update({
            'isDefault': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      return true;
    } catch (e) {
      print('❌ Error setting default address: $e');
      return false;
    }
  }

  /// Get the default address
  static Future<BuyerAddress?> getDefaultAddress(String userId) async {
    try {
      final addresses = await getAddresses(userId);
      return addresses.firstWhere(
        (addr) => addr.isDefault,
        orElse: () => addresses.isNotEmpty ? addresses.first : BuyerAddress(
          id: '',
          label: '',
          fullAddress: '',
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      print('❌ Error getting default address: $e');
      return null;
    }
  }

  /// Helper: Unset all default addresses
  static Future<void> _unsetAllDefaults(String userId, {String? excludeId}) async {
    final snapshot = await _db
        .collection(_getCollectionPath(userId))
        .where('isDefault', isEqualTo: true)
        .get();

    final batch = _db.batch();
    for (var doc in snapshot.docs) {
      if (doc.id != excludeId) {
        batch.update(doc.reference, {
          'isDefault': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    if (snapshot.docs.isNotEmpty) {
      await batch.commit();
    }
  }
}

