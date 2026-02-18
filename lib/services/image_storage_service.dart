import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 's3_storage_service.dart';
import '../models/listing.dart';

/// Service to handle image uploads and downloads
/// Now uses AWS S3 instead of Firebase Storage
class ImageStorageService {

  /// Upload a single image to S3
  /// Returns the download URL if successful, null otherwise
  static Future<String?> uploadImage({
    required String localPath,
    Uint8List? imageBytes, // For web
    required String sellerId,
    String? listingId,
    String? colorName, // For color-specific images
  }) async {
    // Delegate to S3StorageService
    return await S3StorageService.uploadImage(
      localPath: localPath,
      imageBytes: imageBytes,
      sellerId: sellerId,
      listingId: listingId,
      colorName: colorName,
    );
  }

  /// Upload multiple color images
  /// Returns a map of colorName -> download URL
  static Future<Map<String, String>> uploadColorImages({
    required Map<String, String> colorImagePaths,
    Map<String, Uint8List>? colorImageBytes, // For web
    required String sellerId,
    String? listingId,
  }) async {
    // Delegate to S3StorageService
    return await S3StorageService.uploadColorImages(
      colorImagePaths: colorImagePaths,
      colorImageBytes: colorImageBytes,
      sellerId: sellerId,
      listingId: listingId,
    );
  }

  /// Upload a document (PDF, JPG, PNG) to S3 for grocery onboarding
  /// Returns the download URL if successful, null otherwise
  static Future<String?> uploadDocument({
    required String documentType,
    String? localPath,
    Uint8List? documentBytes, // For web
    required String sellerId,
  }) async {
    // Delegate to S3StorageService
    return await S3StorageService.uploadDocument(
      documentType: documentType,
      localPath: localPath,
      documentBytes: documentBytes,
      sellerId: sellerId,
    );
  }

  /// Delete an image from S3
  static Future<bool> deleteImage(String imageUrl) async {
    // Delegate to S3StorageService
    return await S3StorageService.deleteImage(imageUrl);
  }

  /// Delete multiple images
  static Future<void> deleteImages(List<String> imageUrls) async {
    await Future.wait(
      imageUrls.map((url) => deleteImage(url)),
    );
  }

  /// Check if a URL is an S3 Storage URL
  static bool isStorageUrl(String? url) {
    // Delegate to S3StorageService
    return S3StorageService.isStorageUrl(url);
  }

  /// Check if a path is a local file path (not a Storage URL)
  static bool isLocalPath(String? path) {
    // Delegate to S3StorageService
    return S3StorageService.isLocalPath(path);
  }

  /// Delete images from S3 if listing quantity is 0 (out of stock)
  /// This should be called after updating listing quantity
  static Future<void> deleteImagesIfOutOfStock(Listing listing) async {
    // Only delete if quantity is 0 or less
    if (listing.quantity > 0) {
      return;
    }

    try {
      final List<String> imageUrls = [];
      
      // Add main product image if it's an S3 URL
      if (listing.imagePath != null && 
          isStorageUrl(listing.imagePath!)) {
        imageUrls.add(listing.imagePath!);
      }
      
      // Add color images if they exist
      if (listing.colorImages != null) {
        for (final colorImageUrl in listing.colorImages!.values) {
          if (isStorageUrl(colorImageUrl)) {
            imageUrls.add(colorImageUrl);
          }
        }
      }
      
      // Delete all images
      if (imageUrls.isNotEmpty) {
        print('🗑️ Listing "${listing.name}" is out of stock (quantity: 0). Deleting ${imageUrls.length} image(s) from S3...');
        await deleteImages(imageUrls);
        print('✅ All images deleted from S3 for out-of-stock listing: ${listing.name}');
      } else {
        print('ℹ️ No S3 images to delete for out-of-stock listing: ${listing.name}');
      }
    } catch (e) {
      print('⚠️ Error deleting images from S3 for out-of-stock listing (continuing): $e');
      // Don't throw - allow app to continue even if image deletion fails
    }
  }
}

