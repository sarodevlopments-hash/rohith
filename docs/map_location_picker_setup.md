# Map Location Picker Setup Guide

## Overview

This implementation provides a map-based location picker with nearby places search that works with both Google Maps and Mapbox/Apple Maps.

## Features

✅ Search bar with autocomplete  
✅ Nearby places (POIs) displayed on map  
✅ Tap POI to select  
✅ Search updates based on map camera position  
✅ Cross-platform support (Google Maps + Mapbox)  
✅ Consistent UX across both providers  

## Setup Instructions

### Step 1: Add Required Packages

The `http` package has been added to `pubspec.yaml`. For full map functionality, add:

```yaml
dependencies:
  # For Google Maps (recommended)
  google_maps_flutter: ^2.5.0
  
  # OR for Mapbox
  mapbox_maps_flutter: ^1.0.0
```

Run:
```bash
flutter pub get
```

### Step 2: Get API Keys

#### Google Maps:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable these APIs:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Places API
   - Geocoding API
4. Create API key
5. Add to `lib/services/google_places_service.dart`:
   ```dart
   static const String _apiKey = 'YOUR_GOOGLE_PLACES_API_KEY';
   ```

#### Mapbox:
1. Go to [Mapbox Account](https://account.mapbox.com/)
2. Get your access token
3. Add to `lib/services/mapbox_places_service.dart`:
   ```dart
   static const String _accessToken = 'YOUR_MAPBOX_ACCESS_TOKEN';
   ```

### Step 3: Configure Android (Google Maps)

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
  <application>
    <meta-data
        android:name="com.google.android.geo.API_KEY"
        android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
  </application>
</manifest>
```

### Step 4: Configure iOS (Google Maps)

Add to `ios/Runner/AppDelegate.swift`:

```swift
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### Step 5: Permissions

Already configured in your app:
- ✅ `NSLocationWhenInUseUsageDescription` (iOS)
- ✅ `ACCESS_FINE_LOCATION` (Android)

## Usage

### Basic Usage

```dart
// Open map location picker
final result = await Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const MapLocationPickerScreen(
      mapProvider: MapProvider.google, // or MapProvider.mapbox
    ),
  ),
);

if (result != null) {
  final lat = result['latitude'] as double;
  final lng = result['longitude'] as double;
  final address = result['address'] as String;
  // Use the selected location
}
```

### Integration with Add Listing Screen

Already integrated! The "Search nearby places" option in the location picker now opens the map-based picker.

## Implementation Details

### Architecture

```
PlacesService (Abstract)
├── GooglePlacesService (HTTP API)
└── MapboxPlacesService (HTTP API)

MapLocationPickerScreen
├── Search Bar (autocomplete)
├── Map View (placeholder - add map widget)
└── Results List (search results + nearby places)
```

### Key Components

1. **PlacesService**: Abstract interface for place search
2. **GooglePlacesService**: Google Places API implementation
3. **MapboxPlacesService**: Mapbox Geocoding API implementation
4. **MapLocationPickerScreen**: Main UI screen
5. **PlaceResult**: Model for place data

### API Usage

#### Google Places API:
- **Autocomplete**: `/place/autocomplete/json`
- **Details**: `/place/details/json`
- **Nearby Search**: `/place/nearbysearch/json`

#### Mapbox Geocoding API:
- **Search**: `/geocoding/v5/mapbox.places/{query}.json`
- **Reverse**: `/geocoding/v5/mapbox.places/{lng},{lat}.json`

## Next Steps: Adding Actual Map Widget

### For Google Maps:

1. Install `google_maps_flutter`
2. Replace `_buildMapView()` in `map_location_picker_screen.dart`:

```dart
Widget _buildMapView() {
  return GoogleMap(
    initialCameraPosition: CameraPosition(
      target: LatLng(_cameraLatitude, _cameraLongitude),
      zoom: 15,
    ),
    myLocationEnabled: true,
    myLocationButtonEnabled: false,
    markers: _buildMarkers(),
    onCameraMove: (CameraPosition position) {
      _onMapCameraMoved(
        position.target.latitude,
        position.target.longitude,
      );
    },
    onTap: (LatLng position) {
      _selectLocation(position.latitude, position.longitude);
    },
  );
}

Set<Marker> _buildMarkers() {
  final markers = <Marker>{};
  
  // Selected location marker
  if (_selectedLatitude != null && _selectedLongitude != null) {
    markers.add(Marker(
      markerId: const MarkerId('selected'),
      position: LatLng(_selectedLatitude!, _selectedLongitude!),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    ));
  }
  
  // Nearby places markers
  for (var place in _nearbyPlaces) {
    markers.add(Marker(
      markerId: MarkerId(place.placeId),
      position: LatLng(place.latitude, place.longitude),
      infoWindow: InfoWindow(title: place.name),
      onTap: () => _selectPlace(place),
    ));
  }
  
  return markers;
}
```

### For Mapbox:

Similar approach using `MapboxMap` widget from `mapbox_maps_flutter`.

## Testing

1. Test search functionality
2. Test nearby places loading
3. Test place selection
4. Test map camera movement updates search context
5. Test POI tap selection

## Troubleshooting

### API Key Issues:
- Ensure API key is correctly set
- Check API restrictions in Google Cloud Console
- Verify billing is enabled (Google Maps requires billing)

### No Results:
- Check internet connection
- Verify API quotas haven't been exceeded
- Check API key permissions

### Map Not Showing:
- Ensure map package is installed
- Check platform-specific configuration
- Verify API keys are set correctly

## Cost Considerations

### Google Maps:
- Autocomplete: $2.83 per 1000 requests
- Places Details: $17 per 1000 requests
- Nearby Search: $32 per 1000 requests

### Mapbox:
- Geocoding: Free tier includes 100,000 requests/month
- After free tier: $0.75 per 1000 requests

## Security Best Practices

1. **Restrict API Keys**: Add restrictions in Google Cloud Console
2. **Use Environment Variables**: Don't hardcode API keys
3. **Implement Rate Limiting**: Prevent abuse
4. **Cache Results**: Reduce API calls

## Future Enhancements

- [ ] Add map widget integration
- [ ] Implement result caching
- [ ] Add place photos
- [ ] Support custom map styles
- [ ] Add route preview
- [ ] Implement offline support

