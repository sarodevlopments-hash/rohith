import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product_review.dart';
import '../models/seller_review.dart';
import 'star_rating_widget.dart';

/// Widget to display a product review card
class ProductReviewCard extends StatelessWidget {
  final ProductReview review;
  final VoidCallback? onHelpful;
  final bool isHelpful;
  final VoidCallback? onReply;

  const ProductReviewCard({
    super.key,
    required this.review,
    this.onHelpful,
    this.isHelpful = false,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Rating and date
            Row(
              children: [
                StarRatingWidget(
                  rating: review.rating,
                  size: 16,
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM dd, yyyy').format(review.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Review text
            if (review.reviewText != null) ...[
              Text(
                review.reviewText!,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
            ],
            // Review image
            if (review.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  review.imageUrl!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Seller reply
            if (review.sellerReply != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.store, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Seller Reply',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      review.sellerReply!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Actions: Helpful button
            Row(
              children: [
                TextButton.icon(
                  onPressed: onHelpful,
                  icon: Icon(
                    isHelpful ? Icons.thumb_up : Icons.thumb_up_outlined,
                    size: 16,
                    color: isHelpful ? Colors.blue : Colors.grey,
                  ),
                  label: Text(
                    'Helpful (${review.helpfulCount})',
                    style: TextStyle(
                      fontSize: 12,
                      color: isHelpful ? Colors.blue : Colors.grey.shade600,
                    ),
                  ),
                ),
                if (review.updatedAt != null) ...[
                  const Spacer(),
                  Text(
                    'Edited',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget to display a seller review card
class SellerReviewCard extends StatelessWidget {
  final SellerReview review;
  final VoidCallback? onReply;

  const SellerReviewCard({
    super.key,
    required this.review,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Rating and date
            Row(
              children: [
                StarRatingWidget(
                  rating: review.rating,
                  size: 16,
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM dd, yyyy').format(review.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            // Category ratings if available
            if (review.serviceRating != null ||
                review.deliveryRating != null ||
                review.packagingRating != null ||
                review.behaviorRating != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (review.serviceRating != null)
                    _buildCategoryRating('Service', review.serviceRating!),
                  if (review.deliveryRating != null)
                    _buildCategoryRating('Delivery', review.deliveryRating!),
                  if (review.packagingRating != null)
                    _buildCategoryRating('Packaging', review.packagingRating!),
                  if (review.behaviorRating != null)
                    _buildCategoryRating('Behavior', review.behaviorRating!),
                ],
              ),
            ],
            const SizedBox(height: 8),
            // Review text
            if (review.reviewText != null)
              Text(
                review.reviewText!,
                style: const TextStyle(fontSize: 14),
              ),
            if (review.updatedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Edited',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRating(String label, double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        StarRatingWidget(
          rating: rating,
          size: 12,
        ),
      ],
    );
  }
}

