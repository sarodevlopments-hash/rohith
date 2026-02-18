# 🔧 S3 Image Display Troubleshooting Guide

## Issue: Images Not Displaying

If you've configured S3 but images still show the broken image icon, follow these steps:

## Step 1: Check Image URL Format

### Verify the URL is being generated correctly:

1. **Check console logs** when uploading:
   ```
   ✅ Image uploaded successfully to S3: [path]
      URL: https://reqfood.s3.us-east-1.amazonaws.com/...
   ```

2. **Check Firestore** - The `imagePath` field should contain the full S3 URL:
   ```
   https://reqfood.s3.us-east-1.amazonaws.com/[sellerId]/listings/...
   ```

3. **Verify URL format** - Should be:
   ```
   https://reqfood.s3.us-east-1.amazonaws.com/[path]
   ```
   NOT:
   ```
   https://reqfood.s3.amazonaws.com/[path]  ❌ (missing region)
   ```

## Step 2: Check S3 Bucket Permissions

### Enable Public Read Access:

1. Go to **S3 Console** → **`reqfood` bucket**
2. Click **"Permissions"** tab
3. **Block public access**: Click **"Edit"** → Uncheck all 4 boxes → Save
4. **Bucket policy**: Click **"Edit"** → Add this policy:

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

## Step 3: Configure CORS (Important!)

### Add CORS Configuration:

1. Go to **S3 Console** → **`reqfood` bucket**
2. Click **"Permissions"** tab
3. Scroll to **"Cross-origin resource sharing (CORS)"**
4. Click **"Edit"**
5. Paste this CORS configuration:

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

## Step 4: Verify Image Upload

### Check if images are actually uploaded:

1. Go to **S3 Console** → **`reqfood` bucket**
2. Navigate to: `[sellerId]/listings/[listingId]/`
3. You should see files like: `product_[timestamp].jpg`
4. Click on a file → Check **"Object URL"** - should be accessible

### Test URL directly:

1. Copy the Object URL from S3
2. Paste in browser
3. Image should load directly
4. If it doesn't → Bucket permissions issue

## Step 5: Check Flutter App Logs

### Enable Debug Logging:

Add this to see what URL is being used:

```dart
// In your widget, add debug print:
print('🔍 Image URL: ${listing.imagePath}');
print('🔍 Is Storage URL: ${ImageStorageService.isStorageUrl(listing.imagePath)}');
```

### Check for Errors:

Look for these in console:
- `❌ Error loading image`
- `CachedNetworkImage error`
- `403 Forbidden`
- `404 Not Found`

## Step 6: Common Issues & Fixes

### Issue 1: URL Not Recognized as S3 URL

**Symptom**: Image shows local file placeholder

**Fix**: Check `isStorageUrl` method recognizes your URL format:
```dart
// Should return true for:
// https://reqfood.s3.us-east-1.amazonaws.com/...
// https://reqfood.s3.amazonaws.com/...
```

### Issue 2: 403 Forbidden Error

**Symptom**: Image fails to load with 403 error

**Fixes**:
- ✅ Enable public read access (Step 2)
- ✅ Check bucket policy allows `s3:GetObject`
- ✅ Verify IAM user has read permissions

### Issue 3: CORS Error

**Symptom**: Browser console shows CORS error

**Fix**: Configure CORS (Step 3)

### Issue 4: 404 Not Found

**Symptom**: Image URL returns 404

**Fixes**:
- ✅ Verify image was uploaded successfully
- ✅ Check file path in S3 matches URL
- ✅ Verify bucket name is correct (`reqfood`)

### Issue 5: Old Images Still Showing Broken Icon

**Symptom**: New uploads work, but old listings show broken images

**Fix**: Old listings might have:
- Local file paths (not S3 URLs)
- Firebase Storage URLs (not S3)
- Invalid URLs

**Solution**: Re-upload images for old listings OR migrate existing URLs

## Step 7: Test Checklist

✅ **S3 Bucket**:
- [ ] Bucket name: `reqfood`
- [ ] Region: `us-east-1`
- [ ] Public read access enabled
- [ ] Bucket policy allows `s3:GetObject`
- [ ] CORS configured

✅ **IAM User**:
- [ ] User: `reqfooduser`
- [ ] Has `s3:PutObject` permission
- [ ] Access key is correct

✅ **Flutter App**:
- [ ] S3 credentials configured
- [ ] Region set to `us-east-1`
- [ ] Bucket name: `reqfood`
- [ ] `CachedNetworkImage` is being used
- [ ] `isStorageUrl` recognizes S3 URLs

✅ **Image Upload**:
- [ ] Upload succeeds (check console)
- [ ] URL is generated correctly
- [ ] URL is stored in Firestore
- [ ] Image appears in S3 bucket

✅ **Image Display**:
- [ ] URL is recognized as S3 URL
- [ ] `CachedNetworkImage` loads the image
- [ ] No 403/404 errors in console
- [ ] Image displays correctly

## Step 8: Debug Code

Add this temporary debug code to see what's happening:

```dart
// In compact_product_card.dart or buyer_listing_card.dart
// Add before the image widget:

if (imagePath != null) {
  print('🔍 DEBUG IMAGE:');
  print('   Path: $imagePath');
  print('   Is Storage URL: ${ImageStorageService.isStorageUrl(imagePath)}');
  print('   Is Local Path: ${ImageStorageService.isLocalPath(imagePath)}');
  print('   URL starts with https: ${imagePath.startsWith('https://')}');
}
```

## Quick Fix: Test with Direct URL

1. Upload an image
2. Copy the S3 Object URL from S3 Console
3. Temporarily hardcode it in your widget:
   ```dart
   imageUrl: 'https://reqfood.s3.us-east-1.amazonaws.com/[your-path]'
   ```
4. If this works → URL format is correct, check permissions
5. If this doesn't work → Bucket permissions issue

## Still Not Working?

1. **Check S3 bucket logs** (if enabled)
2. **Check CloudWatch** for errors
3. **Test URL in browser** - does it load?
4. **Check network tab** in Flutter DevTools
5. **Verify image actually uploaded** to S3

## Expected Behavior

After fixing:
- ✅ Images upload successfully
- ✅ Full S3 URL stored in Firestore
- ✅ Images display in app
- ✅ Images work after app restart
- ✅ No broken image icons

