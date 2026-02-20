# ⚠️ SECURITY WARNING - AWS Credentials in Code

## 🚨 Important Security Notice

**Your AWS credentials are now hardcoded in `lib/services/s3_storage_service.dart`**

This is a **SECURITY RISK** because:
- ❌ Credentials are visible in your app code
- ❌ Can be extracted from APK/IPA files
- ❌ Anyone with access to your code can see credentials
- ❌ Cannot rotate credentials easily
- ❌ If code is committed to Git, credentials are exposed

## ✅ Current Configuration

Your S3 is configured with:
- **Bucket**: `reqfood`
- **Region**: `us-east-1` (N. Virginia)
- **User**: `reqfooduser`
- **Access Key**: `AKIA3E6WQJ645V7T5PM2`

## 🔒 Recommended: Move to Backend API

**For production, you MUST use a backend API with presigned URLs:**

1. **Create a backend API** (see `BACKEND_API_EXAMPLE.md`)
2. **Store credentials on backend** (not in app)
3. **Backend generates presigned URLs**
4. **App uploads using temporary URLs**

This way:
- ✅ No credentials in app
- ✅ Can rotate credentials on backend
- ✅ Better security
- ✅ Industry best practice

## 🛡️ Immediate Security Steps

### 1. Restrict IAM User Permissions

Go to IAM → Users → `reqfooduser` → Permissions:

**Create a restrictive policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::reqfood/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-server-side-encryption": "AES256"
        }
      }
    }
  ]
}
```

**Remove any unnecessary permissions:**
- ❌ Don't allow `s3:DeleteObject` unless needed
- ❌ Don't allow `s3:GetObject` unless needed
- ❌ Don't allow `s3:*` (full access)

### 2. Enable S3 Bucket Encryption

1. Go to S3 → `reqfood` bucket
2. **Properties** → **Default encryption**
3. Enable **"Server-side encryption"**
4. Choose **"AES-256"**
5. Save

### 3. Set Up Bucket Policy (Public Read)

If you want public read access for images:

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

### 4. Monitor Access

1. Enable **CloudTrail** to log all S3 access
2. Set up **S3 access logging**
3. Monitor for unusual activity
4. Set up **billing alerts** in AWS

### 5. Rotate Credentials Regularly

- Rotate access keys every 90 days
- Create new keys before deleting old ones
- Update app with new keys

## 📝 Next Steps

1. ✅ **Test the current setup** - Verify images upload correctly
2. ⚠️ **Plan backend migration** - Move to presigned URLs
3. 🔒 **Restrict IAM permissions** - Limit what the user can do
4. 📊 **Monitor usage** - Watch for unauthorized access
5. 🔄 **Rotate credentials** - Change keys regularly

## 🚀 Quick Test

Test your S3 upload:

1. Run your Flutter app
2. Upload a product image
3. Check console for:
   ```
   ✅ Image uploaded successfully to S3: [path]
      URL: https://reqfood.s3.us-east-1.amazonaws.com/...
   ```
4. Check S3 Console → `reqfood` bucket → images should appear

## ⚠️ Before Committing to Git

**DO NOT commit credentials to Git!**

If you haven't already:
1. Add `.env` to `.gitignore` ✅ (already done)
2. Check if credentials are in Git history:
   ```bash
   git log --all --full-history -- "lib/services/s3_storage_service.dart"
   ```
3. If found, consider:
   - Rotating credentials (create new keys)
   - Removing from Git history (advanced)

## 📚 Resources

- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [S3 Security Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [Backend API Example](./BACKEND_API_EXAMPLE.md)

