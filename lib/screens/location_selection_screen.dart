import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import 'package:flutter/foundation.dart';

/// Screen for selecting or updating delivery location
class LocationSelectionScreen extends StatefulWidget {
  const LocationSelectionScreen({super.key});

  @override
  State<LocationSelectionScreen> createState() => _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  bool _isLoading = false;
  bool _hasPermission = false;
  String? _currentAddress;
  Position? _currentPosition;
  final TextEditingController _searchController = TextEditingController();
  List<Placemark> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation({bool requestPermission = false}) async {
    setState(() => _isLoading = true);

    try {
      // Check permission status first
      final permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (requestPermission) {
          // Request permission
          final newPermission = await Geolocator.requestPermission();
          if (newPermission == LocationPermission.denied || 
              newPermission == LocationPermission.deniedForever) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasPermission = false;
              });
            }
            return;
          }
        } else {
          // Permission not granted yet, show button to request
          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasPermission = false;
            });
          }
          return;
        }
      }

      // Permission granted, check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasPermission = false;
          });
          _showLocationServiceDisabledDialog();
        }
        return;
      }

      setState(() => _hasPermission = true);

      final position = await LocationService.getCurrentLocation(forceRefresh: true);
      if (position == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      _currentPosition = position;

      // Convert to address with defensive error handling
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
              : 'Current Location';
        } else {
          formattedAddress = 'Current Location';
        }
      } catch (e, stackTrace) {
        debugPrint('[LocationSelectionScreen] Geocoding error: $e');
        debugPrint('[LocationSelectionScreen] Stack trace: $stackTrace');
        // Fallback: use coordinates as address
        formattedAddress = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }

      if (mounted) {
        setState(() {
          _currentAddress = formattedAddress ?? 'Current Location';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[LocationSelectionScreen] Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasPermission = false;
        });
      }
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    try {
      final locations = await locationFromAddress(query);
      if (mounted) {
        final placemarks = await Future.wait(
          locations.map((loc) => placemarkFromCoordinates(loc.latitude, loc.longitude)),
        );
        
        setState(() {
          _searchResults = placemarks.expand((p) => p).toList();
        });
      }
    } catch (e) {
      debugPrint('[LocationSelectionScreen] Search error: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
        });
      }
    }
  }

  Future<void> _selectLocation(Placemark placemark, double? lat, double? lon) async {
    if (lat == null || lon == null) return;

    // Clear cache and update location
    LocationService.clearCache();
    
    // Note: We can't directly set location in LocationService, but clearing cache
    // will force next getCurrentLocation() call to fetch fresh location
    // For now, we'll return the selected address and let the parent handle refresh

    final addressParts = <String>[];
    if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
      addressParts.add(placemark.subLocality!);
    } else if (placemark.locality != null && placemark.locality!.isNotEmpty) {
      addressParts.add(placemark.locality!);
    }
    if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
      addressParts.add(placemark.administrativeArea!);
    }

    if (mounted) {
      Navigator.pop(context, addressParts.isNotEmpty ? addressParts.join(', ') : 'Selected Location');
    }
  }

  void _showLocationServiceDisabledDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text(
          'Please enable location services on your device to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Delivery Location'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for area, city...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchLocation('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _searchLocation,
            ),
          ),
          
          // Current location section - Always show this button
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Detecting your location...',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            InkWell(
              onTap: () async {
                if (_hasPermission && _currentPosition != null && _currentAddress != null) {
                  // Location is available, use it
                  Navigator.pop(context, _currentAddress);
                } else {
                  // Request permission and load location
                  await _loadCurrentLocation(requestPermission: true);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: _hasPermission && _currentAddress != null
                      ? Colors.blue.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _hasPermission && _currentAddress != null
                        ? Colors.blue.shade200
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _hasPermission && _currentAddress != null
                          ? Icons.my_location
                          : Icons.location_searching,
                      color: _hasPermission && _currentAddress != null
                          ? Colors.blue.shade700
                          : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _hasPermission && _currentAddress != null
                                ? 'Use Current Location'
                                : 'Detect Current Location',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _hasPermission && _currentAddress != null
                                  ? Colors.blue.shade900
                                  : Colors.grey.shade900,
                            ),
                          ),
                          if (_hasPermission && _currentAddress != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _currentAddress!,
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 4),
                            Text(
                              'Tap to allow location access',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: _hasPermission && _currentAddress != null
                          ? Colors.blue.shade700
                          : Colors.grey.shade700,
                    ),
                  ],
                ),
              ),
            ),

          // Search results
          if (_searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final placemark = _searchResults[index];
                  final addressParts = <String>[];
                  
                  if (placemark.name != null && placemark.name!.isNotEmpty) {
                    addressParts.add(placemark.name!);
                  }
                  if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
                    addressParts.add(placemark.subLocality!);
                  }
                  if (placemark.locality != null && placemark.locality!.isNotEmpty) {
                    addressParts.add(placemark.locality!);
                  }
                  if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
                    addressParts.add(placemark.administrativeArea!);
                  }

                  return ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(addressParts.isNotEmpty ? addressParts.first : 'Location'),
                    subtitle: addressParts.length > 1
                        ? Text(addressParts.sublist(1).join(', '))
                        : null,
                    onTap: () async {
                      // Get coordinates from search result
                      try {
                        final searchQuery = addressParts.join(', ');
                        if (searchQuery.isEmpty) {
                          debugPrint('[LocationSelectionScreen] Empty search query');
                          return;
                        }
                        final locations = await locationFromAddress(searchQuery);
                        if (locations.isNotEmpty) {
                          final location = locations.first;
                          await _selectLocation(
                            placemark,
                            location.latitude,
                            location.longitude,
                          );
                        } else {
                          debugPrint('[LocationSelectionScreen] No locations found for: $searchQuery');
                        }
                      } catch (e) {
                        debugPrint('[LocationSelectionScreen] Error getting coordinates: $e');
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

