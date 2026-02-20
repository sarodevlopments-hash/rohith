# Custom Notification Sound for New Orders (iOS)

## Required File

Place your custom notification sound file here:

**File name:** `order_ring.caf`

## Requirements

- **Format:** CAF (Core Audio Format)
- **Duration:** Under 30 seconds
- **Style:** Loud, clear ringtone (not soft notification tone)
- **File size:** Keep under 500KB for best performance

## How to Convert MP3 to CAF

### Option 1: Using macOS Terminal (Recommended)

```bash
# Convert MP3 to CAF using afconvert
afconvert -f caff -d LEI16 order_ring.mp3 order_ring.caf
```

### Option 2: Using Online Converter

1. Use an online MP3 to CAF converter
2. Download the converted `.caf` file
3. Name it exactly: `order_ring.caf`

### Option 3: Using Audacity (macOS/Windows)

1. Open your MP3 file in Audacity
2. Export as: **Other uncompressed files**
3. Choose format: **CAF (Apple Core Audio Format)**
4. Save as: `order_ring.caf`

## How to Add to Xcode Project

1. Open your project in Xcode
2. Navigate to: **Runner** → **Build Phases** → **Copy Bundle Resources**
3. Click the **+** button
4. Select `order_ring.caf` from the `ios/Runner/` directory
5. Ensure it's added to the list

## Testing

After adding the file:
1. Clean build folder in Xcode (Cmd+Shift+K)
2. Rebuild the app
3. Test on a physical device (sounds may not work in simulator)

## Important iOS Limitations

- **Silent Mode:** If the phone is on silent, the sound will NOT play (Apple restriction)
- **Do Not Disturb:** May delay notification unless "time-sensitive" is allowed
- **Volume:** Sound respects device volume settings

## Note

The sound file name (`order_ring.caf`) must match exactly what's specified in the code:
- In `notification_service.dart`: `sound: 'order_ring.caf'`
- Include the `.caf` extension in the code

