# 🔍 Test Firestore Write Access

## Current Issue
The save operation is timing out, which suggests Firestore rules might not be matching correctly.

## Quick Test

Before trying to save item lists, let's verify Firestore is accessible:

### Option 1: Check Rules in Firebase Console

1. Go to: https://console.firebase.google.com/project/resqfood-66b5f/firestore/rules
2. **Verify the rules are actually published:**
   - Look at the "Last published" timestamp at the top
   - It should show a recent time (within last few minutes)
   - If it shows an old date, the rules weren't published!

3. **Scroll down and verify you see:**
   ```javascript
   match /userProfiles/{userId} {
     // ... other subcollections ...
     
     // Item Lists subcollection (for sellers)
     match /itemLists/{listId} {
       allow read: if request.auth != null && request.auth.uid == userId;
       allow create: if request.auth != null && 
         request.auth.uid == userId &&
         request.resource.data.sellerId == request.auth.uid;
       // ... rest
     }
   }
   ```

### Option 2: Temporary Test Rules

If you want to test quickly, temporarily use these simplified rules (FOR TESTING ONLY):

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
      
      match /addresses/{addressId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /buyerAddresses/{addressId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      // TEMPORARY: Simplified itemLists rules for testing
      match /itemLists/{listId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

**⚠️ WARNING:** These simplified rules are less secure - only use for testing!

After confirming it works, switch back to the full rules with sellerId validation.

