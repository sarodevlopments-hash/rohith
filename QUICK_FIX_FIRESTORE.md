# 🚨 QUICK FIX: Firestore Timeout Issues

## The Problem
All Firestore operations are timing out because **security rules are not published**.

## ✅ THE FIX (2 Minutes)

### Step 1: Open Firebase Console
1. Go to: https://console.firebase.google.com/project/resqfood-66b5f/firestore/rules
2. Or: Firebase Console → Your Project → Firestore Database → **Rules** tab

### Step 2: Copy These Rules
**Delete everything** in the rules editor, then paste this:

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

### Step 3: PUBLISH (CRITICAL!)
1. Click the **"Publish"** button (top right)
2. **NOT** just "Save" - you MUST click "Publish"!
3. Wait for confirmation: **"Rules published successfully"**

### Step 4: Verify
1. Look at the top of the Rules page
2. You should see: **"Last published: [recent time]"**
3. If you don't see this, rules are NOT published!

### Step 5: Test
1. Restart your Flutter app
2. Check console logs
3. You should see:
   - ✅ `User profile synced to Firestore` (instead of timeout)
   - ✅ `Loaded X orders from Firestore` (instead of timeout)
   - ✅ `Listing synced to Firestore` (instead of timeout)

---

## 🔍 How to Verify Rules Are Published

1. Go to Firebase Console → Firestore → Rules
2. Look at the **top of the page**
3. You should see: **"Last published: [date/time]"**
4. If you see "Last saved" instead of "Last published", rules are NOT published!

---

## ⚠️ Common Mistakes

❌ **Mistake 1:** Clicking "Save" instead of "Publish"
- **Fix:** Click "Publish" button

❌ **Mistake 2:** Rules saved but not published
- **Fix:** Check "Last published" timestamp

❌ **Mistake 3:** Using wrong project
- **Fix:** Verify project ID is `resqfood-66b5f`

---

## 🧪 Quick Test (After Publishing)

1. Register a new user in your app
2. Check Firebase Console → Firestore → Data tab
3. You should see:
   - `userProfiles` collection created
   - Your user document inside it

If you see this, Firestore is working! ✅

---

## 📞 Still Not Working?

If you've published rules and still see timeouts:

1. **Check Browser Console** (F12 → Console tab):
   - Look for detailed error messages
   - Share the exact error

2. **Verify Authentication**:
   - Make sure user is logged in
   - Check Firebase Console → Authentication → Users

3. **Check Network**:
   - Try different network
   - Check if firewall is blocking

4. **Try Test Mode** (temporary):
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
   ⚠️ **Less secure** - use only for testing!

---

**Most Important:** Make sure you click **"Publish"**, not just "Save"!

