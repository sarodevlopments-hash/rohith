import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/order.dart';
import '../models/listing.dart';
import '../services/product_review_service.dart';
import '../widgets/star_rating_widget.dart';
import '../theme/app_theme.dart';
import '../services/image_storage_service.dart';

class WriteProductReviewScreen extends StatefulWidget {
  final Order order;
  final Listing listing;

  const WriteProductReviewScreen({
    super.key,
    required this.order,
    required this.listing,
  });

  @override
  State<WriteProductReviewScreen> createState() => _WriteProductReviewScreenState();
}

class _WriteProductReviewScreenState extends State<WriteProductReviewScreen> {
  double _rating = 0.0;
  final TextEditingController _reviewController = TextEditingController();
  File? _reviewImage;
  Uint8List? _reviewImageBytes;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          if (kIsWeb) {
            image.readAsBytes().then((bytes) {
              setState(() {
                _reviewImageBytes = bytes;
              });
            });
          } else {
            _reviewImage = File(image.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _reviewImage = null;
      _reviewImageBytes = null;
    });
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rating'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to submit a review'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Check if can review
      final canReview = await ProductReviewService.canReviewProduct(
        buyerId: currentUser.uid,
        productId: widget.order.listingId,
        orderId: widget.order.orderId,
      );

      if (!canReview) {
        throw Exception('You cannot review this product. Make sure the order is completed.');
      }

      // Submit review
      await ProductReviewService.submitReview(
        productId: widget.order.listingId,
        sellerId: widget.order.sellerId,
        buyerId: currentUser.uid,
        orderId: widget.order.orderId,
        rating: _rating,
        reviewText: _reviewController.text.trim().isEmpty 
            ? null 
            : _reviewController.text.trim(),
        imagePath: kIsWeb ? null : _reviewImage?.path,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Review submitted successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate review was submitted
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting review: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Write Product Review'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (widget.listing.imagePath != null && widget.listing.imagePath!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ImageStorageService.isStorageUrl(widget.listing.imagePath!)
                            ? CachedNetworkImage(
                                imageUrl: widget.listing.imagePath!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Center(
                                  child: SizedBox(
                                    height: 15,
                                    width: 15,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.image, color: Colors.grey),
                                ),
                              )
                            : (kIsWeb
                                ? Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.image, color: Colors.grey),
                                  )
                                : File(widget.listing.imagePath!).existsSync()
                                    ? Image.file(
                                        File(widget.listing.imagePath!),
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.image, color: Colors.grey),
                                      )),
                      )
                    else
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.listing.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.order.sellerName,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Rating Section
            Text(
              'Rate this product',
              style: AppTheme.heading4.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            StarRatingSelector(
              initialRating: _rating,
              onRatingChanged: (rating) {
                setState(() {
                  _rating = rating;
                });
              },
              size: 40,
            ),

            const SizedBox(height: 32),

            // Review Text
            Text(
              'Write a review (Optional)',
              style: AppTheme.heading4.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reviewController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Share your experience with this product...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),

            const SizedBox(height: 24),

            // Image Upload Section
            Text(
              'Add a photo (Optional)',
              style: AppTheme.heading4.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_reviewImage == null && _reviewImageBytes == null)
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Add Photo'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              )
            else
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb
                        ? Image.memory(
                            _reviewImageBytes!,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            _reviewImage!,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                      onPressed: _removeImage,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Submit Review',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

