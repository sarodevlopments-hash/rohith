import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/scheduled_listing.dart';
import '../models/listing.dart';
import '../models/schedule_type.dart';

class ScheduledListingService {
  static Box<ScheduledListing> get _box => Hive.box<ScheduledListing>('scheduledListingsBox');
  static Box<Listing> get _listingBox => Hive.box<Listing>('listingBox');
  
  static Timer? _checkTimer;

  // Initialize the service and start checking for scheduled posts
  static void start() {
    // Check every minute for scheduled posts
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkAndPostScheduled();
    });
    
    // Also check immediately
    _checkAndPostScheduled();
  }

  static void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  // Check all scheduled listings and post if it's time
  static Future<void> _checkAndPostScheduled() async {
    final now = DateTime.now();
    final scheduledListings = _box.values.where((scheduled) => scheduled.isActive).toList();

    for (final scheduled in scheduledListings) {
      if (scheduled.shouldPostNow(now)) {
        await _postScheduledListing(scheduled);
      }
    }
  }

  // Post a scheduled listing (create actual listing)
  static Future<void> _postScheduledListing(ScheduledListing scheduled) async {
    try {
      // Calculate expiry date based on close time if set
      DateTime? expiryDate = scheduled.listingData.expiryDate;
      if (scheduled.scheduleCloseTime != null) {
        final now = DateTime.now();
        final closeDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          scheduled.scheduleCloseTime!.hour,
          scheduled.scheduleCloseTime!.minute,
        );
        // If close time is earlier today, set it for tomorrow
        if (closeDateTime.isBefore(now)) {
          expiryDate = closeDateTime.add(const Duration(days: 1));
        } else {
          expiryDate = closeDateTime;
        }
      }
      
      // Create a new listing from the scheduled data
      final listing = Listing(
        name: scheduled.listingData.name,
        sellerName: scheduled.listingData.sellerName,
        price: scheduled.listingData.price,
        originalPrice: scheduled.listingData.originalPrice,
        quantity: scheduled.listingData.initialQuantity, // Reset to initial quantity
        initialQuantity: scheduled.listingData.initialQuantity,
        sellerId: scheduled.sellerId,
        type: scheduled.listingData.type,
        fssaiLicense: scheduled.listingData.fssaiLicense,
        preparedAt: scheduled.listingData.preparedAt,
        expiryDate: expiryDate,
        category: scheduled.listingData.category,
        cookedFoodSource: scheduled.listingData.cookedFoodSource,
        imagePath: scheduled.listingData.imagePath,
        measurementUnit: scheduled.listingData.measurementUnit,
        packSizes: scheduled.listingData.packSizes,
      );

      // Add to listings box
      await _listingBox.add(listing);

      // Update lastPostedAt
      scheduled.lastPostedAt = DateTime.now();
      await scheduled.save();

      // If it's a one-time schedule and we've posted it, deactivate it
      if (scheduled.scheduleType == ScheduleType.once) {
        scheduled.isActive = false;
        await scheduled.save();
      }
    } catch (e) {
      debugPrint('Error posting scheduled listing: $e');
    }
  }

  // Get all scheduled listings for a seller
  static List<ScheduledListing> getScheduledListings(String sellerId) {
    return _box.values
        .where((scheduled) => scheduled.sellerId == sellerId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  // Get active scheduled listings
  static List<ScheduledListing> getActiveScheduledListings(String sellerId) {
    return _box.values
        .where((scheduled) => scheduled.sellerId == sellerId && scheduled.isActive)
        .toList();
  }

  // Add a scheduled listing
  static Future<void> addScheduledListing(ScheduledListing scheduled) async {
    await _box.add(scheduled);
  }

  // Update a scheduled listing
  static Future<void> updateScheduledListing(ScheduledListing scheduled) async {
    await scheduled.save();
  }

  // Delete a scheduled listing
  static Future<void> deleteScheduledListing(String scheduledId) async {
    final scheduled = _box.values.firstWhere(
      (s) => s.scheduledId == scheduledId,
      orElse: () => throw Exception('Scheduled listing not found'),
    );
    await scheduled.delete();
  }

  // Pause a scheduled listing
  static Future<void> pauseScheduledListing(String scheduledId) async {
    final scheduled = _box.values.firstWhere(
      (s) => s.scheduledId == scheduledId,
      orElse: () => throw Exception('Scheduled listing not found'),
    );
    scheduled.isActive = false;
    await scheduled.save();
  }

  // Resume a scheduled listing
  static Future<void> resumeScheduledListing(String scheduledId) async {
    final scheduled = _box.values.firstWhere(
      (s) => s.scheduledId == scheduledId,
      orElse: () => throw Exception('Scheduled listing not found'),
    );
    scheduled.isActive = true;
    await scheduled.save();
  }
}

