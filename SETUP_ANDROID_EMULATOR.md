# Setting Up Android Emulator for Integration Tests (Windows)

## ⚠️ Important
Integration tests **require** an Android emulator or iOS simulator. Web and desktop devices are **NOT supported**.

## Step-by-Step Guide

### 1. Install Android Studio

1. Download Android Studio from: https://developer.android.com/studio
2. Run the installer
3. Follow the installation wizard
4. Complete the setup (SDK components will be downloaded)

### 2. Create an Android Virtual Device (AVD)

1. **Open Android Studio**
2. **Go to**: `Tools` → `Device Manager`
3. **Click**: `Create Device` button
4. **Select Device**:
   - Choose `Pixel 5` (recommended) or any device
   - Click `Next`
5. **Select System Image**:
   - Choose `API 33` (Android 13) or latest stable version
   - If not downloaded, click `Download` next to the system image
   - Wait for download to complete
   - Click `Next`
6. **Configure AVD**:
   - Name: `test_emulator` (or any name)
   - Click `Finish`

### 3. Start the Emulator

**Option A: From Android Studio**
1. In Device Manager, find your created emulator
2. Click the **Play** button (▶️)
3. Wait for emulator to boot (1-2 minutes)

**Option B: From Command Line**
```bash
# List available emulators
flutter emulators

# Launch emulator
flutter emulators --launch <emulator_id>
```

### 4. Verify Emulator is Running

```bash
# Check if Flutter detects the emulator
flutter devices
```

You should see output like:
```
sdk gphone64 arm64 • emulator-5554 • android-arm64  • Android 13 (API 33)
```

### 5. Run Integration Tests

Once the emulator is running and detected:

```bash
# Run all tests
flutter test integration_test/

# Or specify the device explicitly
flutter test integration_test/ -d emulator-5554
```

## Troubleshooting

### Emulator Not Detected

**Problem**: `flutter devices` doesn't show the emulator

**Solutions**:
1. **Wait longer**: Emulators take 1-2 minutes to fully boot
2. **Check Android Studio**: Make sure emulator is actually running
3. **Restart Flutter**: 
   ```bash
   flutter doctor
   flutter devices
   ```
4. **Check ADB**: 
   ```bash
   adb devices
   ```
   Should show: `emulator-5554 device`

### Emulator Too Slow

**Solutions**:
1. **Enable Hardware Acceleration**:
   - In Android Studio: `Tools` → `SDK Manager` → `SDK Tools`
   - Check `Intel x86 Emulator Accelerator (HAXM installer)`
   - Install and restart

2. **Reduce Emulator Resources**:
   - In Device Manager, click `Edit` (pencil icon)
   - Reduce RAM (e.g., 2GB instead of 4GB)
   - Reduce VM heap (e.g., 256MB)

### "Web devices are not supported"

**Error**: `Web devices are not supported for integration tests yet.`

**Solution**: You must use an Android emulator or iOS simulator. Web/Desktop devices cannot run integration tests.

### Emulator Crashes

**Solutions**:
1. **Update Android Studio** to latest version
2. **Update system images** in SDK Manager
3. **Check system requirements**: Ensure your PC meets minimum specs
4. **Try different system image**: Use API 30 or 31 instead of 33

## Alternative: Use Physical Android Device

If emulator is too slow or problematic:

1. **Enable Developer Options** on your Android phone:
   - Go to `Settings` → `About Phone`
   - Tap `Build Number` 7 times
   - Go back to `Settings` → `Developer Options`
   - Enable `USB Debugging`

2. **Connect Phone via USB**

3. **Verify Connection**:
   ```bash
   flutter devices
   adb devices
   ```

4. **Run Tests**:
   ```bash
   flutter test integration_test/ -d <your_device_id>
   ```

## Performance Tips

1. **Keep Emulator Running**: Don't close it between test runs
2. **Use Cold Boot**: Only when necessary (first time or after changes)
3. **Allocate Resources**: Give emulator enough RAM (4GB recommended)
4. **Close Other Apps**: Free up system resources

## Next Steps

Once emulator is running:
1. Verify: `flutter devices` shows your emulator
2. Run tests: `flutter test integration_test/`
3. Check results in terminal
4. View detailed logs if tests fail

## Need Help?

- Check `TESTING_SETUP.md` for general testing guide
- Check `integration_test/README.md` for test-specific docs
- Review Flutter documentation: https://docs.flutter.dev/testing/integration-tests

