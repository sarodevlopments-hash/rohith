# 🔐 Backend API Example for S3 Presigned URLs

## Why Use a Backend API?

✅ **Security**: No AWS credentials in your Flutter app
✅ **Flexibility**: Can add validation, rate limiting, logging
✅ **Control**: Can restrict file types, sizes, etc.
✅ **Best Practice**: Industry standard for mobile apps

## Example: Node.js/Express Backend

### 1. Install Dependencies

```bash
npm install express aws-sdk cors dotenv
```

### 2. Backend Code (`server.js`)

```javascript
const express = require('express');
const AWS = require('aws-sdk');
const cors = require('cors');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// Configure AWS SDK (uses IAM Role if on EC2, or credentials from .env)
const s3 = new AWS.S3({
  region: process.env.AWS_REGION || 'us-east-1',
  // If not using IAM Role, uncomment:
  // accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  // secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
});

const BUCKET_NAME = process.env.S3_BUCKET_NAME;

// Generate presigned URL for upload
app.post('/api/s3/presigned-url', async (req, res) => {
  try {
    const { fileName, contentType = 'image/jpeg' } = req.body;
    
    // Validate input
    if (!fileName) {
      return res.status(400).json({ error: 'fileName is required' });
    }

    // Validate file type (security)
    const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];
    if (!allowedTypes.includes(contentType)) {
      return res.status(400).json({ error: 'Invalid content type' });
    }

    // Validate file name (prevent path traversal)
    if (fileName.includes('..') || fileName.startsWith('/')) {
      return res.status(400).json({ error: 'Invalid file name' });
    }

    // Generate presigned URL (valid for 5 minutes)
    const params = {
      Bucket: BUCKET_NAME,
      Key: fileName,
      ContentType: contentType,
      Expires: 300, // 5 minutes
    };

    const uploadUrl = await s3.getSignedUrlPromise('putObject', params);
    
    // Generate public download URL
    const downloadUrl = `https://${BUCKET_NAME}.s3.${process.env.AWS_REGION || 'us-east-1'}.amazonaws.com/${fileName}`;

    res.json({
      uploadUrl,
      downloadUrl,
      expiresIn: 300, // seconds
    });
  } catch (error) {
    console.error('Error generating presigned URL:', error);
    res.status(500).json({ error: 'Failed to generate presigned URL' });
  }
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

### 3. Environment Variables (`.env`)

```env
AWS_REGION=us-east-1
S3_BUCKET_NAME=reqfood
PORT=3000

# Only if not using IAM Role:
# AWS_ACCESS_KEY_ID=your_key_here
# AWS_SECRET_ACCESS_KEY=your_secret_here
```

### 4. IAM Role for Backend (Recommended)

If deploying on AWS (EC2, Lambda, ECS):

1. **Create IAM Role**:
   - Go to IAM → Roles → Create Role
   - Select: EC2 (or Lambda, ECS, etc.)
   - Attach policy: Custom policy with S3 permissions

2. **Policy JSON**:
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

3. **Attach Role** to your EC2 instance/Lambda function

## Example: Python/Flask Backend

### 1. Install Dependencies

```bash
pip install flask flask-cors boto3 python-dotenv
```

### 2. Backend Code (`app.py`)

```python
from flask import Flask, request, jsonify
from flask_cors import CORS
import boto3
from botocore.config import Config
import os
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
CORS(app)

# Configure S3 client
s3_client = boto3.client(
    's3',
    region_name=os.getenv('AWS_REGION', 'us-east-1'),
    # If not using IAM Role, uncomment:
    # aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID'),
    # aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY'),
)

BUCKET_NAME = os.getenv('S3_BUCKET_NAME')

@app.route('/api/s3/presigned-url', methods=['POST'])
def get_presigned_url():
    try:
        data = request.json
        file_name = data.get('fileName')
        content_type = data.get('contentType', 'image/jpeg')
        
        # Validate input
        if not file_name:
            return jsonify({'error': 'fileName is required'}), 400
        
        # Validate file type
        allowed_types = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
        if content_type not in allowed_types:
            return jsonify({'error': 'Invalid content type'}), 400
        
        # Validate file name
        if '..' in file_name or file_name.startswith('/'):
            return jsonify({'error': 'Invalid file name'}), 400
        
        # Generate presigned URL
        upload_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': BUCKET_NAME,
                'Key': file_name,
                'ContentType': content_type,
            },
            ExpiresIn=300,  # 5 minutes
        )
        
        # Generate download URL
        download_url = f"https://{BUCKET_NAME}.s3.{os.getenv('AWS_REGION', 'us-east-1')}.amazonaws.com/{file_name}"
        
        return jsonify({
            'uploadUrl': upload_url,
            'downloadUrl': download_url,
            'expiresIn': 300,
        })
    except Exception as e:
        print(f'Error: {e}')
        return jsonify({'error': 'Failed to generate presigned URL'}), 500

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok'})

if __name__ == '__main__':
    app.run(port=int(os.getenv('PORT', 3000)))
```

## Update Flutter App

### Update `s3_storage_service.dart`:

```dart
// Set your backend API URL
static const String? _presignedUrlApi = 'https://api.yourapp.com/api/s3/presigned-url';
```

The existing code already supports presigned URLs! Just set the `_presignedUrlApi` constant.

## Security Best Practices

1. ✅ **Use IAM Roles** (not users) for backend
2. ✅ **Validate file types** on backend
3. ✅ **Validate file sizes** (add max size check)
4. ✅ **Rate limiting** (prevent abuse)
5. ✅ **Authentication** (verify user is logged in)
6. ✅ **Logging** (track uploads for security)
7. ✅ **HTTPS only** (encrypt API calls)

## Deployment Options

1. **AWS Lambda** (Serverless) - Pay per request
2. **AWS EC2** - Fixed monthly cost
3. **AWS ECS/Fargate** - Container-based
4. **Heroku** - Easy deployment
5. **Railway** - Simple hosting
6. **Vercel/Netlify** - For serverless functions

## Cost Estimate

- **Lambda**: ~₹0.20 per 1M requests (very cheap)
- **EC2 t3.micro**: ~₹500/month (24/7)
- **Heroku**: Free tier available

## Next Steps

1. Choose your backend (Node.js or Python)
2. Deploy backend API
3. Update Flutter app with API URL
4. Test upload flow
5. Monitor and secure

