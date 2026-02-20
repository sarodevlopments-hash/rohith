#!/bin/bash
# Fix APK Location Script
# This script copies the APK from Gradle output to Flutter's expected location
# Run this if Flutter test runner can't find the APK

GRADLE_APK="android/app/build/outputs/apk/debug/app-debug.apk"
FLUTTER_APK="build/app/outputs/flutter-apk/app-debug.apk"

if [ -f "$GRADLE_APK" ]; then
    echo "✅ APK found at Gradle location: $GRADLE_APK"
    
    # Create Flutter output directory if it doesn't exist
    mkdir -p "$(dirname "$FLUTTER_APK")"
    
    # Copy APK to Flutter location
    cp "$GRADLE_APK" "$FLUTTER_APK"
    echo "✅ APK copied to Flutter location: $FLUTTER_APK"
    
    APK_SIZE=$(du -h "$FLUTTER_APK" | cut -f1)
    echo "📦 APK Size: $APK_SIZE"
    echo "✅ Ready for Flutter test runner!"
else
    echo "❌ APK not found at: $GRADLE_APK"
    echo "💡 Run 'flutter build apk --debug' or 'cd android && ./gradlew :app:assembleDebug' first"
    exit 1
fi

