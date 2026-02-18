import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import '../models/listing.dart';
import 'listing_firestore_service.dart';
import 'firestore_helper.dart';

/// Real-time sync service for listings from Firestore to Hive
/// Similar to OrderSyncService, this keeps listings synchronized across devices
class ListingSyncService {
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _listingsSub;
  static String? _activeUid;

  /// Start real-time sync for listings
  static Future<void> start() async {
    print('🔍 ListingSyncService.start() called');
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      print('⚠️ ListingSyncService: No authenticated user - skipping Firestore sync');
      print('   Current auth state: ${FirebaseAuth.instance.currentUser}');
      return;
    }
    print('   User authenticated: $uid');
    
    if (_activeUid == uid && _listingsSub != null) {
      print('   ✅ ListingSyncService already active for this user, skipping');
      return;
    }

    await stop();
    _activeUid = uid;
    print('🔍 ListingSyncService: Starting real-time sync for authenticated user: $uid');

    // ✅ Start real-time listener FIRST (this is the most important part)
    // The initial load can happen in parallel - if it times out, the real-time listener will still sync everything
    // Use FirestoreHelper which automatically falls back to default if named DB doesn't exist
    final db = FirestoreHelper.db;
    final listings = db.collection('listings');
    
    // Listen to all listings (all users can see all listings)
    try {
      print('🔗 ListingSyncService: Creating real-time subscription...');
      print('   Database: ${FirestoreHelper.activeDatabaseId ?? "unknown"}, Collection: listings');
      print('   User UID: $uid');
      
      _listingsSub = listings.snapshots().listen(
        (snapshot) {
          print('📡 ListingSyncService: Received real-time update (${snapshot.docChanges.length} changes, ${snapshot.docs.length} total docs)');
          _applySnapshot(snapshot);
        },
        onError: (error) {
          print('❌ ListingSyncService: Error in real-time listener: $error');
          print('   Error type: ${error.runtimeType}');
          print('   Error details: ${error.toString()}');
          if (error.toString().contains('permission-denied')) {
            print('🔴 CRITICAL: Firestore rules are blocking access to listings collection!');
            print('   This will prevent real-time sync from working.');
            print('   Check: https://console.firebase.google.com/project/resqfood-66b5f/firestore/rules');
            _printCriticalInstructions();
            // Try to restart after a delay
            Future.delayed(const Duration(seconds: 5), () {
              if (_activeUid == uid) {
                print('🔄 ListingSyncService: Attempting to restart after permission error...');
                start();
              }
            });
          }
          // Don't cancel - keep trying (cancelOnError: false)
        },
        onDone: () {
          print('⚠️ ListingSyncService: Real-time subscription closed (onDone callback)');
          print('   This should not happen unless explicitly cancelled');
          print('   Current UID: $_activeUid, Expected UID: $uid');
          _listingsSub = null;
          // Try to restart if we're still the active user
          if (_activeUid == uid) {
            print('🔄 ListingSyncService: Attempting to restart after onDone...');
            Future.delayed(const Duration(seconds: 2), () {
              if (_activeUid == uid && _listingsSub == null) {
                print('   Restarting now...');
                start();
              } else {
                print('   Skipping restart - UID changed or subscription already active');
              }
            });
          } else {
            print('   Skipping restart - UID mismatch (user logged out or changed)');
          }
        },
        cancelOnError: false, // Keep listening even if there's an error
      );
      
      print('✅ ListingSyncService: Real-time listener created');
      print('   Subscription object: ${_listingsSub != null ? "created" : "NULL"}');
      
      // Verify subscription is actually active after a short delay
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (_listingsSub != null) {
          print('✅ ListingSyncService: Subscription verified active after 1 second');
          try {
            print('   Status: ${_listingsSub!.isPaused ? "PAUSED" : "ACTIVE"}');
          } catch (e) {
            print('   Could not check pause status: $e');
          }
        } else {
          print('❌ ListingSyncService: Subscription was cancelled immediately!');
          print('   This indicates an error occurred during subscription creation');
          print('   Attempting to restart...');
          // Try to restart
          Future.delayed(const Duration(seconds: 2), () {
            if (_activeUid == uid) {
              print('🔄 ListingSyncService: Restarting after failed subscription...');
              start();
            }
          });
        }
      });
      
      // Also verify after 5 seconds to catch delayed failures
      Future.delayed(const Duration(seconds: 5), () {
        if (_listingsSub == null && _activeUid == uid) {
          print('⚠️ ListingSyncService: Subscription lost after 5 seconds!');
          print('   This indicates the subscription was closed unexpectedly');
          print('   Restarting sync service...');
          start();
        } else if (_listingsSub != null) {
          print('✅ ListingSyncService: Subscription still active after 5 seconds');
          try {
            print('   Subscription status: ${_listingsSub!.isPaused ? "PAUSED" : "ACTIVE"}');
          } catch (e) {
            print('   Could not check subscription status: $e');
          }
        } else {
          print('⚠️ ListingSyncService: Subscription check skipped - UID mismatch');
          print('   Active UID: $_activeUid, Expected: $uid');
        }
      });
      
      // Additional check after 10 seconds to ensure it's still running
      Future.delayed(const Duration(seconds: 10), () {
        if (_listingsSub == null && _activeUid == uid) {
          print('⚠️ ListingSyncService: Subscription lost after 10 seconds!');
          print('   Attempting final restart...');
          start();
        } else if (_listingsSub != null) {
          print('✅ ListingSyncService: Subscription confirmed active after 10 seconds');
        }
      });
      
      // ✅ Load existing listings in parallel (non-blocking)
      // If this times out, the real-time listener will still sync everything
      _loadExistingListings().catchError((e) {
        print('⚠️ ListingSyncService: Initial load failed or timed out: $e');
        print('   This is OK - real-time listener will sync all listings anyway');
      });
    } catch (e, stackTrace) {
      print('❌ ListingSyncService: Failed to create subscription: $e');
      print('   Stack trace: $stackTrace');
      _listingsSub = null;
      // Try to restart after error
      Future.delayed(const Duration(seconds: 3), () {
        if (_activeUid == uid) {
          print('🔄 ListingSyncService: Attempting to restart after exception...');
          start();
        }
      });
    }
  }

  /// Load existing listings from Firestore on startup
  static Future<void> _loadExistingListings() async {
    try {
      print('🔄 Loading existing listings from Firestore...');
      // Use FirestoreHelper which automatically falls back to default if named DB doesn't exist
      final db = FirestoreHelper.db;
      final listings = db.collection('listings');
      print('   Using database: ${FirestoreHelper.activeDatabaseId ?? "unknown"}');
      
      // Increase timeout to 30 seconds for slow connections
      // But don't block the subscription if this times out
      final snapshot = await listings
          .get()
          .timeout(const Duration(seconds: 30), onTimeout: () {
        print('⏱️ ListingSyncService: Initial load timeout after 30 seconds');
        print('   Real-time listener will sync listings instead');
        throw TimeoutException('Initial load timeout', const Duration(seconds: 30));
      });
      
      final box = Hive.box<Listing>('listingBox');
      int loadedCount = 0;
      int skippedCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final listingId = data['key']?.toString() ?? doc.id;
          final key = int.tryParse(listingId);
          
          if (key == null) {
            print('⚠️ Invalid listing key: $listingId');
            skippedCount++;
            continue;
          }
          
          // Always sync from Firestore (even if exists locally) to get latest updates
          // This ensures all browsers have the same data
          final listing = ListingFirestoreService.fromMap(data, key);
          if (listing != null) {
            final existingListing = box.get(key);
            await box.put(key, listing);
            if (existingListing == null) {
              loadedCount++;
              print('   ✅ Loaded new listing: ${listing.name} (key: $key)');
            } else {
              loadedCount++; // Count as loaded even if it existed
              print('   🔄 Updated existing listing: ${listing.name} (key: $key)');
            }
          } else {
            skippedCount++;
            print('   ⚠️ Failed to parse listing: $listingId');
          }
        } catch (e) {
          print('⚠️ Error processing listing ${doc.id}: $e');
          skippedCount++;
        }
      }

      print('✅ Loaded $loadedCount listings from Firestore ($skippedCount skipped)');
      print('📊 Total documents in Firestore: ${snapshot.docs.length}');
      print('📊 Total listings now in Hive: ${box.length}');
      
      // Print summary of what was loaded
      if (loadedCount > 0) {
        print('   ✅ Successfully synced $loadedCount listings from Firestore');
      }
      if (skippedCount > 0) {
        print('   ⚠️ Skipped $skippedCount listings (parsing errors or invalid keys)');
      }
    } on TimeoutException {
      print('⏱️ Firestore listing load timeout - using local data only');
      _printCriticalInstructions();
    } catch (e) {
      print('❌ Error loading listings from Firestore: $e');
      if (e.toString().contains('unavailable') || 
          e.toString().contains('offline') || 
          e.toString().contains('permission')) {
        print('🔴 CRITICAL: Rules are blocking access - they must be PUBLISHED!');
      }
      _printCriticalInstructions();
    }
  }

  static void _printCriticalInstructions() {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🔴 RULES NOT PUBLISHED - DO THIS NOW:');
    print('═══════════════════════════════════════════════════════');
    print('1. Go to: https://console.firebase.google.com/project/resqfood-66b5f/firestore/rules');
    print('2. Look for "Publish" button (top right, blue button)');
    print('3. Click "Publish" (NOT "Save"!)');
    print('4. Wait for "Rules published successfully"');
    print('5. Verify: Top of page shows "Last published: [time]"');
    print('6. Restart your app');
    print('═══════════════════════════════════════════════════════');
    print('');
  }

  /// Stop real-time sync
  static Future<void> stop() async {
    if (_listingsSub != null) {
      print('🛑 ListingSyncService: Stopping subscription...');
      await _listingsSub?.cancel();
      _listingsSub = null;
      print('🛑 ListingSyncService: Stopped');
    }
    _activeUid = null;
  }

  /// Check if sync is active
  static bool get isActive => _listingsSub != null;

  /// Get status information for debugging
  static Map<String, dynamic> getStatus() {
    final box = Hive.box<Listing>('listingBox');
    return {
      'isActive': isActive,
      'activeUid': _activeUid,
      'hasSubscription': _listingsSub != null,
      'totalListingsInHive': box.length,
      'listingKeys': box.keys.take(10).toList(), // First 10 keys for debugging
    };
  }
  
  /// Print diagnostic information to console
  static void printDiagnostics() {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('📊 ListingSyncService Diagnostics');
    print('═══════════════════════════════════════════════════════');
    final status = getStatus();
    print('   Active: ${status['isActive']}');
    print('   Active UID: ${status['activeUid']}');
    print('   Has Subscription: ${status['hasSubscription']}');
    print('   Total Listings in Hive: ${status['totalListingsInHive']}');
    print('   Sample Keys: ${status['listingKeys']}');
    
    final box = Hive.box<Listing>('listingBox');
    if (box.isNotEmpty) {
      print('   All Listings in Hive:');
      final allListings = box.values.toList();
      for (var listing in allListings) {
        print('     - ${listing.name} (key: ${listing.key}, seller: ${listing.sellerId}, qty: ${listing.quantity}, type: ${listing.type.name})');
      }
    } else {
      print('   ⚠️ WARNING: Hive box is EMPTY! No listings found.');
      print('   This means sync from Firestore may have failed.');
    }
    print('═══════════════════════════════════════════════════════');
    print('');
  }

  /// Force a manual sync check (useful for debugging)
  static Future<void> forceSync() async {
    print('🔄 ListingSyncService: Force sync requested');
    await _loadExistingListings();
    print('✅ ListingSyncService: Force sync complete');
  }

  /// Test if Firestore rules are working for listings collection
  /// This will print detailed diagnostics about what's blocking access
  static Future<void> testRules() async {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🧪 TESTING FIRESTORE RULES FOR LISTINGS');
    print('═══════════════════════════════════════════════════════');
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      print('❌ NOT AUTHENTICATED');
      print('   User must be logged in to test rules');
      print('═══════════════════════════════════════════════════════');
      print('');
      return;
    }
    print('✅ User authenticated: $uid');
    
    final db = FirestoreHelper.db;
    final listings = db.collection('listings');
    print('   Using database: ${FirestoreHelper.activeDatabaseId ?? "unknown"}');
    
    // Test 1: Try to read a single document
    print('');
    print('Test 1: Reading a single listing document...');
    try {
      final testDoc = await listings.limit(1).get().timeout(const Duration(seconds: 10));
      if (testDoc.docs.isNotEmpty) {
        print('✅ SUCCESS: Can read listings!');
        print('   Found ${testDoc.docs.length} document(s)');
        print('   Rules are WORKING ✅');
      } else {
        print('⚠️ Can read, but no listings found in database');
        print('   Rules are WORKING, but database is empty');
      }
    } catch (e) {
      print('❌ FAILED: Cannot read listings');
      print('   Error: $e');
      print('   Error type: ${e.runtimeType}');
      
      if (e.toString().contains('permission-denied') || 
          e.toString().contains('Missing or insufficient permissions')) {
        print('');
        print('🔴 CRITICAL: PERMISSION DENIED');
        print('   This means rules are BLOCKING access');
        print('   Possible causes:');
        print('   1. Rules are NOT PUBLISHED (most likely)');
        print('   2. Rules syntax is incorrect');
        print('   3. User is not authenticated (but we checked - user IS authenticated)');
        print('');
        print('   ACTION REQUIRED:');
        print('   1. Go to: https://console.firebase.google.com/project/resqfood-66b5f/firestore/rules');
        print('   2. Check if you see "Last published: [time]" at the TOP');
        print('   3. If you see "Last saved" instead → Rules are NOT published!');
        print('   4. Click "Publish" button (blue button, top right)');
        print('   5. Wait for "Rules published successfully"');
        print('   6. Wait 10-20 seconds for propagation');
        print('   7. Restart app and test again');
      } else if (e.toString().contains('unavailable') || 
                 e.toString().contains('offline')) {
        print('');
        print('🔴 CRITICAL: DATABASE UNAVAILABLE');
        print('   This usually means rules are NOT PUBLISHED');
        print('   Firestore reports "offline" when rules block access');
        print('');
        print('   ACTION: Publish rules in Firebase Console');
      } else if (e.toString().contains('timeout')) {
        print('');
        print('⏱️ TIMEOUT: Request took too long');
        print('   This could mean:');
        print('   1. Rules are blocking (most likely)');
        print('   2. Network issue');
        print('   3. Database is down');
        print('');
        print('   ACTION: Check if rules are published');
      }
    }
    
    // Test 2: Try to listen to snapshots (real-time)
    print('');
    print('Test 2: Testing real-time listener (snapshots)...');
    try {
      bool receivedData = false;
      final testSub = listings.limit(1).snapshots().listen(
        (snapshot) {
          receivedData = true;
          print('✅ SUCCESS: Real-time listener is working!');
          print('   Received snapshot with ${snapshot.docs.length} document(s)');
        },
        onError: (error) {
          print('❌ FAILED: Real-time listener error');
          print('   Error: $error');
          if (error.toString().contains('permission') || 
              error.toString().contains('Missing')) {
            print('   🔴 PERMISSION DENIED - Rules are blocking!');
          }
        },
      );
      
      // Wait a bit to see if we get data
      await Future.delayed(const Duration(seconds: 2));
      await testSub.cancel();
      
      if (!receivedData) {
        print('⚠️ Listener created but no data received');
        print('   This might be normal if database is empty');
        print('   But if you have listings, this indicates a problem');
      }
    } catch (e) {
      print('❌ FAILED: Cannot create real-time listener');
      print('   Error: $e');
      if (e.toString().contains('permission') || 
          e.toString().contains('Missing')) {
        print('   🔴 PERMISSION DENIED - Rules are blocking!');
      }
    }
    
    // Test 3: Check total count
    print('');
    print('Test 3: Counting total listings...');
    try {
      final countSnapshot = await listings.count().get().timeout(const Duration(seconds: 10));
      print('✅ SUCCESS: Can count listings');
      print('   Total listings in database: ${countSnapshot.count}');
    } catch (e) {
      print('❌ FAILED: Cannot count listings');
      print('   Error: $e');
      if (e.toString().contains('permission') || 
          e.toString().contains('Missing')) {
        print('   🔴 PERMISSION DENIED - Rules are blocking!');
      }
    }
    
    print('');
    print('═══════════════════════════════════════════════════════');
    print('📋 SUMMARY');
    print('═══════════════════════════════════════════════════════');
    print('If you see "PERMISSION DENIED" errors above:');
    print('→ Rules are NOT PUBLISHED or have syntax errors');
    print('→ Go to Firebase Console and click "Publish"');
    print('═══════════════════════════════════════════════════════');
    print('');
  }

  /// Apply snapshot changes to Hive
  static void _applySnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    final box = Hive.box<Listing>('listingBox');
    
    print('📥 ListingSyncService: Received snapshot with ${snap.docChanges.length} changes');
    
    for (final change in snap.docChanges) {
      final data = change.doc.data();
      if (data == null) {
        print('⚠️ ListingSyncService: Document ${change.doc.id} has null data');
        continue;
      }
      
      final listingId = data['key']?.toString() ?? change.doc.id;
      final key = int.tryParse(listingId);
      
      if (key == null) {
        print('⚠️ Invalid listing key in snapshot: $listingId (doc.id: ${change.doc.id})');
        print('   Data keys: ${data.keys.join(", ")}');
        continue;
      }

      if (change.type == DocumentChangeType.removed) {
        // Listing was deleted
        final existingListing = box.get(key);
        if (existingListing != null) {
          box.delete(key);
          print('🗑️ Listing removed from sync: ${existingListing.name} (key: $key)');
        }
        continue;
      }

      // Listing was added or modified
      try {
        final listing = ListingFirestoreService.fromMap(data, key);
        if (listing != null) {
          final existingListing = box.get(key);
          
          // Always update from Firestore (Firestore is source of truth)
          box.put(key, listing);
          
          if (change.type == DocumentChangeType.added) {
            if (existingListing != null) {
              print('✨ Listing added from sync (replaced local): ${listing.name} (key: $key, seller: ${listing.sellerId})');
            } else {
              print('✨ New listing synced: ${listing.name} (key: $key, seller: ${listing.sellerId})');
            }
          } else if (change.type == DocumentChangeType.modified) {
            print('🔄 Listing updated from sync: ${listing.name} (key: $key, seller: ${listing.sellerId})');
          }
        } else {
          print('⚠️ Failed to convert Firestore data to Listing: $listingId');
          print('   Document ID: ${change.doc.id}');
          print('   Data keys: ${data.keys.join(", ")}');
          if (data.containsKey('key')) {
            print('   Key value: ${data['key']} (type: ${data['key'].runtimeType})');
          } else {
            print('   ⚠️ WARNING: Document missing "key" field!');
          }
        }
      } catch (e, stackTrace) {
        print('❌ Error processing listing change: $e');
        print('   Document ID: ${change.doc.id}');
        print('   Stack trace: $stackTrace');
      }
    }
    
    print('✅ ListingSyncService: Processed ${snap.docChanges.length} changes. Total listings in Hive: ${box.length}');
  }
}

