# Web Notification Sound - Important Note

## ⚠️ Web Limitation

**You're testing in Chrome (web browser).** Custom notification sounds work differently on web:

### The Issue

1. **Web browsers don't support custom notification sounds** the same way Android/iOS do
2. The `RawResourceAndroidNotificationSound` is **Android-specific** and won't work on web
3. On web, the code shows a **SnackBar** (in-app notification) instead of system notification
4. Web notifications use the **browser's default sound** (if any)

### Current Behavior on Web

- ✅ Notification appears as SnackBar (in-app)
- ❌ Custom sound does NOT play (browser limitation)
- ✅ Works perfectly on Android/iOS with custom sound

## ✅ Solution for Web

To get sound on web, you have two options:

### Option 1: Use Browser's Default Notification Sound
- Request browser notification permission
- Use Web Notifications API
- Browser will use its default sound

### Option 2: Use HTML5 Audio (Recommended)
- Add sound file to `web/assets/order_ring.mp3`
- Use HTML5 Audio API to play sound when notification appears
- Works but requires user interaction first (browser security)

## 🎯 Testing Recommendation

**For testing notification sounds:**
- ✅ **Test on Android device/emulator** - custom sound will work
- ✅ **Test on iOS device** - custom sound will work  
- ⚠️ **Web (Chrome)** - custom sound won't work (browser limitation)

## 📝 Summary

- **Android/iOS:** Custom sound ✅ Works
- **Web (Chrome):** Custom sound ❌ Doesn't work (browser limitation)
- **Web:** Shows SnackBar notification ✅ Works

The implementation is correct for Android/iOS. Web browsers simply don't support custom notification sounds the same way.

