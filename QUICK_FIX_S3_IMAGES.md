# 🚀 Quick Fix: S3 Images Not Displaying

## Most Common Issues & Quick Fixes

### Issue 1: S3 Bucket Not Public (Most Common!)

**Symptom**: Images show broken icon, 403 Forbidden error

**Quick Fix**:

1. Go to **AWS S3 Console** → **`reqfood` bucket**
2. **Permissions** tab → **Block public access** → Click **"Edit"**
3. **Uncheck all 4 boxes** → Click **"Save changes"**
4. **Bucket policy** → Click **"Edit"** → Paste this:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::reqfood/*"
    }
  ]
}
```

5. Click **"Save changes"**

### Issue 2: CORS Not Configured

**Symptom**: CORS error in browser console

**Quick Fix**:

1. **S3 Console** → **`reqfood` bucket** → **Permissions** tab
2. Scroll to **"Cross-origin resource sharing (CORS)"**
3. Click **"Edit"** → Paste this:

```json
[
  {
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET", "HEAD", "PUT", "POST"],
    "AllowedOrigins": ["*"],
    "ExposeHeaders": ["ETag", "x-amz-request-id", "x-amz-id-2"],
    "MaxAgeSeconds": 3000
  }
]
```

**⚠️ Important**: Do NOT include "OPTIONS" in AllowedMethods - S3 handles preflight requests automatically!

4. Click **"Save changes"**

### Issue 3: Old Listings Have Wrong URLs

**Symptom**: New uploads work, old listings show broken images

**Quick Fix**:

Old listings might have:
- Local file paths (not S3 URLs)
- Firebase Storage URLs (not S3)

**Solution**: Re-upload images for those listings OR check Firestore:

1. Go to **Firestore Console** → **`listings` collection**
2. Find a listing with broken image
3. Check `imagePath` field:
   - ✅ Should be: `https://reqfood.s3.us-east-1.amazonaws.com/...`
   - ❌ NOT: `/path/to/local/file.jpg`
   - ❌ NOT: `https://firebasestorage.googleapis.com/...`

### Issue 4: URL Not Recognized

**Symptom**: Image shows local file placeholder instead of loading

**Quick Fix**:

Check if URL format is correct:
- ✅ `https://reqfood.s3.us-east-1.amazonaws.com/...`
- ✅ `https://reqfood.s3.amazonaws.com/...`
- ❌ `reqfood.s3.us-east-1.amazonaws.com/...` (missing https://)

## Step-by-Step Verification

### 1. Check Image Uploaded Successfully

1. Go to **S3 Console** → **`reqfood` bucket**
2. Look for folder: `[sellerId]/listings/[listingId]/`
3. Should see file: `product_[timestamp].jpg`
4. Click file → Check **"Object URL"**
5. Copy URL → Paste in browser
6. **If image loads in browser** → Bucket is public ✅
7. **If 403 error** → Fix bucket permissions (Issue 1)

### 2. Check Firestore Has Correct URL

1. Go to **Firestore Console** → **`listings` collection**
2. Find your listing (e.g., "Biryani-aws")
3. Check `imagePath` field
4. Should be full S3 URL: `https://reqfood.s3.us-east-1.amazonaws.com/...`
5. **If wrong format** → Re-upload the image

### 3. Check Flutter App Logs

When app loads, check console for:
```
🔍 Image URL: https://reqfood.s3.us-east-1.amazonaws.com/...
🔍 Is Storage URL: true
```

If `Is Storage URL: false` → URL format issue

### 4. Test Direct URL

1. Get S3 Object URL from S3 Console
2. Temporarily hardcode in widget:
   ```dart
   imageUrl: 'https://reqfood.s3.us-east-1.amazonaws.com/[actual-path]'
   ```
3. **If works** → URL format OK, check permissions
4. **If doesn't work** → Bucket permissions issue

## Most Likely Fix

**90% of the time, it's bucket permissions!**

1. ✅ Make bucket public (Issue 1)
2. ✅ Add bucket policy (Issue 1)
3. ✅ Configure CORS (Issue 2)
4. ✅ Restart app
5. ✅ Test again

## Still Not Working?

Check these in order:

1. **S3 bucket exists**: `reqfood` in `us-east-1`
2. **Image uploaded**: Check S3 bucket has the file
3. **URL correct**: Full HTTPS URL in Firestore
4. **Bucket public**: Public read access enabled
5. **CORS configured**: CORS policy added
6. **App restarted**: Restart Flutter app after changes

## Debug Code to Add

Add this temporarily to see what's happening:

```dart
// In compact_product_card.dart, before image widget:
if (imagePath != null) {
  print('🔍 IMAGE DEBUG:');
  print('   URL: $imagePath');
  print('   Is S3 URL: ${ImageStorageService.isStorageUrl(imagePath)}');
  if (ImageStorageService.isStorageUrl(imagePath)) {
    print('   ✅ Will use CachedNetworkImage');
  } else {
    print('   ❌ Will use local file or placeholder');
  }
}
```

This will show you exactly what URL is being used and whether it's recognized as S3 URL.

