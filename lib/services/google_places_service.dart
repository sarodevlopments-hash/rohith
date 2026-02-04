import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/place_result.dart';
import 'places_service.dart';

/// Google Places API implementation
/// Uses HTTP API (no SDK required)
class GooglePlacesService implements PlacesService {
  // Google Places API key
  static const String _apiKey = 'AQ.Ab8RN6LByAgM3CQdMMDuoo8c67YY-XQGA5SbvK9s8_FbPudg1g';
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';

  @override
  Future<List<PlaceResult>> searchPlaces({
    required String query,
    double? latitude,
    double? longitude,
    int? radius,
  }) async {
    if (query.isEmpty) return [];

    try {
      // Build autocomplete request
      final locationBias = (latitude != null && longitude != null)
          ? '&location=$latitude,$longitude&radius=${radius ?? 5000}'
          : '';

      final url = Uri.parse(
        '$_baseUrl/autocomplete/json?input=${Uri.encodeComponent(query)}'
        '&key=$_apiKey'
        '$locationBias'
        '&types=establishment|point_of_interest',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) {
        debugPrint('[GooglePlacesService] Error: ${response.statusCode}');
        return [];
      }

      final data = json.decode(response.body);
      if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
        debugPrint('[GooglePlacesService] API Error: ${data['status']}');
        return [];
      }

      final predictions = data['predictions'] as List? ?? [];
      final results = <PlaceResult>[];

      for (final prediction in predictions) {
        final placeId = prediction['place_id'] as String;
        final description = prediction['description'] as String;
        final structuredFormatting = prediction['structured_formatting'] ?? {};
        final mainText = structuredFormatting['main_text'] as String? ?? description;

        // Get place details for coordinates
        final details = await getPlaceDetails(placeId);
        if (details != null) {
          results.add(PlaceResult(
            placeId: placeId,
            name: mainText,
            address: description,
            latitude: details.latitude,
            longitude: details.longitude,
            placeType: _extractPlaceType(prediction['types'] as List?),
          ));
        }
      }

      return results;
    } catch (e) {
      debugPrint('[GooglePlacesService] Exception: $e');
      return [];
    }
  }

  @override
  Future<PlaceResult?> getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/details/json?place_id=$placeId'
        '&fields=geometry,name,formatted_address,types,rating,photos'
        '&key=$_apiKey',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      if (data['status'] != 'OK') return null;

      final result = data['result'];
      final location = result['geometry']?['location'];
      if (location == null) return null;

      final photos = result['photos'] as List?;
      final photoRef = photos?.isNotEmpty == true
          ? photos![0]['photo_reference'] as String?
          : null;

      return PlaceResult(
        placeId: placeId,
        name: result['name'] as String? ?? '',
        address: result['formatted_address'] as String? ?? '',
        latitude: (location['lat'] as num).toDouble(),
        longitude: (location['lng'] as num).toDouble(),
        placeType: _extractPlaceType(result['types'] as List?),
        rating: result['rating'] != null
            ? (result['rating'] as num).toDouble()
            : null,
        photoReference: photoRef,
      );
    } catch (e) {
      debugPrint('[GooglePlacesService] getPlaceDetails error: $e');
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
    try {
      final typeParam = types != null && types.isNotEmpty
          ? '&type=${types.first}' // Google Places API accepts one type at a time
          : '';

      final url = Uri.parse(
        '$_baseUrl/nearbysearch/json?location=$latitude,$longitude'
        '&radius=$radius'
        '$typeParam'
        '&key=$_apiKey',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
        return [];
      }

      final results = data['results'] as List? ?? [];
      return results.map((item) {
        final location = item['geometry']?['location'];
        final photos = item['photos'] as List?;
        final photoRef = photos?.isNotEmpty == true
            ? photos![0]['photo_reference'] as String?
            : null;

        return PlaceResult(
          placeId: item['place_id'] as String? ?? '',
          name: item['name'] as String? ?? '',
          address: item['vicinity'] as String? ?? item['formatted_address'] as String? ?? '',
          latitude: (location?['lat'] as num?)?.toDouble() ?? 0.0,
          longitude: (location?['lng'] as num?)?.toDouble() ?? 0.0,
          placeType: _extractPlaceType(item['types'] as List?),
          rating: item['rating'] != null
              ? (item['rating'] as num).toDouble()
              : null,
          photoReference: photoRef,
        );
      }).toList();
    } catch (e) {
      debugPrint('[GooglePlacesService] searchNearbyPlaces error: $e');
      return [];
    }
  }

  String? _extractPlaceType(List? types) {
    if (types == null || types.isEmpty) return null;
    // Filter out generic types, prefer specific ones
    final specificTypes = types
        .where((t) => !['establishment', 'point_of_interest', 'geocode'].contains(t))
        .toList();
    return specificTypes.isNotEmpty ? specificTypes.first as String : types.first as String;
  }
}

