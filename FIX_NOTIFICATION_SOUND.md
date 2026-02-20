# Fix: Notification Sound Not Playing

## Problem
Channel is created successfully (you see the log), but sound doesn't play.

## Root Cause
The sound file might not be bundled in the APK, or the app needs a **full clean rebuild**.

## ✅ Solution: Clean Rebuild

### Step 1: Clean Build
```bash
flutter clean
```

### Step 2: Get Dependencies
```bash
flutter pub get
```

### Step 3: Uninstall App from Device
```bash
# Find your package name first (check android/app/build.gradle.kts)
adb uninstall com.example.foodApp
```

Or manually uninstall from device/emulator.

### Step 4: Full Rebuild and Install
```bash
flutter run --release
```

Or for debug:
```bash
flutter run
```

## 🔍 Verify Sound File is in APK

### Option 1: Check APK Contents
```bash
# Build APK first
flutter build apk --debug

# Extract and check (on Linux/Mac)
unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep order_ring

# On Windows, use 7-Zip or WinRAR to open the APK
# Navigate to: res/raw/ and check if order_ring.mp3 exists
```

### Option 2: Check File Location
Verify the file is exactly here:
```
android/app/src/main/res/raw/order_ring.mp3
```

## 🐛 Common Issues

### Issue 1: File Not Bundled
**Symptom:** Channel created but no sound
**Solution:** 
- Do `flutter clean` and rebuild
- Verify file is in `res/raw/` (not `res/drawable/`)
- Check file name is exactly `order_ring.mp3` (lowercase)

### Issue 2: Invalid MP3 Format
**Symptom:** File exists but Android can't play it
**Solution:**
- Re-encode MP3 with standard settings
- Try a different MP3 file
- Ensure file is under 500KB

### Issue 3: Channel Still Using Old Settings
**Symptom:** Even after restart, old channel persists
**Solution:**
- **Must uninstall app completely** (not just restart)
- Clear app data doesn't always delete channels
- Full uninstall + reinstall is required

## ✅ Verification Checklist

After clean rebuild and reinstall:

1. ✅ Check log shows: `Created notification channel: new_order_channel_v2 with custom sound: order_ring`
2. ✅ Verify sound file in APK (use method above)
3. ✅ Check device notification volume is ON
4. ✅ Test notification by placing order
5. ✅ Check Settings → Apps → Your App → Notifications → "New Order Alerts" channel exists

## 🎯 Quick Test

1. **Clean everything:**
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Uninstall app:**
   ```bash
   adb uninstall com.example.foodApp
   ```

3. **Rebuild and run:**
   ```bash
   flutter run
   ```

4. **Check logs for channel creation**

5. **Test notification**

## 📝 Important Notes

- **MP3 file must be valid:** Try playing it on your computer first
- **File name is case-sensitive:** `order_ring.mp3` (not `Order_Ring.mp3`)
- **Location matters:** Must be in `res/raw/` not `res/drawable/`
- **Full uninstall required:** Restarting app is NOT enough - must uninstall

