import '../models/listing.dart';
import '../models/seller_profile.dart';
import '../services/seller_profile_service.dart';
import '../services/location_service.dart';
import '../utils/distance_utils.dart';
import '../utils/location_parser.dart';
import 'package:flutter/foundation.dart';

/// Service for filtering listings by distance with dynamic radius expansion
class DistanceFilterService {
  // Default radius progression: 100m, 1km, 2km, 5km, 10km, 20km
  // Starting with 100m instead of 10m to be more practical
  static const List<double> _radiusProgression = [
    100,     // 100 meters (more practical starting point)
    1000,    // 1 km
    2000,    // 2 km
    5000,    // 5 km
    10000,   // 10 km
    20000,   // 20 km
  ];
  
  // Maximum distance beyond which products are completely excluded (50 km)
  // Products beyond this distance are useless and should not appear anywhere
  static const double _maxAllowedDistance = 50000; // 50 km

  /// Filter listings by distance and sort by nearest first
  /// Returns filtered and sorted listings with distance information
  /// [includeWithoutLocation] - If true, includes listings without seller location at the end (default: false)
  static Future<List<ListingWithDistance>> filterByDistance(
    List<Listing> listings, {
    double? customRadius,
    bool expandRadiusIfEmpty = true,
    bool includeWithoutLocation = false,
  }) async {
    // Get buyer's current location
    final buyerPosition = await LocationService.getCurrentLocation();
    if (buyerPosition == null) {
      debugPrint('[DistanceFilterService] No buyer location available, returning all listings without distance');
      // Return all listings without distance if location unavailable
      return listings.map((listing) => ListingWithDistance(
        listing: listing,
        distanceInMeters: null,
      )).toList();
    }

    final buyerLat = buyerPosition.latitude;
    final buyerLon = buyerPosition.longitude;
    debugPrint('[DistanceFilterService] Buyer location: ($buyerLat, $buyerLon), filtering ${listings.length} listings');

    // Get seller profiles for all listings
    final sellerIds = listings.map((l) => l.sellerId).toSet().toList();
    final sellerProfiles = <String, SellerProfile?>{};
    
    for (final sellerId in sellerIds) {
      try {
        final profile = await SellerProfileService.getProfile(sellerId);
        sellerProfiles[sellerId] = profile;
      } catch (e) {
        debugPrint('[DistanceFilterService] Failed to get profile for seller $sellerId: $e');
        sellerProfiles[sellerId] = null;
      }
    }

    // Calculate distances for all listings
    final listingsWithDistance = <ListingWithDistance>[];
    final listingsWithoutLocation = <ListingWithDistance>[];
    
    for (final listing in listings) {
      final sellerProfile = sellerProfiles[listing.sellerId];
      if (sellerProfile == null || sellerProfile.pickupLocation.isEmpty) {
        // No location available, add without distance (will be shown after filtered ones)
        debugPrint('[DistanceFilterService] Listing "${listing.name}" from seller "${listing.sellerId}": No seller profile or pickup location');
        listingsWithoutLocation.add(ListingWithDistance(
          listing: listing,
          distanceInMeters: null,
        ));
        continue;
      }

      // Parse seller location
      final sellerCoords = await LocationParser.parseLocation(sellerProfile.pickupLocation);
      if (sellerCoords == null) {
        // Could not parse location, add without distance
        debugPrint('[DistanceFilterService] Listing "${listing.name}" from seller "${listing.sellerId}": Could not parse location "${sellerProfile.pickupLocation}"');
        listingsWithoutLocation.add(ListingWithDistance(
          listing: listing,
          distanceInMeters: null,
        ));
        continue;
      }

      // Calculate distance
      final distance = DistanceUtils.calculateDistance(
        buyerLat,
        buyerLon,
        sellerCoords['latitude']!,
        sellerCoords['longitude']!,
      );

      debugPrint('[DistanceFilterService] Listing "${listing.name}" from seller "${listing.sellerId}": '
          'Buyer: ($buyerLat, $buyerLon), Seller: (${sellerCoords['latitude']}, ${sellerCoords['longitude']}), '
          'Distance: ${DistanceUtils.formatDistance(distance)}');

      listingsWithDistance.add(ListingWithDistance(
        listing: listing,
        distanceInMeters: distance,
        sellerLatitude: sellerCoords['latitude'],
        sellerLongitude: sellerCoords['longitude'],
      ));
    }

    // Determine radius to use
    double radiusToUse;
    if (customRadius != null) {
      radiusToUse = customRadius;
      debugPrint('[DistanceFilterService] Using custom radius: ${DistanceUtils.formatDistance(radiusToUse)}');
    } else {
      // Use dynamic radius expansion
      radiusToUse = _findOptimalRadius(listingsWithDistance, expandRadiusIfEmpty);
      debugPrint('[DistanceFilterService] Using optimal radius: ${DistanceUtils.formatDistance(radiusToUse)}');
    }

    debugPrint('[DistanceFilterService] Total listings with distance: ${listingsWithDistance.length}, listings without location: ${listingsWithoutLocation.length}');

    // Filter by radius (only listings with valid distances)
    // Also exclude products beyond maximum allowed distance (completely useless)
    final filtered = listingsWithDistance.where((item) {
      if (item.distanceInMeters == null) return false;
      
      // First check: exclude products beyond maximum allowed distance
      if (item.distanceInMeters! > _maxAllowedDistance) {
        debugPrint('[DistanceFilterService] Listing "${item.listing.name}" at ${DistanceUtils.formatDistance(item.distanceInMeters!)} is beyond maximum allowed distance ${DistanceUtils.formatDistance(_maxAllowedDistance)} - excluding completely');
        return false;
      }
      
      // Second check: filter by current radius
      final isWithinRadius = item.distanceInMeters! <= radiusToUse;
      if (!isWithinRadius) {
        debugPrint('[DistanceFilterService] Listing "${item.listing.name}" at ${DistanceUtils.formatDistance(item.distanceInMeters!)} is outside radius ${DistanceUtils.formatDistance(radiusToUse)}');
      }
      return isWithinRadius;
    }).toList();

    // Sort by distance (nearest first)
    filtered.sort((a, b) {
      if (a.distanceInMeters == null && b.distanceInMeters == null) return 0;
      if (a.distanceInMeters == null) return 1;
      if (b.distanceInMeters == null) return -1;
      return a.distanceInMeters!.compareTo(b.distanceInMeters!);
    });

    // Only append listings without location if explicitly requested
    if (includeWithoutLocation) {
      filtered.addAll(listingsWithoutLocation);
    }

    final listingsWithValidDistance = filtered.where((item) => item.distanceInMeters != null).length;
    debugPrint('[DistanceFilterService] Filtered ${filtered.length} listings (${listingsWithValidDistance} with distance within ${DistanceUtils.formatDistance(radiusToUse)}, ${includeWithoutLocation ? listingsWithoutLocation.length : 0} without location)');
    
    return filtered;
  }

