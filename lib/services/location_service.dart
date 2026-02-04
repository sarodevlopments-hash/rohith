import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

/// Service for managing buyer location and permissions
class LocationService {
  static Position? _currentPosition;
  static DateTime? _lastUpdated;
  static const Duration _cacheDuration = Duration(minutes: 5); // Cache location for 5 minutes

  /// Check and request location permissions
  static Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[LocationService] Location services are disabled');
      return false;
    }

    // Check current permission status
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Request permission
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[LocationService] Location permissions are denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('[LocationService] Location permissions are permanently denied');
      return false;
    }

    return true;
  }

  /// Get current buyer location (with caching)
  static Future<Position?> getCurrentLocation({bool forceRefresh = false}) async {
    // Return cached location if still valid and not forcing refresh
    if (!forceRefresh && 
        _currentPosition != null && 
        _lastUpdated != null &&
        DateTime.now().difference(_lastUpdated!) < _cacheDuration) {
      debugPrint('[LocationService] Returning cached location');
      return _currentPosition;
    }

    // Check permissions first
    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) {
      debugPrint('[LocationService] No location permission');
      return null;
    }

    try {
      // Get current position with high accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _currentPosition = position;
      _lastUpdated = DateTime.now();
      
      debugPrint('[LocationService] Location updated: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      debugPrint('[LocationService] Error getting location: $e');
      return null;
    }
  }

  /// Get last known location (faster, may be stale)
  static Future<Position?> getLastKnownLocation() async {
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) {
        return null;
      }

      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        _currentPosition = position;
        _lastUpdated = DateTime.now();
      }
      return position;
    } catch (e) {
      debugPrint('[LocationService] Error getting last known location: $e');
      return null;
    }
  }

  /// Clear cached location
  static void clearCache() {
    _currentPosition = null;
    _lastUpdated = null;
  }

  /// Check if location is available
  static bool get hasLocation => _currentPosition != null;

  /// Get cached position (may be null)
  static Position? get cachedPosition => _currentPosition;
}

