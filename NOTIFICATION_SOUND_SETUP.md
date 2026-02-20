# Loud New Order Notification Sound Setup Guide

## 🎯 Objective

Implement loud custom ringtone notifications for new orders on both Android and iOS, without changing any UI, flow, or order behavior.

## ✅ Implementation Status

The code has been updated to support custom notification sounds. You now need to add the actual sound files.

## 📱 ANDROID SETUP

### Step 1: Add Sound File

1. Create or obtain a loud ringtone-style sound file (5-8 seconds, MP3 format)
2. Name it exactly: `order_ring.mp3`
3. Place it in: `android/app/src/main/res/raw/order_ring.mp3`

### Step 2: Reinstall App

⚠️ **IMPORTANT:** You must uninstall and reinstall the app after adding the sound file.

Android notification channels cannot be modified after creation. If the app was previously installed, the channel was created without the custom sound. Reinstalling recreates the channel with the new sound.

### Step 3: Verify

- The sound file should be in: `android/app/src/main/res/raw/order_ring.mp3`
- Rebuild and reinstall the app
- Test by placing a new order

## 🍎 iOS SETUP

### Step 1: Convert Sound to CAF Format

iOS requires `.caf` (Core Audio Format) files. Convert your MP3:

**Using macOS Terminal:**
```bash
afconvert -f caff -d LEI16 order_ring.mp3 order_ring.caf
```

**Or use an online converter:**
- Search for "MP3 to CAF converter"
- Convert your sound file
- Download the `.caf` file

### Step 2: Add to Xcode Project

1. Place `order_ring.caf` in: `ios/Runner/`
2. Open project in Xcode
3. Go to: **Runner** → **Build Phases** → **Copy Bundle Resources**
4. Click **+** and add `order_ring.caf`
5. Ensure it appears in the list

### Step 3: Rebuild

1. Clean build folder (Cmd+Shift+K in Xcode)
2. Rebuild the app
3. Test on a physical device (sounds may not work in simulator)

## 🔧 Code Changes Made

### Android
- Updated notification channel to use `RawResourceAndroidNotificationSound('order_ring')`
- Updated notification details to specify custom sound
- Channel ID changed to `new_order_channel` for clarity

### iOS
- Updated notification details to use `sound: 'order_ring.caf'`
- Already configured with `interruptionLevel: InterruptionLevel.timeSensitive` for immediate delivery

## 📋 Backend FCM Payload (For Reference)

If you're sending notifications via FCM from a backend, use these payloads:

### Android
```json
{
  "to": "seller_device_token",
  "priority": "high",
  "android": {
    "priority": "high",
    "notification": {
      "channel_id": "new_order_channel",
      "sound": "order_ring"
    }
  },
  "notification": {
    "title": "New Order Received",
    "body": "You have a new order"
  },
  "data": {
    "type": "new_order",
    "orderId": "12345"
  }
}
```

### iOS
```json
{
  "to": "seller_device_token",
  "priority": "high",
  "notification": {
    "title": "New Order Received",
    "body": "You have a new order",
    "sound": "order_ring.caf"
  },
  "apns": {
    "headers": {
      "apns-priority": "10"
    },
    "payload": {
      "aps": {
        "sound": "order_ring.caf",
        "interruption-level": "time-sensitive"
      }
    }
  }
}
```

## ⚠️ Important Notes

### Android
- **Channel ID:** Must match `new_order_channel` in code
- **Sound name:** Must be `order_ring` (without `.mp3` extension)
- **Reinstall required:** If app was previously installed, uninstall and reinstall

### iOS
- **Sound format:** Must be `.caf` (not `.mp3`)
- **File name:** Must be exactly `order_ring.caf`
- **Silent mode:** Sound will NOT play if phone is on silent (Apple restriction)
- **Do Not Disturb:** May delay unless time-sensitive is allowed

## ✅ Expected Behavior

### Android
- 🔊 Loud custom ringtone plays
- 📳 Strong vibration
- ⚡ Immediate delivery (high priority)
- ✅ Same UI and flow (no changes)

### iOS
- 🔔 Loud custom sound plays (if not on silent)
- 📳 Vibration
- ⚡ Time-sensitive delivery
- ✅ Same UI and flow (no changes)

## 🧪 Testing

1. Add sound files to both platforms
2. Rebuild and reinstall apps
3. Place a test order as a buyer
4. Verify seller receives notification with loud sound
5. Check that UI and flow remain unchanged

## 📝 Summary

- ✅ Code updated to support custom sounds
- ⏳ **Action Required:** Add `order_ring.mp3` to Android `res/raw/`
- ⏳ **Action Required:** Add `order_ring.caf` to iOS `Runner/` and Xcode project
- ⏳ **Action Required:** Reinstall apps after adding sound files

