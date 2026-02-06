# 🔍 Test Firestore Rules

## Quick Test

The timeout suggests the rules might not be matching. Let's verify:

### Step 1: Check Rules in Firebase Console

1. Go to: https://console.firebase.google.com/project/resqfood-66b5f/firestore/rules
2. Scroll down to find the `itemLists` section
3. It should look like this:

```javascript
match /userProfiles/{userId} {
  // ... other subcollections ...
  
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
}
```

### Step 2: If Rules Are Missing

Copy the ENTIRE `firestore.rules` file and paste into Firebase Console, then click **"Publish"**.

### Step 3: Temporary Test - Simplified Rules

If you want to test quickly, temporarily use these simpler rules (for testing only):

```javascript
match /userProfiles/{userId} {
  match /itemLists/{listId} {
    // TEMPORARY: Allow all for testing
    allow read, write: if request.auth != null && request.auth.uid == userId;
  }
}
```

**⚠️ WARNING:** These are less secure - only use for testing, then switch back to the full rules.

### Step 4: Verify Rules Are Published

After publishing:
1. Check the "Last published" timestamp
2. Wait 2-3 minutes
3. Restart your Flutter app
4. Try saving again

