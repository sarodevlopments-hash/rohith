# Firestore Setup Guide

## Why Firestore Sync is Timing Out

The timeouts you're seeing (`⏱️ Firestore sync timeout`) indicate that Firestore is either:
1. Not enabled in Firebase Console
2. Security rules are blocking access
3. Network connectivity issues

## Step-by-Step Setup

### 1. Enable Firestore Database

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **resqfood-66b5f**
3. Click on **"Firestore Database"** in the left sidebar
4. If you see "Create database" button, click it
5. Choose **"Start in test mode"** (for development) or **"Production mode"** (requires security rules)
6. Select a location (choose closest to your users, e.g., `us-central1` or `asia-south1` for India)
7. Click **"Enable"**

### 2. Configure Security Rules

1. In Firestore Database, click on the **"Rules"** tab
2. Replace the default rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Listings: Users can read all, but only write their own
    match /listings/{listingId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && 
        request.resource.data.sellerId == request.auth.uid;
      allow update, delete: if request.auth != null && 
        resource.data.sellerId == request.auth.uid;
    }
    
    // Orders: Users can read/write their own orders
    match /orders/{orderId} {
      allow read: if request.auth != null && 
        (resource.data.userId == request.auth.uid || 
         resource.data.sellerId == request.auth.uid);
      allow create: if request.auth != null && 
        (request.resource.data.userId == request.auth.uid || 
         request.resource.data.sellerId == request.auth.uid);
      allow update: if request.auth != null && 
        (resource.data.userId == request.auth.uid || 
         resource.data.sellerId == request.auth.uid);
    }
  }
}
```

3. Click **"Publish"** to save the rules

### 3. Verify Collections

1. Go to the **"Data"** tab in Firestore
2. The collections `listings` and `orders` will be created automatically when data is written
3. You don't need to create them manually

### 4. Test Connection

After setting up, restart your app. You should see:
- ✅ `Listing synced to Firestore: [listingId]` instead of timeouts
- ✅ `Firestore sync complete: X restored` instead of timeout errors

## Troubleshooting

### Still Getting Timeouts?

1. **Check Authentication**: Make sure users are logged in before sync runs
2. **Check Network**: Ensure device has internet connection
3. **Check Rules**: Verify security rules are published (not just saved)
4. **Check Console**: Look for errors in Firebase Console > Firestore > Usage tab

### For Development/Testing

If you want to allow all access temporarily (NOT for production):

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

⚠️ **Warning**: This allows any authenticated user to read/write all data. Use only for testing!

## What Happens After Setup

- ✅ Listings will sync to Firestore automatically
- ✅ Data will persist even if app is uninstalled
- ✅ Data can be restored on new devices
- ✅ Real-time sync across devices

## Current Status

Your app is configured correctly. The only missing piece is enabling Firestore in Firebase Console and setting up security rules.

