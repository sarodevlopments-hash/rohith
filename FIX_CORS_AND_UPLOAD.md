# 🔧 Fix CORS and Upload Issues

## Issue 1: CORS Configuration Missing OPTIONS Method

Your CORS is configured but missing the **OPTIONS** method which is needed for preflight requests.

### Fix CORS Configuration:

1. Go to **S3 Console** → **`reqfood` bucket** → **Permissions** tab
2. Scroll to **"Cross-origin resource sharing (CORS)"**
3. Click **"Edit"**
4. Replace with this (adds OPTIONS method):

```json
[
  {
    "AllowedHeaders": [
      "*"
    ],
    "AllowedMethods": [
      "GET",
      "HEAD",
      "PUT",
      "POST"
    ],
    "AllowedOrigins": [
      "*"
    ],
    "ExposeHeaders": [
      "ETag",
      "x-amz-request-id",
      "x-amz-id-2"
    ],
    "MaxAgeSeconds": 3000
  }
]
```

**Important Notes:**
- ❌ **DO NOT include "OPTIONS"** - S3 handles preflight OPTIONS requests automatically
- ✅ S3 will automatically respond to OPTIONS preflight requests based on your CORS config
- ✅ Added more headers to `ExposeHeaders` for better compatibility

5. Click **"Save changes"**

## Issue 2: Uploads Failing (Bucket Empty)

The bucket is empty, which means uploads are failing silently. Let's add better error handling and fix the upload.

### Check Upload Errors:

The upload might be failing due to:
1. **Signature calculation error**
2. **Content-Type mismatch**
3. **IAM permissions issue**
4. **Network/CORS blocking the PUT request**

### Add Debug Logging:

I've fixed a bug where `contentType` was being overridden. Now let's verify uploads work.

### Test Upload:

1. **Restart your Flutter app**
2. **Try uploading a document again**
3. **Check console for**:
   ```
   ✅ Document uploaded to S3: [path]
      URL: https://reqfood.s3.us-east-1.amazonaws.com/...
   ```
   OR
   ```
   ❌ S3 upload failed: [status code] - [error message]
   ```

## Issue 3: Verify IAM Permissions

Check that your IAM user has the correct permissions:

1. Go to **IAM Console** → **Users** → **`reqfooduser`**
2. **Permissions** tab → Check attached policies
3. Should have policy with:
   ```json
   {
     "Effect": "Allow",
     "Action": [
       "s3:PutObject",
       "s3:PutObjectAcl"
     ],
     "Resource": "arn:aws:s3:::reqfood/*"
   }
   ```

## Quick Test Steps:

1. ✅ **Fix CORS** (add OPTIONS method) - See Issue 1 above
2. ✅ **Restart app** after CORS fix
3. ✅ **Try uploading again**
4. ✅ **Check console logs** for upload success/failure
5. ✅ **Check S3 bucket** - files should appear

## If Upload Still Fails:

Check console for these errors:

- **403 Forbidden** → IAM permissions issue
- **400 Bad Request** → Signature or content-type issue
- **CORS error** → CORS not configured correctly
- **Network error** → Connection issue

## Alternative: Use Backend API (Recommended)

Since direct upload from web is complex due to CORS, consider using a backend API:

1. **Deploy backend API** (see `BACKEND_API_EXAMPLE.md`)
2. **Backend generates presigned URLs**
3. **App uploads using presigned URL**
4. **No CORS issues** (presigned URLs handle it)

This is the recommended approach for production!

