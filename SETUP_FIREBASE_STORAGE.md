# 🔥 Setup Firebase Storage for Image Uploads

## Step 1: Enable Firebase Storage

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **resqfood-66b5f**
3. Click **"Storage"** in the left sidebar
4. Click **"Get started"**
5. Choose **"Start in test mode"** (for development)
6. Select location: **asia-south1** (same as Firestore)
7. Click **"Done"**
8. Wait for Storage to initialize (30-60 seconds)

## Step 2: Configure Security Rules

1. In Firebase Console → Storage
2. Click the **"Rules"** tab
3. **Copy and paste** the rules from `storage.rules` file:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Product images: sellers can upload/delete their own images
    match /{sellerId}/listings/{listingId}/{allPaths=**} {
      allow read: if request.auth != null; // Anyone authenticated can read
      allow write: if request.auth != null && request.auth.uid == sellerId; // Only seller can write
      allow delete: if request.auth != null && request.auth.uid == sellerId; // Only seller can delete
    }
    
    // Default: deny all other access
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

4. Click **"Publish"** (NOT "Save"!)
5. Wait for "Rules published successfully"
6. Verify: Top of page shows "Last published: [time]"

## Step 3: Install Dependencies

Run in your terminal:
```bash
flutter pub get
```

This will install the `firebase_storage` package.

## Step 4: Test Image Upload

1. **Restart your app**
2. **Add a new listing** with an image
3. **Check the console** - you should see:
   ```
   ✅ Image uploaded successfully: [sellerId]/listings/[listingId]/product_[timestamp].jpg
      URL: https://firebasestorage.googleapis.com/...
   ```
4. **Check Firebase Console → Storage** - you should see uploaded images in folders

## ✅ What's Changed

### Before (❌):
- Images stored locally on device
- Lost on app reinstall
- Not accessible to other users
- No cloud backup

### After (✅):
- Images uploaded to Firebase Storage
- Stored in cloud permanently
- Accessible to all users
- Survives app reinstalls
- Fast CDN delivery

## 📁 Storage Structure

Images are organized like this:
```
{sellerId}/
  └── listings/
      └── {listingId}/
          ├── product_[timestamp].jpg (main image)
          └── colors/
              ├── red_[timestamp].jpg
              ├── blue_[timestamp].jpg
              └── ...
```

## 🔍 Verify It's Working

1. **Add a listing** with an image
2. **Check Firebase Console → Storage** - you should see the image file
3. **Check Firestore → listings collection** - `imagePath` should be a Storage URL (starts with `https://firebasestorage.googleapis.com/...`)
4. **View listing on another device** - image should load from Storage URL

## 🚨 Troubleshooting

### Images not uploading?
- Check Firebase Console → Storage is enabled
- Check Storage rules are published
- Check console for error messages
- Verify user is authenticated

### Images not displaying?
- Check `imagePath` in Firestore is a Storage URL (not local path)
- Check Storage rules allow read access
- Check network connection

### "Permission denied" errors?
- Verify Storage rules are published
- Check user is authenticated
- Verify sellerId matches authenticated user

---

**After setup, all new listings will automatically upload images to Firebase Storage!** 🎉

