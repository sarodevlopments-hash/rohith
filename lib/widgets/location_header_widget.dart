import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import '../services/location_service.dart';
import 'package:flutter/foundation.dart';

/// Widget to display buyer's current location in the header
class LocationHeaderWidget extends StatefulWidget {
  final Function(String? address)? onLocationChanged;
  final Function()? onTap;

  const LocationHeaderWidget({
    super.key,
    this.onLocationChanged,
    this.onTap,
  });

  @override
  State<LocationHeaderWidget> createState() => _LocationHeaderWidgetState();
}

class _LocationHeaderWidgetState extends State<LocationHeaderWidget> {
  String? _currentAddress;
  bool _isLoading = false;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation({bool forceRefresh = false}) async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // Check permission first
      final hasPermission = await LocationService.checkAndRequestPermission();
      if (!hasPermission) {
        if (mounted) {
          setState(() {
            _hasPermission = false;
            _isLoading = false;
            _currentAddress = null;
          });
        }
        return;
      }

      setState(() => _hasPermission = true);

      // Get current location
      final position = await LocationService.getCurrentLocation(
        forceRefresh: forceRefresh,
      );

      if (position == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _currentAddress = null;
          });
        }
        return;
      }

      // Convert coordinates to readable address with defensive error handling
      String? formattedAddress;
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
          localeIdentifier: 'en',
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () => <Placemark>[],
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          // Format: "Area, City" (e.g., "Banjara Hills, Hyderabad")
          final addressParts = <String>[];
          
          // Safely extract address parts with null checks - use try-catch for each field access
          try {
            final subLocality = place.subLocality;
            if (subLocality != null && subLocality.isNotEmpty) {
              addressParts.add(subLocality);
            }
          } catch (_) {}
          
          try {
            final locality = place.locality;
            if (locality != null && locality.isNotEmpty && addressParts.isEmpty) {
              addressParts.add(locality);
            }
          } catch (_) {}
          
          try {
            final administrativeArea = place.administrativeArea;
            if (administrativeArea != null && administrativeArea.isNotEmpty) {
              addressParts.add(administrativeArea);
            }
          } catch (_) {}

          formattedAddress = addressParts.isNotEmpty
              ? addressParts.join(', ')
              : 'Location detected';
        } else {
          formattedAddress = 'Location detected';
        }
      } catch (e, stackTrace) {
        debugPrint('[LocationHeaderWidget] Geocoding error: $e');
        debugPrint('[LocationHeaderWidget] Stack trace: $stackTrace');
        // Fallback: use coordinates as address
        formattedAddress = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }

      if (mounted) {
        setState(() {
          _currentAddress = formattedAddress;
          _isLoading = false;
        });

        // Notify parent of location change
        widget.onLocationChanged?.call(formattedAddress);
      }
    } catch (e) {
      debugPrint('[LocationHeaderWidget] Error loading location: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentAddress = null;
        });
      }
    }
  }

  Future<void> _handleTap() async {
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }

    // Default behavior: refresh location
    await _loadCurrentLocation(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade600),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Detecting location...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    if (!_hasPermission || _currentAddress == null) {
      return InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                'Tap to set location',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on,
              size: 16,
              color: Colors.blue.shade600,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _currentAddress!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: Colors.blue.shade600,
            ),
          ],
        ),
      ),
    );
  }
}

