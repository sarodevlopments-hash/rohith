import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';

/// Utility to parse seller pickup location (coordinates or address string)
class LocationParser {
  /// Parse pickup location string to get coordinates
  /// Returns (latitude, longitude) or null if parsing fails
  static Future<Map<String, double>?> parseLocation(String pickupLocation) async {
    if (pickupLocation.isEmpty) {
      return null;
    }

    // Try to parse as coordinates first (format: "lat, lng" or "lat,lng")
    final coordinates = _parseCoordinates(pickupLocation);
    if (coordinates != null) {
      return coordinates;
    }

    // If not coordinates, try geocoding the address
    try {
      final locations = await locationFromAddress(pickupLocation);
      if (locations.isNotEmpty) {
        final location = locations.first;
        return {
          'latitude': location.latitude,
          'longitude': location.longitude,
        };
      }
    } catch (e) {
      debugPrint('[LocationParser] Geocoding failed for "$pickupLocation": $e');
    }

    return null;
  }

  /// Parse coordinate string (e.g., "19.0760, 72.8777" or "19.0760,72.8777")
  /// Also handles malformed strings like "17.16252102078.789241720321125" (missing comma)
  static Map<String, double>? _parseCoordinates(String locationString) {
    try {
      // Remove whitespace
      final cleaned = locationString.trim();
      
      // First, try standard format with comma separator
      final parts = cleaned.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());

        if (lat != null && lng != null) {
          // Validate latitude and longitude ranges
          if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
            return {
              'latitude': lat,
              'longitude': lng,
            };
          }
        }
      }

      // Fallback: Try to parse malformed coordinates (e.g., "17.16252102078.789241720321125")
      // This happens when coordinates are concatenated without a comma
      // Pattern: "lat.long" where lat and long both have decimal points
      final decimalPoints = cleaned.split('.').length - 1;
      if (decimalPoints >= 2) {
        debugPrint('[LocationParser] Attempting to fix malformed coordinates: "$locationString" (has $decimalPoints decimal points)');
        
        // Find the second decimal point
        final firstDecimalIndex = cleaned.indexOf('.');
        if (firstDecimalIndex > 0) {
          final secondDecimalIndex = cleaned.indexOf('.', firstDecimalIndex + 1);
          if (secondDecimalIndex > firstDecimalIndex && secondDecimalIndex < cleaned.length - 1) {
            // Split at second decimal point
            final potentialLat = cleaned.substring(0, secondDecimalIndex);
            final lngPart = cleaned.substring(secondDecimalIndex + 1);
            
            debugPrint('[LocationParser] Split: lat="$potentialLat", lngPart="$lngPart"');
            
            // The longitude part might be missing its decimal point
            // Try to intelligently add it back
            // Pattern: "78.789241720321125" -> after split becomes "789241720321125"
            // We need to find where to insert the decimal point
            
            // Try different positions for the decimal point in longitude
            // Longitude typically starts with 2-3 digits before decimal
            // We'll try all positions and prefer the one that makes most sense
            Map<String, double>? bestMatch;
            double? bestLngDiff;
            
            for (int i = 1; i <= 3 && i < lngPart.length; i++) {
              final potentialLng = lngPart.substring(0, i) + '.' + lngPart.substring(i);
              final lat = double.tryParse(potentialLat);
              final lng = double.tryParse(potentialLng);
              
              debugPrint('[LocationParser] Trying: lat=$lat, lng=$lng (from "$potentialLng")');
              
              if (lat != null && lng != null) {
                // Validate ranges
                if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
                  // Prefer longitude values that are reasonable (between 60-100 for India region)
                  // This helps avoid parsing errors like 98 instead of 78
                  final lngDiff = (lng - 78).abs(); // 78 is typical for Hyderabad/India region
                  
                  if (bestMatch == null || bestLngDiff == null || lngDiff < bestLngDiff) {
                    bestMatch = {
                      'latitude': lat,
                      'longitude': lng,
                    };
                    bestLngDiff = lngDiff;
                    debugPrint('[LocationParser] ✓ Candidate: "$potentialLat, $potentialLng" (lng diff from 78: ${lngDiff.toStringAsFixed(2)})');
                  }
                } else {
                  debugPrint('[LocationParser] ✗ Invalid ranges: lat=$lat (valid: -90 to 90), lng=$lng (valid: -180 to 180)');
                }
              }
            }
            
            if (bestMatch != null) {
              debugPrint('[LocationParser] ✓ Fixed malformed coordinates "$locationString" -> "${bestMatch['latitude']}, ${bestMatch['longitude']}"');
              return bestMatch;
            }
            
            // Also try without adding decimal (in case longitude doesn't have one)
            final lat = double.tryParse(potentialLat);
            final lng = double.tryParse(lngPart);
            if (lat != null && lng != null) {
              if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
                debugPrint('[LocationParser] ✓ Fixed malformed coordinates "$locationString" -> "$potentialLat, $lngPart"');
                return {
                  'latitude': lat,
                  'longitude': lng,
                };
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[LocationParser] Error parsing coordinates "$locationString": $e');
    }

    return null;
  }

  /// Check if location string is in coordinate format
  static bool isCoordinateFormat(String locationString) {
    return _parseCoordinates(locationString) != null;
  }
}

