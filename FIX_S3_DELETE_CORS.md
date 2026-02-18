# 🔧 Fix S3 DELETE CORS Error

## Issue
When deleting images from S3, you're getting this error:
```
Access to fetch at 'https://reqfood.s3.us-east-1.amazonaws.com/...' from origin 'http://localhost:50603' has been blocked by CORS policy: Response to preflight request doesn't pass access control check: No 'Access-Control-Allow-Origin' header is present on the requested resource.
```

## Solution: Update S3 CORS Configuration

The CORS configuration needs to include the **DELETE** method.

### Steps:

1. Go to **AWS S3 Console** → **`reqfood` bucket**
2. Click **"Permissions"** tab
3. Scroll to **"Cross-origin resource sharing (CORS)"**
4. Click **"Edit"**
5. Replace the entire CORS configuration with this (includes DELETE):

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
      "POST",
      "DELETE"
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

6. Click **"Save changes"**

## Important Notes:

- **DO NOT** include `OPTIONS` in `AllowedMethods` - S3 handles preflight requests automatically
- The `DELETE` method is now included, which allows deletion requests from your web app
- `AllowedOrigins: ["*"]` allows requests from any origin (you can restrict this to specific domains in production)

## After Updating:

1. **Restart your app** (hot restart or full restart)
2. Try deleting an item again
3. The DELETE request should now work without CORS errors

## Verification:

After updating CORS, check the browser console. You should see:
- ✅ `S3 DELETE Response: Status: 204` (success)
- ✅ `Image deleted successfully from S3`

Instead of:
- ❌ CORS policy errors
- ❌ `net::ERR_FAILED`

