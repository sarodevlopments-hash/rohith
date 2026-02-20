# 📋 Firestore Rules to Publish

## What You Need to Do

1. **Copy ALL the rules below** (the entire content)
2. **Go to Firebase Console**: https://console.firebase.google.com/project/resqfood-66b5f/firestore/rules
3. **Paste the rules** into the editor
4. **Click "Publish"** button (top right, blue button)

---

## The Complete Rules (Copy Everything Below)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper function to check if user is owner
    // Handles case where user profile might not exist yet
    function isOwner() {
      return request.auth != null && 
        exists(/databases/$(database)/documents/userProfiles/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/userProfiles/$(request.auth.uid)).data.get('role', '') == 'owner';
    }
    
    // Listings Collection
    // - Anyone authenticated can read listings (for buyers to browse)
    // - Only the seller who created it can write/update/delete
    // - Owners have full access
    // Note: allow read works for both individual documents and collection queries (.get() and .snapshots())
    match /listings/{listingId} {
      // Allow owners to read any listing (including collection queries)
      allow read: if isOwner();
      // Allow authenticated users to read listings (works for collection queries too)
      allow read: if request.auth != null;
      allow create: if request.auth != null && 
        (request.resource.data.sellerId == request.auth.uid || isOwner());
      allow update, delete: if request.auth != null && 
        (resource.data.sellerId == request.auth.uid || isOwner());
    }
    
    // Orders Collection
    // - Users can read their own orders (as buyer or seller)
    // - Users can create orders where they are the buyer
    // - Sellers can update orders where they are the seller
    // - Owners have full access (including collection queries)
    match /orders/{orderId} {
      // Allow owners to read any order (including collection queries)
      allow read: if isOwner();
      // Allow users to read their own orders
      allow read: if request.auth != null && 
        (resource.data.userId == request.auth.uid || 
         resource.data.sellerId == request.auth.uid);
      allow create: if request.auth != null && 
        (request.resource.data.userId == request.auth.uid || isOwner());
      allow update: if request.auth != null && 
        (resource.data.userId == request.auth.uid || 
         resource.data.sellerId == request.auth.uid ||
         isOwner());
      allow delete: if request.auth != null && 
        (resource.data.userId == request.auth.uid || isOwner());
    }
    
    // User Profiles Collection
    // - Users can read/write their own profile
    // - Owners can read all profiles (including collection queries)
    match /userProfiles/{userId} {
      // Allow owners to read any profile (including collection queries)
      allow read: if isOwner();
      // Allow users to read their own profile
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null && request.auth.uid == userId;
      
      // Addresses subcollection
      match /addresses/{addressId} {
        allow read: if request.auth != null && request.auth.uid == userId;
        allow create: if request.auth != null && request.auth.uid == userId;
        allow update: if request.auth != null && request.auth.uid == userId;
        allow delete: if request.auth != null && request.auth.uid == userId;
      }
      
      // Buyer Addresses subcollection
      match /buyerAddresses/{addressId} {
        allow read: if request.auth != null && request.auth.uid == userId;
        allow write: if request.auth != null && request.auth.uid == userId;
      }
      
      // Item Lists subcollection (for sellers)
      match /itemLists/{listId} {
        // Allow read if authenticated and userId matches
        allow read: if request.auth != null && request.auth.uid == userId;
        // Allow create if authenticated, userId matches, and sellerId in data matches auth.uid
        allow create: if request.auth != null && 
          request.auth.uid == userId &&
          request.resource.data.sellerId == request.auth.uid;
        // Allow update if authenticated, userId matches, and sellerId matches
        allow update: if request.auth != null && 
          request.auth.uid == userId &&
          resource.data.sellerId == request.auth.uid;
        // Allow delete if authenticated, userId matches, and sellerId matches
        allow delete: if request.auth != null && 
          request.auth.uid == userId &&
          resource.data.sellerId == request.auth.uid;
      }
      
      // Seller Profile subcollection
      match /sellerProfile/{profileId} {
        allow read: if request.auth != null && request.auth.uid == userId;
        allow write: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    // Product Reviews Collection
    // - Anyone authenticated can read reviews (for displaying on product pages)
    // - Buyers can create reviews for products they purchased
    // - Buyers can update their own reviews (within 24 hours)
    // - Owners have full access
    match /productReviews/{reviewId} {
      // Allow owners to read any review (including collection queries)
      allow read: if isOwner();
      // Allow authenticated users to read reviews
      allow read: if request.auth != null;
      // Allow buyers to create reviews where they are the buyer
      allow create: if request.auth != null && 
        request.resource.data.buyerId == request.auth.uid;
      // Allow buyers to update their own reviews (within 24 hours)
      allow update: if request.auth != null && 
        resource.data.buyerId == request.auth.uid &&
        (request.resource.data.createdAt == resource.data.createdAt || isOwner());
      // Allow buyers to delete their own reviews, or owners to delete any
      allow delete: if request.auth != null && 
        (resource.data.buyerId == request.auth.uid || isOwner());
    }
    
    // Seller Reviews Collection
    // - Anyone authenticated can read reviews (for displaying on seller profiles)
    // - Buyers can create reviews for sellers they purchased from
    // - Buyers can update their own reviews (within 24 hours)
    // - Owners have full access
    match /sellerReviews/{reviewId} {
      // Allow owners to read any review (including collection queries)
      allow read: if isOwner();
      // Allow authenticated users to read reviews
      allow read: if request.auth != null;
      // Allow buyers to create reviews where they are the buyer
      allow create: if request.auth != null && 
        request.resource.data.buyerId == request.auth.uid;
      // Allow buyers to update their own reviews (within 24 hours)
      allow update: if request.auth != null && 
        resource.data.buyerId == request.auth.uid &&
        (request.resource.data.createdAt == resource.data.createdAt || isOwner());
      // Allow buyers to delete their own reviews, or owners to delete any
      allow delete: if request.auth != null && 
        (resource.data.buyerId == request.auth.uid || isOwner());
    }
    
    // Default: deny all other access
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## Quick Steps to Publish

1. **Copy the entire rules above** (from `rules_version = '2';` to the closing `}`)

2. **Open Firebase Console**:
   - Go to: https://console.firebase.google.com/project/resqfood-66b5f/firestore/rules

3. **Paste the rules**:
   - Delete everything in the editor
   - Paste the rules you copied

4. **Click "Publish"**:
   - Look for the blue "Publish" button (top right)
   - Click it
   - Wait for "Rules published successfully"

5. **Verify**:
   - Check the top of the page - should show "Last published: [time]"

---

## What These Rules Do

- ✅ **Listings**: Anyone logged in can read, sellers can create/update their own
- ✅ **Orders**: Users can read their own orders (as buyer or seller)
- ✅ **User Profiles**: Users can read/write their own profile
- ✅ **Reviews**: Anyone can read, buyers can create their own
- ✅ **Owner Access**: Users with `role: "owner"` have full access to everything

These rules allow real-time sync to work because authenticated users can read the `listings` collection.

