import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart' show Hmac, sha256;

/// Service to handle image uploads to AWS S3
/// 
/// Configuration required:
/// - S3_BUCKET_NAME: Your S3 bucket name
/// - AWS_REGION: AWS region (e.g., 'us-east-1', 'ap-south-1')
/// - AWS_ACCESS_KEY_ID: AWS access key (for direct upload)
/// - AWS_SECRET_ACCESS_KEY: AWS secret key (for direct upload)
/// 
/// OR use a backend API endpoint that generates presigned URLs (recommended for security)
class S3StorageService {
  // ⚠️ SECURITY WARNING: These credentials are exposed in your app code!
  // For production, use a backend API with presigned URLs instead.
  // See BACKEND_API_EXAMPLE.md for the secure approach.
  
  // S3 Configuration
  static const String _bucketName = 'reqfood'; // Your S3 bucket name
  static const String _region = 'us-east-1'; // AWS region (N. Virginia)
  
  // ⚠️ SECURITY: Credentials should be loaded from environment variables or secure storage
  // For development, set these in your environment or use a .env file (gitignored)
  // For production, use a backend API with presigned URLs (see BACKEND_API_EXAMPLE.md)
  static String get _accessKeyId {
    // TODO: Load from environment variable or secure storage
    // Example: const String? key = Platform.environment['AWS_ACCESS_KEY_ID'];
    // For now, you need to set this manually or use backend API
    throw UnimplementedError('AWS_ACCESS_KEY_ID must be configured. See S3_SETUP_GUIDE.md');
  }
  
  static String get _secretAccessKey {
    // TODO: Load from environment variable or secure storage
    // Example: const String? key = Platform.environment['AWS_SECRET_ACCESS_KEY'];
    // For now, you need to set this manually or use backend API
    throw UnimplementedError('AWS_SECRET_ACCESS_KEY must be configured. See S3_SETUP_GUIDE.md');
  }
  
  // Option 2: Backend API endpoint (recommended for production - more secure)
  // Set this to your backend API that generates presigned URLs
  // If set, direct upload credentials above will be ignored
  static const String? _presignedUrlApi = null; // e.g., 'https://api.yourapp.com/s3/presigned-url'

