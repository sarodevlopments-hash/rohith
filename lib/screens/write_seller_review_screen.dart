import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order.dart';
import '../services/seller_review_service.dart';
import '../widgets/star_rating_widget.dart';
import '../theme/app_theme.dart';

class WriteSellerReviewScreen extends StatefulWidget {
  final Order order;

  const WriteSellerReviewScreen({
    super.key,
    required this.order,
  });

  @override
  State<WriteSellerReviewScreen> createState() => _WriteSellerReviewScreenState();
}

class _WriteSellerReviewScreenState extends State<WriteSellerReviewScreen> {
  double _overallRating = 0.0;
  double? _serviceRating;
  double? _deliveryRating;
  double? _packagingRating;
  double? _behaviorRating;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;
  bool _showCategoryRatings = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_overallRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an overall rating'),
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
      final canReview = await SellerReviewService.canReviewSeller(
        buyerId: currentUser.uid,
        sellerId: widget.order.sellerId,
        orderId: widget.order.orderId,
      );

      if (!canReview) {
        throw Exception('You cannot review this seller. Make sure the order is completed.');
      }

      // Submit review
      await SellerReviewService.submitReview(
        sellerId: widget.order.sellerId,
        buyerId: currentUser.uid,
        orderId: widget.order.orderId,
        rating: _overallRating,
        reviewText: _reviewController.text.trim().isEmpty 
            ? null 
            : _reviewController.text.trim(),
        serviceRating: _serviceRating,
        deliveryRating: _deliveryRating,
        packagingRating: _packagingRating,
        behaviorRating: _behaviorRating,
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
        title: const Text('Write Seller Review'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seller Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.store,
                        color: AppTheme.primaryColor,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.order.sellerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Order #${widget.order.orderId.substring(widget.order.orderId.length - 6)}',
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

            // Overall Rating
            Text(
              'Overall Rating',
              style: AppTheme.heading4.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            StarRatingSelector(
              initialRating: _overallRating,
              onRatingChanged: (rating) {
                setState(() {
                  _overallRating = rating;
                });
              },
              size: 40,
            ),

            const SizedBox(height: 24),

            // Category Ratings Toggle
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Add detailed ratings (Optional)',
                    style: AppTheme.heading4.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: _showCategoryRatings,
                  onChanged: (value) {
                    setState(() {
                      _showCategoryRatings = value;
                      if (!value) {
                        _serviceRating = null;
                        _deliveryRating = null;
                        _packagingRating = null;
                        _behaviorRating = null;
                      }
                    });
                  },
                ),
              ],
            ),

            if (_showCategoryRatings) ...[
              const SizedBox(height: 16),
              _buildCategoryRating(
                'Service',
                _serviceRating,
                (rating) => setState(() => _serviceRating = rating),
              ),
              const SizedBox(height: 16),
              _buildCategoryRating(
                'Delivery',
                _deliveryRating,
                (rating) => setState(() => _deliveryRating = rating),
              ),
              const SizedBox(height: 16),
              _buildCategoryRating(
                'Packaging',
                _packagingRating,
                (rating) => setState(() => _packagingRating = rating),
              ),
              const SizedBox(height: 16),
              _buildCategoryRating(
                'Behavior',
                _behaviorRating,
                (rating) => setState(() => _behaviorRating = rating),
              ),
            ],

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
                hintText: 'Share your experience with this seller...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
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

  Widget _buildCategoryRating(
    String label,
    double? rating,
    ValueChanged<double> onRatingChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        StarRatingSelector(
          initialRating: rating ?? 0.0,
          onRatingChanged: onRatingChanged,
          size: 32,
          showLabels: false,
        ),
      ],
    );
  }
}

