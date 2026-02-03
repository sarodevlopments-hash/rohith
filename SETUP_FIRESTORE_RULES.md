# Firestore Security Rules Setup

## ✅ Database Created Successfully!

Your Firestore database is ready. Now you need to configure security rules.

## Step 1: Copy Security Rules to Firebase Console

1. Go to your Firebase Console: https://console.firebase.google.com/project/resqfood-66b5f/firestore/rules
2. Click on the **"Rules"** tab (you should see it in the top navigation)
3. **Delete** the existing default rules
4. **Copy and paste** the rules from `firestore.rules` file (or use the rules below)
5. Click **"Publish"** button

## Security Rules (Copy This):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Listings Collection
    // - Anyone authenticated can read listings (for buyers to browse)
    // - Only the seller who created it can write/update/delete
    match /listings/{listingId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && 
        request.resource.data.sellerId == request.auth.uid;
      allow update, delete: if request.auth != null && 
        resource.data.sellerId == request.auth.uid;
    }
    
    // Orders Collection
    // - Users can read their own orders (as buyer or seller)
    // - Users can create orders where they are the buyer
    // - Sellers can update orders where they are the seller
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
    
    // Default: deny all other access
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

## Step 2: Verify Setup

After publishing the rules:

1. **Restart your Flutter app**
2. **Create a test listing** in your app
3. **Check Firebase Console** → Firestore → Data tab
4. You should see:
   - ✅ A `listings` collection created automatically
   - ✅ Your listing document inside it
   - ✅ No timeout errors in console logs

## What These Rules Do:

### Listings:
- ✅ **Read**: Any authenticated user can read (buyers can browse)
- ✅ **Create**: Users can create listings with their own `sellerId`
- ✅ **Update/Delete**: Only the seller who created it can modify

### Orders:
- ✅ **Read**: Users can read orders where they are buyer OR seller
- ✅ **Create**: Users can create orders as buyers
- ✅ **Update**: Buyers or sellers can update their orders
- ✅ **Delete**: Only buyers can delete their orders

## Troubleshooting

### Still Getting Timeouts?

1. **Check Rules Published**: Make sure you clicked "Publish", not just "Save"
2. **Check Authentication**: Ensure user is logged in before creating listings
3. **Check Console Logs**: Look for specific error messages
4. **Wait 1-2 minutes**: Rules can take a moment to propagate

### Test Mode (Temporary - Development Only)

If you want to test quickly without rules, you can temporarily use:

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

⚠️ **Warning**: This is less secure. Use only for testing, then switch back to the proper rules above.

## Next Steps

Once rules are published:
1. ✅ Your app will sync listings to Firestore
2. ✅ Data will persist in the cloud
3. ✅ No more timeout errors
4. ✅ Data can be restored after app reinstall

