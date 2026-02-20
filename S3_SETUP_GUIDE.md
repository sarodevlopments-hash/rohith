# 🚀 AWS S3 Integration Setup Guide

## ✅ What's Been Done

1. ✅ Created `S3StorageService` - handles S3 uploads
2. ✅ Updated `ImageStorageService` - now uses S3 instead of Firebase Storage
3. ✅ Added `crypto` package for AWS signature generation
4. ✅ Maintained same interface - no other code changes needed

## 📋 Setup Steps

### Step 1: Create AWS S3 Bucket

1. Go to [AWS Console](https://console.aws.amazon.com/s3/)
2. Click **"Create bucket"**
3. Configure:
   - **Bucket name**: e.g., `resqfood-images` (must be globally unique)
   - **Region**: e.g., `ap-south-1` (Mumbai) or `us-east-1`
   - **Block Public Access**: Uncheck if you want public read access
   - **Bucket Versioning**: Disable (unless needed)
4. Click **"Create bucket"**

### Step 2: Configure S3 Bucket Permissions

#### Option A: Public Read Access (Recommended for product images)

1. Go to your bucket → **Permissions** tab
2. **Block public access**: Uncheck all (allow public read)
3. **Bucket policy**: Add this policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::YOUR_BUCKET_NAME/*"
    }
  ]
}
```

Replace `YOUR_BUCKET_NAME` with your actual bucket name.

#### Option B: Authenticated Access Only

Keep bucket private and use presigned URLs (see Step 4).

### Step 3: Choose Your Architecture

#### ⚠️ **IMPORTANT**: For Mobile/Web Apps, Use Backend API (Recommended)

**Do NOT use IAM Users directly in your Flutter app!** This exposes credentials in your app code, which is a security risk.

**Recommended Approach: Backend API with IAM Role**

1. **Create a backend API** (Node.js, Python, etc.) that:
   - Has an IAM Role attached (not user credentials)
   - Generates presigned URLs for S3 uploads
   - Returns the presigned URL to your Flutter app
   - Your app uploads directly to S3 using the presigned URL

2. **Benefits**:
   - ✅ No credentials in your app
   - ✅ Can rotate credentials on backend
   - ✅ Better security
   - ✅ Can add rate limiting, validation, etc.

#### Alternative: IAM User (Only for Development/Testing)

⚠️ **Warning**: Only use this for development/testing. Never use in production!

1. Go to [IAM Console](https://console.aws.amazon.com/iam/)
2. Click **"Users"** → **"Create user"**
3. **User name**: `resqfood-s3-uploader-dev`
4. **Access type**: Select **"Programmatic access"**
5. **Permissions**: Click **"Attach policies directly"**
6. Create custom policy with this JSON:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Resource": "arn:aws:s3:::YOUR_BUCKET_NAME/*"
    }
  ]
}
```

7. Save and create user
8. **IMPORTANT**: Copy the **Access Key ID** and **Secret Access Key** (you won't see it again!)

### Step 4: Configure Your App

#### ✅ Option A: Backend API with Presigned URLs (RECOMMENDED - Production Ready)

**This is the secure way!** Use IAM Role on backend, not credentials in app.

1. **Deploy a backend API** (see `BACKEND_API_EXAMPLE.md` for code)
   - Node.js/Express or Python/Flask
   - Uses IAM Role (not user credentials)
   - Generates presigned URLs

2. **Update `lib/services/s3_storage_service.dart`**:

```dart
static const String? _presignedUrlApi = 'https://api.yourapp.com/api/s3/presigned-url';
// Leave _accessKeyId and _secretAccessKey as placeholders (not used)
```

3. **Backend API Requirements**:
   - Endpoint: `POST /api/s3/presigned-url`
   - Request: `{ "fileName": "sellerId/listings/...", "contentType": "image/jpeg" }`
   - Response: `{ "uploadUrl": "...", "downloadUrl": "..." }`

**Benefits**:
- ✅ No credentials in app
- ✅ IAM Role on backend (more secure)
- ✅ Can add validation, rate limiting
- ✅ Industry best practice

#### ⚠️ Option B: Direct S3 Upload (Development Only - NOT Recommended)

**Only use for development/testing!** Never use in production.

1. Open `lib/services/s3_storage_service.dart`
2. Update these constants:

```dart
static const String _bucketName = 'resqfood-images'; // Your bucket name
static const String _region = 'ap-south-1'; // Your AWS region
static const String _accessKeyId = 'YOUR_AWS_ACCESS_KEY_ID';
static const String _secretAccessKey = 'YOUR_AWS_SECRET_ACCESS_KEY';
static const String? _presignedUrlApi = null; // Keep null for direct upload
```

⚠️ **Security Warning**: 
- ❌ Exposes AWS credentials in your app code
- ❌ Credentials can be extracted from APK/IPA
- ❌ Cannot rotate credentials easily
- ❌ Security risk if app is reverse-engineered
- ✅ Only use for development/testing

### Step 5: Test the Integration

1. **Restart your app**
2. **Upload a product image**
3. **Check console logs** - should see:
   ```
   ✅ Image uploaded successfully to S3: [sellerId]/listings/[listingId]/product_[timestamp].jpg
      URL: https://[bucket].s3.[region].amazonaws.com/...
   ```
4. **Check S3 Console** - image should appear in your bucket
5. **Verify image displays** - should load in app using `CachedNetworkImage`

## 🔒 Security Best Practices

1. **Use Presigned URLs** (Option B) for production
2. **Never commit AWS credentials** to git
3. **Use environment variables** or secure storage for credentials
4. **Limit IAM permissions** - only grant `s3:PutObject` (not full S3 access)
5. **Enable CloudFront** (optional) for CDN and better performance

## 📝 Environment Variables (Recommended)

Instead of hardcoding credentials, use environment variables:

1. Create `.env` file (add to `.gitignore`):
   ```
   AWS_BUCKET_NAME=resqfood-images
   AWS_REGION=ap-south-1
   AWS_ACCESS_KEY_ID=your_key_here
   AWS_SECRET_ACCESS_KEY=your_secret_here
   ```

2. Use `flutter_dotenv` package to load them

## 🎯 What Changed

- **Before**: Images uploaded to Firebase Storage
- **After**: Images uploaded to AWS S3
- **Display**: Still uses `CachedNetworkImage` (works with S3 URLs)
- **Firestore**: Still stores full download URL (now S3 URL instead of Firebase URL)

## ✅ Expected Result

- ✅ Images upload to S3
- ✅ Full S3 URL stored in Firestore
- ✅ Images display correctly in app
- ✅ Images work after app restart
- ✅ No code changes needed elsewhere (same interface)

## 🆘 Troubleshooting

**Images not uploading?**
- Check AWS credentials are correct
- Verify bucket name and region match
- Check IAM user has `s3:PutObject` permission
- Check bucket policy allows uploads

**Images not displaying?**
- Verify bucket has public read access (or use CloudFront)
- Check S3 URL format is correct
- Verify `CachedNetworkImage` is working

**403 Forbidden errors?**
- Check IAM permissions
- Verify bucket policy
- Check CORS configuration if uploading from web

## 📚 Additional Resources

- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [S3 Bucket Policies](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-policies.html)
- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)

