# 🔍 Verify Firestore Rules Include itemLists

## Quick Check

In Firebase Console → Firestore → Rules, scroll down and verify you see this section:

```javascript
// Item Lists subcollection (for sellers)
match /itemLists/{listId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow create: if request.auth != null && request.auth.uid == userId &&
    request.resource.data.sellerId == request.auth.uid;
  allow update: if request.auth != null && request.auth.uid == userId &&
    resource.data.sellerId == request.auth.uid;
  allow delete: if request.auth != null && request.auth.uid == userId &&
    resource.data.sellerId == request.auth.uid;
}
```

## If You DON'T See This Section:

1. **Copy the ENTIRE `firestore.rules` file** (all 71 lines)
2. **Paste into Firebase Console Rules editor**
3. **Click "Publish"** (not just Save)
4. **Wait 2-3 minutes** for propagation
5. **Restart your Flutter app**

## If You DO See This Section But Still Getting Timeout:

1. **Check the "Last published" timestamp** - should be very recent (within last few minutes)
2. **Wait 2-3 minutes** after publishing (rules can take time to propagate globally)
3. **Restart your Flutter app** completely (not just hot reload)
4. **Check console logs** - the improved error handling will now show the actual Firestore error code

## Test the Rules:

After publishing, try saving an item list again. The console will now show:
- The actual Firestore error code (if it's a permission issue)
- More detailed debugging information
- Specific guidance based on the error type

