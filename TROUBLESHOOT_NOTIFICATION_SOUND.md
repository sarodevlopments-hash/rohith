# Troubleshooting: Notification Sound Not Playing

## Problem
You've added the sound file (`order_ring.mp3`) but notifications are playing without sound.

## Root Cause
Android notification channels **cannot be modified** after they're created. If the channel was created before you added the sound file, it won't use the custom sound.

## ✅ Solution Applied

I've updated the code to:
1. **Changed channel ID** from `new_order_channel` to `new_order_channel_v2` to force recreation
2. **Added code to delete old channels** automatically
3. **Added debug logging** to verify channel creation

## 🔧 Steps to Fix

### Option 1: Reinstall App (Recommended)
1. **Uninstall the app** completely from your device
2. **Rebuild and reinstall** the app
3. The new channel will be created with the custom sound

### Option 2: Clear App Data
1. Go to **Settings** → **Apps** → Your App
2. Tap **Storage** → **Clear Data**
3. Restart the app
4. The channel will be recreated with the custom sound

### Option 3: Manual Channel Deletion (Advanced)
1. Go to **Settings** → **Apps** → Your App → **Notifications**
2. Find "New Order Alerts" or "New Orders" channel
3. Delete the channel
4. Restart the app

## ✅ Verification Steps

After reinstalling/clearing data:

1. **Check the sound file exists:**
   ```
   android/app/src/main/res/raw/order_ring.mp3
   ```

2. **Verify file name:**
   - Must be exactly: `order_ring.mp3` (lowercase, no spaces)
   - Must be in: `android/app/src/main/res/raw/`

3. **Check device volume:**
   - Ensure device volume is not muted
   - Check notification volume in Settings

4. **Test notification:**
   - Place a test order
   - Verify sound plays

5. **Check logs:**
   - Look for: `[NotificationService] Created notification channel: new_order_channel_v2 with custom sound: order_ring`

## 🐛 Common Issues

### Issue: Still no sound after reinstall
**Solution:**
- Verify the MP3 file is valid (try playing it on your computer)
- Check file size (should be under 500KB)
- Ensure file name is exactly `order_ring.mp3` (case-sensitive)

### Issue: Sound plays but is quiet
**Solution:**
- The sound file itself may be quiet
- Use a louder ringtone file
- Check device notification volume settings

### Issue: Sound plays but notification doesn't show
**Solution:**
- Check notification permissions in app settings
- Verify channel importance is set to `Importance.max` (already configured)

## 📝 Code Changes Made

1. **Channel ID updated:**
   ```dart
   static const String _channelId = 'new_order_channel_v2';
   ```

2. **Old channel deletion added:**
   ```dart
   await androidPlugin.deleteNotificationChannel('new_order_channel');
   await androidPlugin.deleteNotificationChannel('new_orders_channel');
   ```

3. **Debug logging added:**
   ```dart
   debugPrint('[NotificationService] Created notification channel: $_channelId with custom sound: order_ring');
   ```

## ✅ Expected Result

After following the steps above:
- 🔊 Loud custom ringtone plays when new order arrives
- 📳 Strong vibration
- ⚡ Immediate delivery
- ✅ Same UI and flow (no changes)

## 📞 Still Not Working?

If sound still doesn't play after reinstalling:

1. **Check Android version:** Custom sounds work on Android 8.0+ (API 26+)
2. **Verify file format:** Must be MP3, not WAV or other formats
3. **Check file location:** Must be in `res/raw/` not `res/drawable/`
4. **Test with default sound:** Temporarily remove `sound:` parameter to verify notifications work
5. **Check device settings:** Some devices have "Do Not Disturb" modes that suppress sounds