  /// Find optimal radius that returns at least some results
  /// Returns the smallest radius that includes at least one listing
  static double _findOptimalRadius(
    List<ListingWithDistance> listingsWithDistance,
    bool expandIfEmpty,
  ) {
    if (!expandIfEmpty) {
      return _radiusProgression.first; // Start with 100m
    }

    if (listingsWithDistance.isEmpty) {
      // No listings with distance info, return smallest radius
      return _radiusProgression.first;
    }

    // Try each radius in progression until we find listings
    for (final radius in _radiusProgression) {
      final count = listingsWithDistance.where((item) {
        return item.distanceInMeters != null && item.distanceInMeters! <= radius;
      }).length;

      if (count > 0) {
        debugPrint('[DistanceFilterService] Found $count listings within ${DistanceUtils.formatDistance(radius)}, using this radius');
        return radius;
      }
    }

    // If no listings found within any radius progression, return the largest radius
    // This means all listings are beyond 20km
    debugPrint('[DistanceFilterService] No listings found within any radius progression, using maximum radius ${DistanceUtils.formatDistance(_radiusProgression.last)}');
    return _radiusProgression.last;
  }

  /// Get current active radius (for display purposes)
  static double getActiveRadius(List<ListingWithDistance> filteredListings) {
    if (filteredListings.isEmpty) return _radiusProgression.first;
    
    final maxDistance = filteredListings
        .where((item) => item.distanceInMeters != null)
        .map((item) => item.distanceInMeters!)
        .fold<double>(0, (max, dist) => dist > max ? dist : max);
    
    // Find the smallest radius that contains all listings
    for (final radius in _radiusProgression) {
      if (maxDistance <= radius) {
        return radius;
      }
    }
    
    return _radiusProgression.last;
  }
}

/// Wrapper class to hold listing with distance information
class ListingWithDistance {
  final Listing listing;
  final double? distanceInMeters;
  final double? sellerLatitude;
  final double? sellerLongitude;

  ListingWithDistance({
    required this.listing,
    this.distanceInMeters,
    this.sellerLatitude,
    this.sellerLongitude,
  });

  String get formattedDistance {
    if (distanceInMeters == null) return 'Distance unknown';
    return DistanceUtils.formatDistance(distanceInMeters!);
  }
}

