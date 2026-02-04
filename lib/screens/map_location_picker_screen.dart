import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/place_result.dart';
import '../services/places_service.dart';
import '../services/google_places_service.dart';
import '../services/mapbox_places_service.dart';
import '../services/location_service.dart';

// Conditional import for Google Maps (only on mobile, not web)
// On web, this will import a stub that prevents compilation errors
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps
    if (dart.library.html) 'package:flutter/material.dart';

/// Map-based location picker with nearby places search
/// Supports both Google Maps and Mapbox
class MapLocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;
  final MapProvider mapProvider; // 'google' or 'mapbox'

  const MapLocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
    this.mapProvider = MapProvider.google,
  });

  @override
  State<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

enum MapProvider { google, mapbox }

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  PlacesService? _placesService;
  dynamic _mapController; // GoogleMapController on mobile, null on web
  
  double? _selectedLatitude;
  double? _selectedLongitude;
  String? _selectedAddress;
  
  List<PlaceResult> _searchResults = [];
  List<PlaceResult> _nearbyPlaces = [];
  bool _isSearching = false;
  bool _isLoadingNearby = false;
  
  // Map camera position (for context-based search)
  double _cameraLatitude = 0.0;
  double _cameraLongitude = 0.0;
  
  // Map markers (only used on mobile)
  final Set<dynamic> _markers = {};
  dynamic _selectedMarkerId;

  @override
  void initState() {
    super.initState();
    _initializePlacesService();
    _loadInitialLocation();
  }

  void _initializePlacesService() {
    // Initialize the appropriate Places service based on provider
    _placesService = widget.mapProvider == MapProvider.google
        ? GooglePlacesService()
        : MapboxPlacesService();
  }

  Future<void> _loadInitialLocation() async {
    // Use provided initial location or get current location
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _cameraLatitude = widget.initialLatitude!;
      _cameraLongitude = widget.initialLongitude!;
      _selectedLatitude = widget.initialLatitude;
      _selectedLongitude = widget.initialLongitude;
      _selectedAddress = widget.initialAddress;
      
      if (mounted) {
        setState(() {
          _updateMarkers();
        });
        _loadNearbyPlaces();
      }
    } else {
      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        _cameraLatitude = position.latitude;
        _cameraLongitude = position.longitude;
        _selectedLatitude = position.latitude;
        _selectedLongitude = position.longitude;
        
        // Reverse geocode to get address
        try {
          final placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          if (placemarks.isNotEmpty) {
            _selectedAddress = _formatPlacemark(placemarks.first);
          }
        } catch (e) {
          debugPrint('[MapLocationPicker] Geocoding error: $e');
        }
        
        if (mounted) {
          setState(() {
            _updateMarkers();
          });
          _loadNearbyPlaces();
        }
      }
    }
  }

  Future<void> _loadNearbyPlaces() async {
    if (_cameraLatitude == 0.0 || _cameraLongitude == 0.0) return;
    if (_placesService == null) return;

    setState(() => _isLoadingNearby = true);

    try {
      final places = await _placesService!.searchNearbyPlaces(
        latitude: _cameraLatitude,
        longitude: _cameraLongitude,
        radius: 1000, // 1 km radius
        types: ['restaurant', 'store', 'establishment', 'point_of_interest'],
      );

      if (mounted) {
        setState(() {
          _nearbyPlaces = places;
          _isLoadingNearby = false;
        });
        _updateMarkers();
      }
    } catch (e) {
      debugPrint('[MapLocationPicker] Error loading nearby places: $e');
      if (mounted) {
        setState(() => _isLoadingNearby = false);
      }
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    // Try Places API first if available
    if (_placesService != null) {
      try {
        final results = await _placesService!.searchPlaces(
          query: query,
          latitude: _cameraLatitude != 0.0 ? _cameraLatitude : null,
          longitude: _cameraLongitude != 0.0 ? _cameraLongitude : null,
          radius: 5000, // 5 km radius for search context
        );

        if (results.isNotEmpty && mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
          return;
        }
      } catch (e) {
        debugPrint('[MapLocationPicker] Places API error: $e');
        // Fall through to geocoding fallback
      }
    }

    // Fallback to geocoding service (works without API keys)
    try {
      final locations = await locationFromAddress(query);
      final results = <PlaceResult>[];

      for (final loc in locations.take(5)) {
        try {
          final placemarks = await placemarkFromCoordinates(
            loc.latitude,
            loc.longitude,
          );
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            final address = _formatPlacemark(place);
            results.add(PlaceResult(
              placeId: '${loc.latitude}_${loc.longitude}',
              name: place.name ?? address.split(',').first,
              address: address,
              latitude: loc.latitude,
              longitude: loc.longitude,
            ));
          } else {
            results.add(PlaceResult(
              placeId: '${loc.latitude}_${loc.longitude}',
              name: 'Location',
              address: '${loc.latitude}, ${loc.longitude}',
              latitude: loc.latitude,
              longitude: loc.longitude,
            ));
          }
        } catch (e) {
          debugPrint('[MapLocationPicker] Geocoding error: $e');
        }
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('[MapLocationPicker] Search error: $e');
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _selectPlace(PlaceResult place) {
    setState(() {
      _selectedLatitude = place.latitude;
      _selectedLongitude = place.longitude;
      _selectedAddress = place.address;
      _cameraLatitude = place.latitude;
      _cameraLongitude = place.longitude;
      _searchResults = [];
      _searchController.clear();
    });

    // Move map camera to selected location
    _moveCameraToLocation(place.latitude, place.longitude);
    
    // Reload nearby places for new location
    _loadNearbyPlaces();
  }
  
  Future<void> _moveCameraToLocation(double lat, double lng) async {
    if (kIsWeb) return; // Not supported on web
    if (_mapController != null) {
      await _mapController!.animateCamera(
        maps.CameraUpdate.newLatLngZoom(
          maps.LatLng(lat, lng),
          15.0,
        ),
      );
    }
  }

  void _updateMarkers() {
    if (kIsWeb) return; // Markers not supported on web
    
    final markers = <maps.Marker>{};
    
    // Add selected location marker (red, larger)
    if (_selectedLatitude != null && _selectedLongitude != null) {
      _selectedMarkerId = const maps.MarkerId('selected');
      markers.add(maps.Marker(
        markerId: _selectedMarkerId!,
        position: maps.LatLng(_selectedLatitude!, _selectedLongitude!),
        icon: maps.BitmapDescriptor.defaultMarkerWithHue(maps.BitmapDescriptor.hueRed),
        anchor: const Offset(0.5, 1.0),
        infoWindow: maps.InfoWindow(
          title: 'Selected Location',
          snippet: _selectedAddress ?? '${_selectedLatitude!.toStringAsFixed(6)}, ${_selectedLongitude!.toStringAsFixed(6)}',
        ),
      ));
    }
    
    // Add nearby places markers (blue)
    for (var place in _nearbyPlaces) {
      final isSelected = _selectedLatitude == place.latitude &&
          _selectedLongitude == place.longitude;
      
      if (!isSelected) {
        markers.add(maps.Marker(
          markerId: maps.MarkerId(place.placeId),
          position: maps.LatLng(place.latitude, place.longitude),
          icon: maps.BitmapDescriptor.defaultMarkerWithHue(maps.BitmapDescriptor.hueBlue),
          infoWindow: maps.InfoWindow(
            title: place.name,
            snippet: place.address,
          ),
          onTap: () => _selectPlace(place),
        ));
      }
    }
    
    setState(() {
      _markers.clear();
      _markers.addAll(markers);
    });
  }

  void _onMapCameraMoved(dynamic position) {
    if (kIsWeb) return;
    _cameraLatitude = position.target.latitude;
    _cameraLongitude = position.target.longitude;
    // Optionally reload nearby places when map moves (debounced)
    // _loadNearbyPlaces();
  }
  
  void _onMapCreated(dynamic controller) {
    if (kIsWeb) return;
    _mapController = controller;
    
    // Move camera to initial location if available
    if (_selectedLatitude != null && _selectedLongitude != null) {
      _moveCameraToLocation(_selectedLatitude!, _selectedLongitude!);
    }
  }

  Future<void> _useCurrentLocation() async {
    final position = await LocationService.getCurrentLocation(forceRefresh: true);
    if (position != null) {
      _selectLocation(position.latitude, position.longitude);
    }
  }

  Future<void> _selectLocation(double lat, double lng) async {
    setState(() {
      _selectedLatitude = lat;
      _selectedLongitude = lng;
      _cameraLatitude = lat;
      _cameraLongitude = lng;
    });

    // Reverse geocode to get address
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        _selectedAddress = _formatPlacemark(placemarks.first);
      }
    } catch (e) {
      debugPrint('[MapLocationPicker] Geocoding error: $e');
    }

    if (mounted) {
      setState(() {
        _updateMarkers();
      });
      _loadNearbyPlaces();
    }
  }

  void _confirmSelection() {
    if (_selectedLatitude != null && _selectedLongitude != null) {
      Navigator.of(context).pop({
        'latitude': _selectedLatitude,
        'longitude': _selectedLongitude,
        'address': _selectedAddress ?? '${_selectedLatitude}, ${_selectedLongitude}',
      });
    }
  }

  String _formatPlacemark(Placemark place) {
    final parts = [
      place.name,
      place.street,
      place.subLocality,
      place.locality,
      place.administrativeArea,
    ].whereType<String>().where((p) => p.isNotEmpty);
    return parts.join(', ');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Pickup Location'),
        actions: [
          TextButton(
            onPressed: _selectedLatitude != null && _selectedLongitude != null
                ? _confirmSelection
                : null,
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search nearby places...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _searchPlaces('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: _searchPlaces,
                ),
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),

          // Map View (Placeholder - replace with actual map widget)
          Expanded(
            flex: 2,
            child: _buildMapView(),
          ),

          // Search Results or Nearby Places
          Expanded(
            flex: 1,
            child: _buildResultsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _useCurrentLocation,
        child: const Icon(Icons.my_location),
        tooltip: 'Use current location',
      ),
    );
  }

  Widget _buildMapView() {
    // Web fallback - show interactive map using URL launcher or iframe
    if (kIsWeb) {
      return _buildWebMapView();
    }

    // Mobile - use Google Maps Flutter
    return _buildMobileMapView();
  }

  Widget _buildWebMapView() {
    // For web, show coordinates and allow selection via search/list
    final lat = _selectedLatitude ?? _cameraLatitude;
    final lng = _selectedLongitude ?? _cameraLongitude;
    
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map, size: 64, color: Colors.blue.shade700),
            const SizedBox(height: 16),
            Text(
              'Map View (Web)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 8),
            if (lat != 0.0 && lng != 0.0) ...[
              Text(
                'Selected: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (_selectedAddress != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _selectedAddress!,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  // Open Google Maps in new tab for web
                  final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                  // Note: url_launcher should handle this, but for web you might need web-specific implementation
                  debugPrint('Would open: $url');
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open in Google Maps'),
              ),
            ] else
              const Text('Use search or select from list below'),
            const SizedBox(height: 16),
            const Text(
              'Note: Full map view available on mobile devices',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileMapView() {
    if (kIsWeb) {
      // Should not reach here on web, but just in case
      return _buildWebMapView();
    }
    
    // This will only compile on mobile platforms (not web)
    // ignore: undefined_class
    return _buildGoogleMapWidget();
  }
  
  // Separate method to isolate GoogleMap usage (prevents web compilation issues)
  // ignore: undefined_class, undefined_method
  Widget _buildGoogleMapWidget() {
    // Determine initial camera position
    final initialPosition = _selectedLatitude != null && _selectedLongitude != null
        ? maps.LatLng(_selectedLatitude!, _selectedLongitude!)
        : (_cameraLatitude != 0.0 && _cameraLongitude != 0.0
            ? maps.LatLng(_cameraLatitude, _cameraLongitude)
            : const maps.LatLng(17.3850, 78.4867)); // Default: Hyderabad

    return maps.GoogleMap(
      initialCameraPosition: maps.CameraPosition(
        target: initialPosition,
        zoom: _selectedLatitude != null ? 15.0 : 12.0,
      ),
      onMapCreated: _onMapCreated,
      markers: _markers.cast<maps.Marker>(),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      mapType: maps.MapType.normal,
      zoomControlsEnabled: false,
      onCameraMove: _onMapCameraMoved,
      onTap: (maps.LatLng position) {
        _selectLocation(position.latitude, position.longitude);
      },
      padding: const EdgeInsets.only(bottom: 200), // Space for results list
    );
  }

  Widget _buildResultsList() {
    if (_searchResults.isNotEmpty) {
      return _buildSearchResults();
    } else if (_isLoadingNearby) {
      return const Center(child: CircularProgressIndicator());
    } else if (_nearbyPlaces.isNotEmpty) {
      return _buildNearbyPlaces();
    } else {
      return const Center(
        child: Text('Search for places or tap on map'),
      );
    }
  }

  Widget _buildSearchResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Search Results (${_searchResults.length})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final place = _searchResults[index];
              return ListTile(
                leading: const Icon(Icons.place),
                title: Text(place.name),
                subtitle: Text(place.address),
                trailing: place.placeType != null
                    ? Chip(
                        label: Text(
                          place.placeType!,
                          style: const TextStyle(fontSize: 10),
                        ),
                        padding: EdgeInsets.zero,
                      )
                    : null,
                onTap: () => _selectPlace(place),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNearbyPlaces() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Nearby Places (${_nearbyPlaces.length})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _nearbyPlaces.length,
            itemBuilder: (context, index) {
              final place = _nearbyPlaces[index];
              final isSelected = _selectedLatitude == place.latitude &&
                  _selectedLongitude == place.longitude;

              return ListTile(
                leading: Icon(
                  Icons.location_on,
                  color: isSelected ? Colors.red : Colors.grey,
                ),
                title: Text(place.name),
                subtitle: Text(place.address),
                trailing: place.rating != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.amber),
                          Text('${place.rating!.toStringAsFixed(1)}'),
                        ],
                      )
                    : null,
                selected: isSelected,
                onTap: () => _selectPlace(place),
              );
            },
          ),
        ),
      ],
    );
  }
}