  /// Upload a single image to S3
  /// Returns the download URL if successful, null otherwise
  static Future<String?> uploadImage({
    required String localPath,
    Uint8List? imageBytes, // For web
    required String sellerId,
    String? listingId,
    String? colorName, // For color-specific images
  }) async {
    print('🚀 S3StorageService.uploadImage called');
    print('   Local path: $localPath');
    print('   Seller ID: $sellerId');
    print('   Listing ID: $listingId');
    print('   Color name: $colorName');
    print('   Is Web: $kIsWeb');
    print('   Has imageBytes: ${imageBytes != null}');
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      print('   Current user: ${currentUser?.uid ?? "NULL"}');
      
      if (currentUser == null || currentUser.uid != sellerId) {
        print('⚠️ Not authenticated or unauthorized to upload image for seller $sellerId');
        print('   Current user: ${currentUser?.uid ?? "NULL"}');
        print('   Expected seller: $sellerId');
        return null;
      }

      print('✅ Authentication check passed');

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = colorName != null
          ? '${sellerId}/listings/${listingId ?? 'temp'}/colors/${colorName}_$timestamp.jpg'
          : '${sellerId}/listings/${listingId ?? 'temp'}/product_$timestamp.jpg';

      print('📝 Generated filename: $fileName');

      // Read file bytes
      Uint8List bytes;
      if (kIsWeb) {
        print('🌐 Web platform - using imageBytes');
        if (imageBytes == null) {
          print('❌ No image bytes provided for web upload');
          return null;
        }
        bytes = imageBytes;
        print('   Image bytes size: ${bytes.length}');
      } else {
        print('📱 Mobile platform - reading from file');
        final file = File(localPath);
        if (!await file.exists()) {
          print('❌ Image file does not exist: $localPath');
          return null;
        }
        bytes = await file.readAsBytes();
        print('   File size: ${bytes.length} bytes');
      }

      print('📤 Starting S3 upload...');
      print('   Bucket: $_bucketName');
      print('   Region: $_region');
      print('   Using presigned URL API: ${_presignedUrlApi != null}');

      // Upload to S3
      String? downloadUrl;
      if (_presignedUrlApi != null) {
        print('🔗 Using presigned URL method');
        // Use backend API for presigned URL (recommended)
        downloadUrl = await _uploadViaPresignedUrl(fileName, bytes);
      } else {
        print('📤 Using direct S3 upload method');
        // Direct S3 upload
        downloadUrl = await _uploadDirectly(fileName, bytes);
      }

      if (downloadUrl != null) {
        print('✅ Image uploaded successfully to S3: $fileName');
        print('   URL: $downloadUrl');
      } else {
        print('❌ Upload returned null - upload failed');
      }
      return downloadUrl;
    } catch (e, stackTrace) {
      print('❌ Error uploading image to S3: $e');
      print('   Stack trace: $stackTrace');
      return null;
    }
  }

  /// Upload using presigned URL from backend API (recommended)
  static Future<String?> _uploadViaPresignedUrl(String fileName, Uint8List bytes) async {
    try {
      // Step 1: Get presigned URL from your backend
      final response = await http.post(
        Uri.parse('$_presignedUrlApi?fileName=$fileName&contentType=image/jpeg'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        print('❌ Failed to get presigned URL: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);
      final uploadUrl = data['uploadUrl'] as String;
      final downloadUrl = data['downloadUrl'] as String;

      // Step 2: Upload file to S3 using presigned URL
      final uploadResponse = await http.put(
        Uri.parse(uploadUrl),
        body: bytes,
        headers: {'Content-Type': 'image/jpeg'},
      );

      if (uploadResponse.statusCode == 200) {
        return downloadUrl;
      } else {
        print('❌ Failed to upload to S3: ${uploadResponse.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error in presigned URL upload: $e');
      return null;
    }
  }

  /// Direct S3 upload using AWS credentials (less secure)
  static Future<String?> _uploadDirectly(String fileName, Uint8List bytes, [String contentType = 'image/jpeg']) async {
    print('🔧 _uploadDirectly called');
    print('   File: $fileName');
    print('   Size: ${bytes.length} bytes');
    print('   Content-Type: $contentType');
    
    try {
      // Use the passed contentType parameter (don't override it)
      final now = DateTime.now().toUtc();
      final dateStamp = _formatDate(now);
      final amzDate = _formatDateTime(now);
      
      print('   Date stamp: $dateStamp');
      print('   AMZ date: $amzDate');

      // Create canonical request
      final canonicalUri = '/$fileName';
      final canonicalQueryString = '';
      final payloadHash = sha256.convert(bytes).toString();
      final canonicalHeaders = 'content-type:$contentType\nhost:$_bucketName.s3.$_region.amazonaws.com\nx-amz-content-sha256:$payloadHash\nx-amz-date:$amzDate\n';
      final signedHeaders = 'content-type;host;x-amz-content-sha256;x-amz-date';

      final canonicalRequest = 'PUT\n'
          '$canonicalUri\n'
          '$canonicalQueryString\n'
          '$canonicalHeaders\n'
          '$signedHeaders\n'
          '$payloadHash';

      // Create string to sign
      final algorithm = 'AWS4-HMAC-SHA256';
      final credentialScope = '$dateStamp/$_region/s3/aws4_request';
      final stringToSign = '$algorithm\n'
          '$amzDate\n'
          '$credentialScope\n'
          '${sha256.convert(utf8.encode(canonicalRequest)).toString()}';

      print('🔐 Calculating AWS signature...');
      // Calculate signature
      final kSecret = utf8.encode('AWS4$_secretAccessKey');
      final kDate = _hmacSha256(kSecret, dateStamp);
      final kRegion = _hmacSha256(kDate, _region);
      final kService = _hmacSha256(kRegion, 's3');
      final kSigning = _hmacSha256(kService, 'aws4_request');
      final signatureBytes = _hmacSha256(kSigning, stringToSign);
      final signature = _bytesToHex(signatureBytes);
      
      print('   Signature calculated (first 20 chars): ${signature.substring(0, signature.length > 20 ? 20 : signature.length)}...');

      // Create authorization header
      final authorization = '$algorithm '
          'Credential=$_accessKeyId/$credentialScope, '
          'SignedHeaders=$signedHeaders, '
          'Signature=$signature';
      
      print('   Authorization header created');

      // Upload to S3
      final url = 'https://$_bucketName.s3.$_region.amazonaws.com/$fileName';
      
      print('📤 Uploading to S3:');
      print('   URL: $url');
      print('   File: $fileName');
      print('   Size: ${bytes.length} bytes');
      print('   Content-Type: $contentType');
      
      final response = await http.put(
        Uri.parse(url),
        body: bytes,
        headers: {
          'Content-Type': contentType,
          'x-amz-content-sha256': payloadHash,
          'x-amz-date': amzDate,
          'Authorization': authorization,
        },
      );

      print('📥 S3 Response:');
      print('   Status: ${response.statusCode}');
      print('   Headers: ${response.headers}');
      
      if (response.statusCode == 200) {
        print('✅ Upload successful!');
        // Return public URL (or CloudFront URL if configured)
        return url;
      } else {
        print('❌ S3 upload failed: ${response.statusCode}');
        print('   Response body: ${response.body}');
        print('   Response headers: ${response.headers}');
        return null;
      }
    } catch (e) {
      print('❌ Error in direct S3 upload: $e');
      return null;
    }
  }

  /// Upload multiple color images
  static Future<Map<String, String>> uploadColorImages({
    required Map<String, String> colorImagePaths,
    Map<String, Uint8List>? colorImageBytes,
    required String sellerId,
    String? listingId,
  }) async {
    final uploadedUrls = <String, String>{};

    for (final entry in colorImagePaths.entries) {
      final colorName = entry.key;
      final localPath = entry.value;

      final url = await uploadImage(
        localPath: localPath,
        imageBytes: colorImageBytes?[colorName],
        sellerId: sellerId,
        listingId: listingId,
        colorName: colorName,
      );

      if (url != null) {
        uploadedUrls[colorName] = url;
      }
    }

    return uploadedUrls;
  }

  /// Upload a document to S3
  static Future<String?> uploadDocument({
    required String documentType,
    String? localPath,
    Uint8List? documentBytes,
    required String sellerId,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != sellerId) {
        print('⚠️ Not authenticated or unauthorized');
        return null;
      }

      // Read file bytes
      Uint8List bytes;
      String contentType;
      String extension;

      if (kIsWeb) {
        if (documentBytes == null) {
          print('❌ No document bytes provided');
          return null;
        }
        bytes = documentBytes;
        // Detect type from bytes
        if (bytes.length > 4 && String.fromCharCodes(bytes.sublist(0, 4)) == '%PDF') {
          extension = 'pdf';
          contentType = 'application/pdf';
        } else if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
          extension = 'jpg';
          contentType = 'image/jpeg';
        } else {
          extension = 'png';
          contentType = 'image/png';
        }
      } else {
        if (localPath == null) {
          print('❌ No local path provided');
          return null;
        }
        final file = File(localPath);
        if (!await file.exists()) {
          print('❌ Document file does not exist');
          return null;
        }
        bytes = await file.readAsBytes();
        if (localPath.toLowerCase().endsWith('.pdf')) {
          extension = 'pdf';
          contentType = 'application/pdf';
        } else if (localPath.toLowerCase().endsWith('.jpg') || localPath.toLowerCase().endsWith('.jpeg')) {
          extension = 'jpg';
          contentType = 'image/jpeg';
        } else {
          extension = 'png';
          contentType = 'image/png';
        }
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cleanDocType = documentType.replaceAll(' ', '_').replaceAll('/', '_');
      final fileName = '${sellerId}/documents/grocery/${cleanDocType}_$timestamp.$extension';

      String? downloadUrl;
      if (_presignedUrlApi != null) {
        downloadUrl = await _uploadViaPresignedUrl(fileName, bytes);
      } else {
        downloadUrl = await _uploadDirectly(fileName, bytes, contentType);
      }

      if (downloadUrl != null) {
        print('✅ Document uploaded to S3: $fileName');
      }
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading document to S3: $e');
      return null;
    }
  }

  /// Delete an image from S3
  /// Returns true if successful, false otherwise
  static Future<bool> deleteImage(String imageUrl) async {
    try {
      print('🗑️ S3StorageService.deleteImage called');
      print('   Image URL: $imageUrl');
      
      // Check if it's an S3 URL
      if (!isStorageUrl(imageUrl)) {
        print('⚠️ Not an S3 URL, skipping deletion: $imageUrl');
        return false;
      }
      
      // Extract the object key from the URL
      // URL format: https://bucket.s3.region.amazonaws.com/key
      final objectKey = _extractObjectKeyFromUrl(imageUrl);
      if (objectKey == null) {
        print('❌ Could not extract object key from URL: $imageUrl');
        return false;
      }
      
      print('   Object key: $objectKey');
      
      // Check authentication
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('⚠️ Not authenticated, cannot delete image');
        return false;
      }
      
      // Create DELETE request with AWS Signature Version 4
      final now = DateTime.now().toUtc();
      final dateStamp = _formatDate(now);
      final amzDate = _formatDateTime(now);
      
      // For DELETE requests, payload is empty
      final payloadHash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'; // SHA256 of empty string
      
      // Create canonical request for DELETE
      final canonicalUri = '/$objectKey';
      final canonicalQueryString = '';
      final canonicalHeaders = 'host:$_bucketName.s3.$_region.amazonaws.com\nx-amz-content-sha256:$payloadHash\nx-amz-date:$amzDate\n';
      final signedHeaders = 'host;x-amz-content-sha256;x-amz-date';
      
      final canonicalRequest = 'DELETE\n'
          '$canonicalUri\n'
          '$canonicalQueryString\n'
          '$canonicalHeaders\n'
          '$signedHeaders\n'
          '$payloadHash';
      
      // Create string to sign
      final algorithm = 'AWS4-HMAC-SHA256';
      final credentialScope = '$dateStamp/$_region/s3/aws4_request';
      final stringToSign = '$algorithm\n'
          '$amzDate\n'
          '$credentialScope\n'
          '${sha256.convert(utf8.encode(canonicalRequest)).toString()}';
      
      // Calculate signature
      final kSecret = utf8.encode('AWS4$_secretAccessKey');
      final kDate = _hmacSha256(kSecret, dateStamp);
      final kRegion = _hmacSha256(kDate, _region);
      final kService = _hmacSha256(kRegion, 's3');
      final kSigning = _hmacSha256(kService, 'aws4_request');
      final signatureBytes = _hmacSha256(kSigning, stringToSign);
      final signature = _bytesToHex(signatureBytes);
      
      // Create authorization header
      final authorization = '$algorithm '
          'Credential=$_accessKeyId/$credentialScope, '
          'SignedHeaders=$signedHeaders, '
          'Signature=$signature';
      
      // Send DELETE request
      final url = 'https://$_bucketName.s3.$_region.amazonaws.com/$objectKey';
      
      print('📤 Sending DELETE request to S3:');
      print('   URL: $url');
      
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'x-amz-content-sha256': payloadHash,
          'x-amz-date': amzDate,
          'Authorization': authorization,
        },
      );
      
      print('📥 S3 DELETE Response:');
      print('   Status: ${response.statusCode}');
      
      if (response.statusCode == 204 || response.statusCode == 200) {
        print('✅ Image deleted successfully from S3: $objectKey');
        return true;
      } else {
        print('❌ S3 delete failed: ${response.statusCode}');
        print('   Response body: ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ Error deleting image from S3: $e');
      print('   Stack trace: $stackTrace');
      return false;
    }
  }
  
  /// Extract the S3 object key from a URL
  /// Returns null if the URL format is not recognized
  static String? _extractObjectKeyFromUrl(String url) {
    try {
      // URL format: https://bucket.s3.region.amazonaws.com/key
      // or: https://s3.region.amazonaws.com/bucket/key
      final uri = Uri.parse(url);
      
      // Try format: https://bucket.s3.region.amazonaws.com/key
      if (uri.host.contains('.s3.') && uri.host.contains('amazonaws.com')) {
        // Path should be the object key (without leading slash)
        final path = uri.path;
        if (path.isNotEmpty && path.startsWith('/')) {
          return path.substring(1); // Remove leading slash
        }
        return path.isEmpty ? null : path;
      }
      
      // Try format: https://s3.region.amazonaws.com/bucket/key
      if (uri.host.startsWith('s3.') && uri.host.contains('amazonaws.com')) {
        final pathSegments = uri.pathSegments;
        if (pathSegments.length >= 2) {
          // First segment is bucket, rest is the key
          return pathSegments.sublist(1).join('/');
        }
      }
      
      print('⚠️ Could not parse S3 URL format: $url');
      return null;
    } catch (e) {
      print('❌ Error extracting object key from URL: $e');
      return null;
    }
  }

  /// Check if a URL is an S3 URL
  static bool isStorageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.contains('.s3.') || 
           url.contains('amazonaws.com') ||
           url.contains('s3.amazonaws.com');
  }

  /// Check if a path is a local file path (or blob URL on web that needs upload)
  static bool isLocalPath(String? path) {
    if (path == null || path.isEmpty) return false;
    // If it's already a storage URL, it's not local
    if (isStorageUrl(path)) return false;
    // For web: blob URLs are considered "local" (need upload)
    if (kIsWeb && path.startsWith('blob:')) return true;
    // For mobile: check if it's a file path
    return path.startsWith('/') || path.contains('\\');
  }

  // Helper methods for AWS signature
  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  static String _formatDateTime(DateTime date) {
    final dateStr = _formatDate(date);
    final timeStr = '${date.hour.toString().padLeft(2, '0')}${date.minute.toString().padLeft(2, '0')}${date.second.toString().padLeft(2, '0')}';
    return '${dateStr}T${timeStr}Z';
  }

  static List<int> _hmacSha256(List<int> key, String data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(utf8.encode(data)).bytes;
  }

  static String _bytesToHex(List<int> bytes) {
    return bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  }
}

