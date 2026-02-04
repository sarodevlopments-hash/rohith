import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/place_result.dart';
import 'places_service.dart';

/// Mapbox Places API implementation
/// Uses Mapbox Geocoding API for place search
class MapboxPlacesService implements PlacesService {
  // TODO: Replace with your Mapbox access token
  static const String _accessToken = 'YOUR_MAPBOX_ACCESS_TOKEN';
  static const String _baseUrl = 'https://api.mapbox.com/geocoding/v5/mapbox.places';

  @override
  Future<List<PlaceResult>> searchPlaces({
    required String query,
    double? latitude,
    double? longitude,
    int? radius,
  }) async {
    if (query.isEmpty) return [];

    try {
      // Build proximity parameter if location provided
      final proximity = (latitude != null && longitude != null)
          ? '&proximity=$longitude,$latitude'
          : '';

      final url = Uri.parse(
        '$_baseUrl/$query.json?access_token=$_accessToken'
        '$proximity'
        '&types=poi,address'
        '&limit=10',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) {
        debugPrint('[MapboxPlacesService] Error: ${response.statusCode}');
        return [];
      }

      final data = json.decode(response.body);
      final features = data['features'] as List? ?? [];

      return features.map((feature) {
        final geometry = feature['geometry'];
        final coordinates = geometry['coordinates'] as List;
        final properties = feature['properties'] ?? {};
        final context = feature['context'] as List?;

        // Build address from context
        final addressParts = <String>[];
        if (properties['name'] != null) {
          addressParts.add(properties['name'] as String);
        }
        if (context != null) {
          for (final item in context) {
            final text = item['text'] as String?;
            if (text != null && text.isNotEmpty) {
              addressParts.add(text);
            }
          }
        }

        return PlaceResult(
          placeId: feature['id'] as String? ?? '',
          name: properties['name'] as String? ?? properties['address'] as String? ?? '',
          address: addressParts.isNotEmpty
              ? addressParts.join(', ')
              : feature['place_name'] as String? ?? '',
          latitude: (coordinates[1] as num).toDouble(),
          longitude: (coordinates[0] as num).toDouble(),
          placeType: properties['category'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('[MapboxPlacesService] Exception: $e');
      return [];
    }
  }

  @override
  Future<PlaceResult?> getPlaceDetails(String placeId) async {
    // Mapbox uses the same endpoint, just fetch by ID
    try {
      final url = Uri.parse(
        '$_baseUrl/$placeId.json?access_token=$_accessToken',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      final feature = data['features']?.first;
      if (feature == null) return null;

      final geometry = feature['geometry'];
      final coordinates = geometry['coordinates'] as List;
      final properties = feature['properties'] ?? {};

      return PlaceResult(
        placeId: placeId,
        name: properties['name'] as String? ?? '',
        address: feature['place_name'] as String? ?? '',
        latitude: (coordinates[1] as num).toDouble(),
        longitude: (coordinates[0] as num).toDouble(),
        placeType: properties['category'] as String?,
      );
    } catch (e) {
      debugPrint('[MapboxPlacesService] getPlaceDetails error: $e');
      return null;
    }
  }

  @override
  Future<List<PlaceResult>> searchNearbyPlaces({
    required double latitude,
    required double longitude,
    required int radius,
    List<String>? types,
  }) async {
    // Mapbox doesn't have a direct nearby search, use reverse geocoding with POI filter
    try {
      final typeFilter = types != null && types.isNotEmpty
          ? '&types=${types.join(",")}'
          : '&types=poi';

      final url = Uri.parse(
        '$_baseUrl/$longitude,$latitude.json?access_token=$_accessToken'
        '$typeFilter'
        '&limit=20',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final features = data['features'] as List? ?? [];

      return features.where((feature) {
        // Filter by radius
        final geometry = feature['geometry'];
        final coordinates = geometry['coordinates'] as List;
        final placeLat = (coordinates[1] as num).toDouble();
        final placeLng = (coordinates[0] as num).toDouble();
        
        // Simple distance check (Haversine would be more accurate)
        final distance = _calculateDistance(latitude, longitude, placeLat, placeLng);
        return distance <= radius;
      }).map((feature) {
        final geometry = feature['geometry'];
        final coordinates = geometry['coordinates'] as List;
        final properties = feature['properties'] ?? {};

        return PlaceResult(
          placeId: feature['id'] as String? ?? '',
          name: properties['name'] as String? ?? '',
          address: feature['place_name'] as String? ?? '',
          latitude: (coordinates[1] as num).toDouble(),
          longitude: (coordinates[0] as num).toDouble(),
          placeType: properties['category'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('[MapboxPlacesService] searchNearbyPlaces error: $e');
      return [];
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Simple distance calculation (meters) using Haversine formula
    const double earthRadius = 6371000; // meters
    final double dLat = (lat2 - lat1) * (3.14159265359 / 180);
    final double dLon = (lon2 - lon1) * (3.14159265359 / 180);
    final double a = (dLat / 2) * (dLat / 2) +
        (lat1 * (3.14159265359 / 180)) *
            (lat2 * (3.14159265359 / 180)) *
            (dLon / 2) *
            (dLon / 2);
    final double c = 2 * (a < 0 ? -1 : 1) * (a.abs() < 1 ? a.abs() : 1);
    return (earthRadius * c).toDouble();
  }
}

