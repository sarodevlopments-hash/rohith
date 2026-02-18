# AWS Credentials Setup

## ⚠️ Security Notice

AWS credentials should **NEVER** be committed to Git. They are currently removed from the codebase for security.

## Setup Options

### Option 1: Environment Variables (Recommended for Development)

1. Create a `.env` file in the project root (already gitignored):
   ```
   AWS_ACCESS_KEY_ID=your_access_key_here
   AWS_SECRET_ACCESS_KEY=your_secret_key_here
   ```

2. Update `lib/services/s3_storage_service.dart` to load from environment:
   ```dart
   static String get _accessKeyId {
     const String? key = Platform.environment['AWS_ACCESS_KEY_ID'];
     return key ?? throw Exception('AWS_ACCESS_KEY_ID not set');
   }
   
   static String get _secretAccessKey {
     const String? key = Platform.environment['AWS_SECRET_ACCESS_KEY'];
     return key ?? throw Exception('AWS_SECRET_ACCESS_KEY not set');
   }
   ```

3. Use `flutter_dotenv` package to load `.env` file:
   ```yaml
   dependencies:
     flutter_dotenv: ^5.1.0
   ```

### Option 2: Backend API with Presigned URLs (Recommended for Production)

Use a backend API to generate presigned URLs. This is the most secure approach.

See `BACKEND_API_EXAMPLE.md` for implementation details.

### Option 3: Temporary Development Setup

For local development only, you can temporarily hardcode credentials in `s3_storage_service.dart`, but:
- **NEVER commit them to Git**
- Remove them before pushing
- Use Option 1 or 2 for any shared code

## Your Current Credentials

Your AWS credentials should be stored securely (not in Git):
- Access Key ID: (stored in environment variable or secure storage)
- Secret Access Key: (stored in environment variable or secure storage)
- Bucket: `reqfood`
- Region: `us-east-1`

**Note:** Never commit actual credentials to Git. Store them in environment variables or use a backend API.

## Next Steps

1. Set up environment variables (Option 1) or backend API (Option 2)
2. Update `s3_storage_service.dart` to use your chosen method
3. Test the image upload/delete functionality
4. Never commit credentials to Git

