# 🔍 Debug Upload Logs Guide

## What to Look For

After adding comprehensive logging, you should now see detailed logs when uploading. Here's what to check:

## Expected Log Flow

### 1. When You Click "Post" or "Save Listing":

```
🖼️ Checking product image upload...
   Product image path: [path]
   Is local path: true/false
   Is storage URL: true/false
```

### 2. If Image Needs Upload:

```
📤 Starting image upload to S3...
🚀 S3StorageService.uploadImage called
   Local path: [path]
   Seller ID: [id]
   Listing ID: [id]
   Is Web: true/false
   Has imageBytes: true/false
   Current user: [user id]
```

### 3. Authentication Check:

```
✅ Authentication check passed
```

OR

```
⚠️ Not authenticated or unauthorized to upload image for seller [id]
   Current user: NULL or [different id]
   Expected seller: [id]
```

### 4. File Processing:

**For Web:**
```
🌐 Web platform - using imageBytes
   Image bytes size: [size]
```

**For Mobile:**
```
📱 Mobile platform - reading from file
   File size: [size] bytes
```

### 5. Upload Method:

```
📤 Starting S3 upload...
   Bucket: reqfood
   Region: us-east-1
   Using presigned URL API: false
📤 Using direct S3 upload method
```

### 6. Signature Calculation:

```
🔧 _uploadDirectly called
   File: [filename]
   Size: [bytes]
   Content-Type: image/jpeg
   Date stamp: [date]
   AMZ date: [datetime]
🔐 Calculating AWS signature...
   Signature calculated (first 20 chars): [signature]...
   Authorization header created
```

### 7. Upload Request:

```
📤 Uploading to S3:
   URL: https://reqfood.s3.us-east-1.amazonaws.com/...
   File: [filename]
   Size: [bytes]
   Content-Type: image/jpeg
```

### 8. Response:

**Success:**
```
📥 S3 Response:
   Status: 200
   Headers: {...}
✅ Upload successful!
✅ Image uploaded successfully to S3: [filename]
   URL: https://reqfood.s3.us-east-1.amazonaws.com/...
📥 Upload result: SUCCESS
   Uploaded URL: [url]
```

**Failure:**
```
📥 S3 Response:
   Status: [error code]
   Headers: {...}
❌ S3 upload failed: [status code]
   Response body: [error message]
❌ Upload returned null - upload failed
📥 Upload result: FAILED
❌ Image upload failed - stopping submission
```

## Common Issues & What Logs Show

### Issue 1: Upload Not Called

**Symptom**: No logs at all when clicking "Post"

**Possible causes:**
- Image path is already a storage URL (skips upload)
- Image path is null
- Code path not reached

**Check logs for:**
```
🖼️ Checking product image upload...
   Is local path: false  ← Should be true
   Is storage URL: true  ← Should be false
```

### Issue 2: Authentication Failure

**Symptom**: Logs show authentication error

**Check logs for:**
```
⚠️ Not authenticated or unauthorized
   Current user: NULL
```

**Fix**: Make sure user is logged in

### Issue 3: File Not Found (Mobile)

**Symptom**: Logs show file doesn't exist

**Check logs for:**
```
❌ Image file does not exist: [path]
```

**Fix**: Check file path is correct

### Issue 4: No Image Bytes (Web)

**Symptom**: Logs show no bytes

**Check logs for:**
```
❌ No image bytes provided for web upload
```

**Fix**: Check image picker is providing bytes

### Issue 5: Upload Fails with 403

**Symptom**: Status 403 in response

**Check logs for:**
```
📥 S3 Response:
   Status: 403
```

**Fix**: Check IAM permissions

### Issue 6: Upload Fails with 400

**Symptom**: Status 400 in response

**Check logs for:**
```
📥 S3 Response:
   Status: 400
   Response body: [error]
```

**Fix**: Check signature calculation or content-type

## How to Test

1. **Open Flutter DevTools** or check console
2. **Clear console** (to see fresh logs)
3. **Add a new listing** with an image
4. **Click "Post"**
5. **Watch the logs** - you should see the full flow above

## What to Share

If upload still fails, share these logs:
- All logs starting with 🚀, 📤, 🔧, 📥
- Any ❌ error messages
- The S3 Response status code and body

This will help identify exactly where it's failing!

