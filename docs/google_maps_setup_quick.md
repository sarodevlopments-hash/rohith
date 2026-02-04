# Quick Google Maps Setup Guide

## Step 1: Install Package

Run:
```bash
flutter pub get
```

## Step 2: Get Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create/Select a project
3. Enable these APIs:
   - **Maps SDK for Android**
   - **Maps SDK for iOS** 
   - **Places API** (for search)
   - **Geocoding API** (for address lookup)
4. Create API Key: APIs & Services → Credentials → Create Credentials → API Key
5. (Optional) Restrict the API key to your app's package name

## Step 3: Configure Android

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
  <application>
    <!-- Add this inside <application> tag -->
    <meta-data
        android:name="com.google.android.geo.API_KEY"
        android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
  </application>
</manifest>
```

## Step 4: Configure iOS

Add to `ios/Runner/AppDelegate.swift`:

```swift
import UIKit
import Flutter
import GoogleMaps  // Add this import

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")  // Add this line
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

## Step 5: (Optional) Configure Places API Key

For better search results, add your Places API key to:
`lib/services/google_places_service.dart`:
```dart
static const String _apiKey = 'YOUR_GOOGLE_PLACES_API_KEY';
```

## Testing

1. Run the app
2. Go to Add Listing → Pickup Location → Search nearby places
3. You should see the Google Map with your current location
4. Search for places and tap markers to select

## Troubleshooting

**Map shows blank/grey:**
- Check API key is correctly set in AndroidManifest.xml / AppDelegate.swift
- Verify API key has Maps SDK enabled
- Check billing is enabled (Google Maps requires billing)

**Search not working:**
- Verify Places API is enabled
- Check API key restrictions
- Fallback geocoding will work without Places API

**Build errors:**
- Run `flutter clean && flutter pub get`
- For iOS: `cd ios && pod install && cd ..`

