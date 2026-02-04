# Map-Based Location Picker with Nearby Places Search

## Implementation Plan

### 1. Required Packages

Add to `pubspec.yaml`:

```yaml
dependencies:
  # Google Maps (Primary)
  google_maps_flutter: ^2.5.0
  google_places_flutter: ^3.1.0
  
  # Mapbox (Alternative/Cross-platform)
  mapbox_maps_flutter: ^1.0.0
  
  # Places API abstraction
  places_service: ^2.0.0  # Or use direct API calls
```

### 2. API Keys Setup

#### Google Maps:
- Get API key from Google Cloud Console
- Enable: Maps SDK for Android/iOS, Places API, Geocoding API
- Add to `android/app/src/main/AndroidManifest.xml`:
  ```xml
  <meta-data
      android:name="com.google.android.geo.API_KEY"
      android:value="YOUR_API_KEY"/>
  ```
- Add to `ios/Runner/AppDelegate.swift`:
  ```swift
  GMSServices.provideAPIKey("YOUR_API_KEY")
  ```

#### Mapbox:
- Get access token from Mapbox account
- Store in environment/config file

### 3. Permissions

Already configured in your app:
- `NSLocationWhenInUseUsageDescription` (iOS)
- `ACCESS_FINE_LOCATION` (Android)

### 4. Architecture

```
lib/
  screens/
    map_location_picker_screen.dart  # Main map picker screen
  services/
    places_service.dart               # Abstract Places API service
    google_places_service.dart        # Google Places implementation
    mapbox_places_service.dart        # Mapbox Places implementation
  widgets/
    map_search_bar.dart               # Search bar widget
    poi_marker.dart                   # POI marker widget
```

### 5. Features

- ✅ Map view with current location
- ✅ Search bar with autocomplete
- ✅ POI markers on map
- ✅ Tap POI to select
- ✅ Camera position updates search context
- ✅ Cross-platform (Google Maps + Mapbox)

