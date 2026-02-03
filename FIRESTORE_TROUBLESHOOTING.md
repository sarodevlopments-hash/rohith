# Firestore Troubleshooting Guide

## 🔴 Current Issue: All Firestore Operations Timing Out

Based on your logs, all Firestore operations are timing out:
- `⏱️ Firestore user fetch timeout`
- `⏱️ Firestore order load timeout`
- `⏱️ Firestore sync timeout`

This indicates **Firestore is not accessible**. Here's how to fix it:

---

## ✅ Step-by-Step Fix

### Step 1: Verify Firestore is Enabled

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **resqfood-66b5f**
3. Click **"Firestore Database"** in the left sidebar
4. You should see your database with location **asia-south1**
5. If you see "Create database" instead, click it and enable Firestore

### Step 2: Publish Security Rules (CRITICAL!)

**This is the most common cause of timeouts!**

1. In Firebase Console → Firestore Database
2. Click the **"Rules"** tab (top navigation)
3. You should see the rules editor
4. **Copy and paste these rules:**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Listings Collection
    match /listings/{listingId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && 
        request.resource.data.sellerId == request.auth.uid;
      allow update, delete: if request.auth != null && 
        resource.data.sellerId == request.auth.uid;
    }
    
    // Orders Collection
    match /orders/{orderId} {
      allow read: if request.auth != null && 
        (resource.data.userId == request.auth.uid || 
         resource.data.sellerId == request.auth.uid);
      allow create: if request.auth != null && 
        request.resource.data.userId == request.auth.uid;
      allow update: if request.auth != null && 
        (resource.data.userId == request.auth.uid || 
         resource.data.sellerId == request.auth.uid);
      allow delete: if request.auth != null && 
        resource.data.userId == request.auth.uid;
    }
    
    // User Profiles Collection
    match /userProfiles/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Default: deny all other access
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

5. **Click "Publish"** (NOT just "Save" - you must click Publish!)
6. Wait for confirmation: "Rules published successfully"

### Step 3: Verify Rules are Published

1. After publishing, refresh the Rules tab
2. You should see your rules displayed
3. Check the timestamp at the top - it should show "Last published: [recent time]"

### Step 4: Test Connection

1. Restart your Flutter app
2. Check the console logs
3. You should see:
   - ✅ `User profile synced to Firestore: [userId]` (instead of timeout)
   - ✅ `Loaded X orders from Firestore` (instead of timeout)
   - ✅ `Listing synced to Firestore: [listingId]` (instead of timeout)

---

## 🔍 Common Issues

### Issue 1: Rules Not Published
**Symptom:** All operations timeout
**Solution:** Make sure you clicked "Publish", not just "Save"

### Issue 2: Wrong Project
**Symptom:** Timeouts or permission errors
**Solution:** Verify `firebase_options.dart` has correct `projectId: 'resqfood-66b5f'`

### Issue 3: Network/Firewall
**Symptom:** Timeouts on specific networks
**Solution:** 
- Check internet connection
- Try different network
- Check if firewall is blocking Firestore

### Issue 4: Firestore Not Enabled
**Symptom:** "Collection not found" or timeouts
**Solution:** Enable Firestore in Firebase Console

---

## 🧪 Quick Test

To verify Firestore is working, try this in Firebase Console:

1. Go to Firestore → Data tab
2. Click "+ Add collection"
3. Collection ID: `_test`
4. Document ID: `test1`
5. Add a field: `test` (string) = `"hello"`
6. Click "Save"

If this works, Firestore is enabled. The issue is likely security rules.

---

## 📝 Verification Checklist

- [ ] Firestore Database is enabled in Firebase Console
- [ ] Security rules are published (not just saved)
- [ ] Rules include `listings`, `orders`, and `userProfiles` collections
- [ ] User is authenticated (logged in)
- [ ] Internet connection is working
- [ ] `firebase_options.dart` has correct project ID

---

## 🚨 If Still Not Working

If you've completed all steps and still see timeouts:

1. **Check Browser Console** (for web):
   - Open DevTools (F12)
   - Check Console tab for detailed errors
   - Look for CORS or permission errors

2. **Check Firebase Console → Firestore → Usage**:
   - See if there are any errors or blocked requests
   - Check if requests are being made

3. **Try Test Mode Rules** (temporary, for testing only):
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```
   ⚠️ **Warning:** This is less secure. Use only for testing, then switch back to proper rules.

---

## ✅ Success Indicators

When everything is working, you'll see:
- ✅ No timeout errors
- ✅ `✅ User profile synced to Firestore`
- ✅ `✅ Listing synced to Firestore`
- ✅ `✅ Loaded X orders from Firestore`
- ✅ Data appears in Firebase Console → Firestore → Data tab

---

**Most likely issue:** Security rules are not published. Make sure you click "Publish" after editing rules!

