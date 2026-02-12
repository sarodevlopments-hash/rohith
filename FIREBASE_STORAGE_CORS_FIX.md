# Firebase Storage CORS Configuration Fix

## Problem
Document uploads are failing with CORS error when accessing Firebase Storage from localhost.

## Solution

### 1. Install Google Cloud SDK
Download and install from: https://cloud.google.com/sdk/docs/install

### 2. Authenticate with Google Cloud
```bash
gcloud auth login
```

### 3. Set your Firebase project
```bash
gcloud config set project resqfood-66b5f
```

### 4. Apply CORS configuration
```bash
gsutil cors set cors.json gs://resqfood-66b5f.firebasestorage.app
```

### 5. Verify CORS configuration
```bash
gsutil cors get gs://resqfood-66b5f.firebasestorage.app
```

## Alternative: Use Firebase Console

If you prefer not to use command line:

1. Go to: https://console.firebase.google.com/project/resqfood-66b5f/storage
2. Click on the "Rules" tab
3. Add these rules:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow authenticated users to upload documents
    match /{sellerId}/documents/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == sellerId;
    }
    
    // Allow authenticated users to upload listing images
    match /{sellerId}/listings/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == sellerId;
    }
  }
}
```

## Testing
After applying CORS configuration:
1. Restart your Flutter app
2. Try uploading a document again
3. The upload should now work without CORS errors

## Note
- CORS configuration allows requests from any origin (`*`)
- For production, you may want to restrict this to your actual domain
- The configuration persists until you change it

