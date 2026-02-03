# 🚨 ACTION REQUIRED: Publish Firestore Security Rules

## Current Status: ❌ NOT FIXED YET

The error `[cloud_firestore/unavailable] Failed to get document because the client is offline` means **Firestore security rules are not published**.

## ✅ DO THIS NOW (5 Minutes)

### Step 1: Open Firebase Console Rules
**Click this link:** https://console.firebase.google.com/project/resqfood-66b5f/firestore/rules

Or manually:
1. Go to https://console.firebase.google.com/
2. Select project: **resqfood-66b5f**
3. Click **"Firestore Database"** in left sidebar
4. Click **"Security"** tab (or "Rules" tab)

### Step 2: Copy Rules
Open the file `firestore.rules` in your project, or copy from `COPY_THIS_TO_FIRESTORE_RULES.txt`

**Or copy this:**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /listings/{listingId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && 
        request.resource.data.sellerId == request.auth.uid;
      allow update, delete: if request.auth != null && 
        resource.data.sellerId == request.auth.uid;
    }
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
    match /userProfiles/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### Step 3: Paste and Publish
1. **Delete** all existing rules in the Firebase Console editor
2. **Paste** the rules above
3. **Click "Publish"** button (top right, blue button)
   - ⚠️ **NOT "Save"** - you MUST click "Publish"!
4. Wait for: **"Rules published successfully"** message

### Step 4: Verify Rules Are Published
1. Look at the **top of the Rules page**
2. You should see: **"Last published: [date/time]"**
3. If you see "Last saved" instead → Rules are NOT published!

### Step 5: Test Your App
1. **Restart your Flutter app** (close and reopen)
2. **Register/Login** a user
3. **Check console logs** - you should see:
   - ✅ `User profile synced to Firestore: [userId]`
   - ✅ `Loaded X orders from Firestore`
   - ✅ `Listing synced to Firestore: [listingId]`
   - ❌ **NO MORE** timeout errors!

### Step 6: Verify in Firebase Console
1. Go to Firebase Console → Firestore → **Data** tab
2. After registering a user, you should see:
   - `userProfiles` collection created
   - Your user document inside it
3. After creating a listing, you should see:
   - `listings` collection created
   - Your listing document inside it

---

## ✅ Success Indicators

When it's working, you'll see:
- ✅ No timeout errors in console
- ✅ `✅ User profile synced to Firestore`
- ✅ `✅ Listing synced to Firestore`
- ✅ `✅ Loaded X orders from Firestore`
- ✅ Data appears in Firebase Console → Firestore → Data tab
- ✅ Registration persists after app restart
- ✅ Orders persist after app restart
- ✅ Listings persist after app restart

---

## ❌ If Still Not Working

If you've published rules and still see timeouts:

1. **Double-check "Last published" timestamp** in Rules tab
2. **Check Browser Console** (F12) for detailed errors
3. **Verify you're logged in** (Firebase Auth)
4. **Try different network** (in case of firewall)
5. **Check Firebase Console → Firestore → Usage** for errors

---

## 📝 Quick Checklist

- [ ] Opened Firebase Console → Firestore → Rules
- [ ] Deleted old rules
- [ ] Pasted new rules
- [ ] Clicked "Publish" (not just Save)
- [ ] Saw "Rules published successfully"
- [ ] Verified "Last published: [date]" appears
- [ ] Restarted Flutter app
- [ ] Tested registration/login
- [ ] Checked console logs for ✅ messages
- [ ] Verified data in Firebase Console → Data tab

---

**Once you complete these steps, your data will persist!** 🎉

