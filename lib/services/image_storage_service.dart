import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service to handle image uploads and downloads from Firebase Storage
class ImageStorageService {
  // Use the correct database ID: 'reqfood' (not the default)
  static FirebaseStorage get _storage => FirebaseStorage.instanceFor(
    app: Firebase.app(),
    bucket: 'resqfood-66b5f.firebasestorage.app',
  );

  /// Upload a single image to Firebase Storage
  /// Returns the download URL if successful, null otherwise
  static Future<String?> uploadImage({
    required String localPath,
    Uint8List? imageBytes, // For web
    required String sellerId,
    String? listingId,
    String? colorName, // For color-specific images
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != sellerId) {
        print('⚠️ Not authenticated or unauthorized to upload image for seller $sellerId');
        return null;
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = colorName != null
          ? '${sellerId}/listings/${listingId ?? 'temp'}/colors/${colorName}_$timestamp.jpg'
          : '${sellerId}/listings/${listingId ?? 'temp'}/product_$timestamp.jpg';

      // Create reference
      final ref = _storage.ref().child(fileName);

      // Upload based on platform
      if (kIsWeb) {
        // Web: Upload from bytes
        if (imageBytes == null) {
          print('❌ No image bytes provided for web upload');
          return null;
        }
        await ref.putData(
          imageBytes,
          SettableMetadata(
            contentType: 'image/jpeg',
            cacheControl: 'max-age=31536000', // Cache for 1 year
          ),
        );
      } else {
        // Mobile: Upload from file
        final file = File(localPath);
        if (!await file.exists()) {
          print('❌ Image file does not exist: $localPath');
          return null;
        }
        await ref.putFile(
          file,
          SettableMetadata(
            contentType: 'image/jpeg',
            cacheControl: 'max-age=31536000',
          ),
        );
      }

      // Get download URL
      final downloadUrl = await ref.getDownloadURL();
      print('✅ Image uploaded successfully: $fileName');
      print('   URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading image: $e');
      return null;
    }
  }

  /// Upload multiple color images
  /// Returns a map of colorName -> download URL
  static Future<Map<String, String>> uploadColorImages({
    required Map<String, String> colorImagePaths,
    Map<String, Uint8List>? colorImageBytes, // For web
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

  /// Delete an image from Storage
  static Future<bool> deleteImage(String imageUrl) async {
    try {
      // Extract path from URL
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      print('✅ Image deleted from Storage: $imageUrl');
      return true;
    } catch (e) {
      print('❌ Error deleting image: $e');
      return false;
    }
  }

  /// Delete multiple images
  static Future<void> deleteImages(List<String> imageUrls) async {
    await Future.wait(
      imageUrls.map((url) => deleteImage(url)),
    );
  }

  /// Check if a URL is a Firebase Storage URL
  static bool isStorageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.contains('firebasestorage.googleapis.com') ||
           url.contains('firebase.storage');
  }

  /// Check if a path is a local file path (not a Storage URL)
  static bool isLocalPath(String? path) {
    if (path == null || path.isEmpty) return false;
    return !isStorageUrl(path) && (path.startsWith('/') || path.contains('\\'));
  }
}

