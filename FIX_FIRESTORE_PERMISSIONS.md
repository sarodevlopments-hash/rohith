# 🔧 Fix Firestore Permission Errors - Step by Step

## The Problem
You're getting `[cloud_firestore/permission-denied] Missing or insufficient permissions` errors.

## ✅ Solution Steps

### Step 1: Verify Your User Profile Has Owner Role

1. **Get your Firebase Auth UID:**
   - Open browser console (F12)
   - Run: `firebase.auth().currentUser.uid` (if logged in)
   - Or check the login screen - it should show your UID after login

2. **Go to Firestore Console:**
   - https://console.firebase.google.com/project/resqfood-66b5f/firestore/data
   - Navigate to `userProfiles` collection
   - Find your user document (by your UID)

3. **Add/Update the `role` field:**
   ```json
   {
     "role": "owner"  // Must be exactly "owner" (lowercase string)
   }
   ```

### Step 2: Update Firestore Rules

1. **Go to Firestore Rules:**
   - https://console.firebase.google.com/project/resqfood-66b5f/firestore/rules

2. **Copy the ENTIRE content from `firestore.rules` file** (in your project)

3. **Paste it into Firebase Console**

4. **Click "PUBLISH"** (not just Save!)
   - Wait for "Rules published successfully" message
   - Rules take 1-2 minutes to propagate

### Step 3: Verify Database ID

The code uses `databaseId: 'reqfood'`. Make sure:
- Your Firestore database name matches
- Or update the code to match your actual database name

### Step 4: Test Access

1. **Refresh the dashboard** (Ctrl+R or F5)
2. **Check browser console** (F12 → Console tab)
3. **Look for:**
   - ✅ `DEBUG: Found X users...` messages = Success!
   - ❌ `permission-denied` errors = Rules not published or role not set

## 🚨 Temporary Test Rule (If Still Not Working)

If you want to test if rules are the issue, temporarily use this (ONLY FOR TESTING):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // TEMPORARY: Allow all reads for authenticated users
    // REMOVE THIS AFTER TESTING!
    match /{document=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

**⚠️ WARNING:** This is insecure! Only use to test, then switch back to proper rules.

## 📋 Checklist

- [ ] User profile has `role: "owner"` field in Firestore
- [ ] Firestore rules have been PUBLISHED (not just saved)
- [ ] Database ID matches (`reqfood`)
- [ ] User is logged in with the correct account
- [ ] Browser cache cleared (Ctrl+Shift+Delete)

## 🔍 Debugging

If still not working, check:

1. **Browser Console Errors:**
   - Look for specific permission errors
   - Check which collection is failing

2. **Firebase Console → Firestore → Rules:**
   - Verify rules are published
   - Check for syntax errors (red indicators)

3. **Firebase Console → Authentication:**
   - Verify user is authenticated
   - Check user UID matches Firestore document ID

4. **Firebase Console → Firestore → Data:**
   - Verify `userProfiles/{your-uid}` exists
   - Verify `role` field is set to `"owner"` (string, not boolean)

