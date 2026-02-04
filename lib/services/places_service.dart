import 'package:flutter/foundation.dart';
import '../models/place_result.dart';

/// Abstract service for place search functionality
/// Supports both Google Places and Mapbox/Apple Maps
abstract class PlacesService {
  /// Search for places with autocomplete
  /// [query] - Search query text
  /// [latitude] - Current map center latitude (for context)
  /// [longitude] - Current map center longitude (for context)
  /// [radius] - Search radius in meters (optional)
  Future<List<PlaceResult>> searchPlaces({
    required String query,
    double? latitude,
    double? longitude,
    int? radius,
  });

  /// Get place details by place ID
  Future<PlaceResult?> getPlaceDetails(String placeId);

  /// Search nearby places (POIs) based on location
  /// [latitude] - Center latitude
  /// [longitude] - Center longitude
  /// [radius] - Search radius in meters
  /// [types] - Place types to search (e.g., ["restaurant", "store"])
  Future<List<PlaceResult>> searchNearbyPlaces({
    required double latitude,
    required double longitude,
    required int radius,
    List<String>? types,
  });
}

