import 'dart:math';

/// Utility class for distance calculations using Haversine formula
class DistanceUtils {
  /// Earth's radius in meters
  static const double earthRadiusMeters = 6371000;

  /// Calculate distance between two coordinates using Haversine formula
  /// Returns distance in meters
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Convert degrees to radians
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distance = earthRadiusMeters * c;

    return distance;
  }

  /// Convert degrees to radians
  static double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// Format distance for display
  /// Returns formatted string like "0.8 km", "150 m", "2.5 km"
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      // Less than 1 km, show in meters
      return '${distanceInMeters.round()} m';
    } else {
      // Show in kilometers with 1 decimal place
      final km = distanceInMeters / 1000;
      if (km < 10) {
        return '${km.toStringAsFixed(1)} km';
      } else {
        return '${km.round()} km';
      }
    }
  }

  /// Check if a location is within radius
  static bool isWithinRadius(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
    double radiusInMeters,
  ) {
    final distance = calculateDistance(lat1, lon1, lat2, lon2);
    return distance <= radiusInMeters;
  }
}

