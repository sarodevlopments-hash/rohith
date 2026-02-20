# 🔐 IAM Role Setup Guide for S3 Backend API

## Step-by-Step: Creating IAM Role

### Step 1: Select Trusted Entity Type

**Choose based on where you're deploying your backend:**

#### ✅ Option 1: AWS Service (Most Common)

**Choose this if deploying on:**
- AWS Lambda (Serverless)
- AWS EC2 (Virtual Server)
- AWS ECS/Fargate (Containers)
- AWS Elastic Beanstalk
- Any AWS service

**Steps:**
1. ✅ Select **"AWS service"** (already selected in your screenshot)
2. Click **"Next"**

#### Option 2: Custom Trust Policy (For Non-AWS Hosting)

**Choose this if deploying on:**
- Heroku
- Railway
- Vercel
- Netlify
- Your own server (not on AWS)
- Any non-AWS hosting

**Steps:**
1. Select **"Custom trust policy"**
2. Use this trust policy JSON:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::YOUR_ACCOUNT_ID:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {}
    }
  ]
}
```

Replace `YOUR_ACCOUNT_ID` with your AWS account ID (found in top-right of AWS Console).

**Note**: For non-AWS hosting, you might need to use IAM User instead of Role (see alternative below).

---

## Step 2: Select Use Case (If you chose "AWS service")

After clicking "Next", you'll see a dropdown:

### For AWS Lambda:
1. In "Service or use case" dropdown, search for **"Lambda"**
2. Select **"Lambda"**
3. Click **"Next"**

### For AWS EC2:
1. In "Service or use case" dropdown, search for **"EC2"**
2. Select **"EC2"**
3. Click **"Next"**

### For AWS ECS/Fargate:
1. In "Service or use case" dropdown, search for **"Elastic Container Service"**
2. Select **"Elastic Container Service Task"**
3. Click **"Next"**

---

## Step 3: Add Permissions

After selecting use case, you'll see "Add permissions" page:

1. Click **"Create policy"** (opens new tab)
2. Go to **"JSON"** tab
3. Paste this policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::YOUR_BUCKET_NAME/*"
    }
  ]
}
```

**Replace `YOUR_BUCKET_NAME`** with your actual S3 bucket name (e.g., `resqfood-images`).

4. Click **"Next"**
5. Name the policy: `S3UploadPolicy` (or any name)
6. Click **"Create policy"**
7. Go back to Role creation tab
8. Click refresh (🔄) button
9. Search for your policy name
10. Select it
11. Click **"Next"**

---

## Step 4: Name Your Role

1. **Role name**: `S3PresignedUrlRole` (or any name)
2. **Description**: "Role for backend API to generate S3 presigned URLs"
3. Click **"Create role"**

---

## Step 5: Attach Role to Your Service

### For AWS Lambda:
1. Go to Lambda function
2. Go to **"Configuration"** → **"Permissions"**
3. Click **"Edit"**
4. Select your role from dropdown
5. Click **"Save"**

### For AWS EC2:
1. Go to EC2 instance
2. Select instance
3. Click **"Actions"** → **"Security"** → **"Modify IAM role"**
4. Select your role
5. Click **"Update IAM role"**

### For AWS ECS:
1. Go to ECS Task Definition
2. In "Task role", select your role
3. Save task definition

---

## Alternative: IAM User (For Non-AWS Hosting)

If you're **NOT deploying on AWS**, you can't use IAM Role. Instead:

### Create IAM User:

1. Go to **IAM** → **Users** → **"Create user"**
2. **User name**: `s3-backend-user`
3. **Access type**: Select **"Programmatic access"**
4. Click **"Next"**
5. **Permissions**: Click **"Attach policies directly"**
6. Click **"Create policy"** (same policy as above)
7. Attach policy to user
8. Click **"Create user"**
9. **IMPORTANT**: Copy **Access Key ID** and **Secret Access Key**

### Use in Backend:

```javascript
// In your backend .env file
AWS_ACCESS_KEY_ID=your_access_key_here
AWS_SECRET_ACCESS_KEY=your_secret_key_here
```

---

## Quick Decision Guide

**Where are you deploying your backend?**

| Hosting | Choose |
|---------|--------|
| AWS Lambda | ✅ **AWS service** → Lambda |
| AWS EC2 | ✅ **AWS service** → EC2 |
| AWS ECS/Fargate | ✅ **AWS service** → ECS Task |
| Heroku | ⚠️ Use **IAM User** (not Role) |
| Railway | ⚠️ Use **IAM User** (not Role) |
| Vercel/Netlify | ⚠️ Use **IAM User** (not Role) |
| Your own server | ⚠️ Use **IAM User** (not Role) |

---

## Summary

**For your current screenshot:**

1. ✅ **Keep "AWS service" selected** (if deploying on AWS)
2. Click **"Next"**
3. Select your service (Lambda/EC2/ECS) from dropdown
4. Continue with permissions setup

**If NOT deploying on AWS:**
- Choose **"Custom trust policy"** OR
- Use **IAM User** instead (simpler for non-AWS)

---

## Next Steps After Creating Role

1. ✅ Role created
2. ✅ Attach to your backend service
3. ✅ Update backend code (see `BACKEND_API_EXAMPLE.md`)
4. ✅ Test presigned URL generation
5. ✅ Update Flutter app with API URL

