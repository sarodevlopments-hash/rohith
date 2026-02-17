import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/seller_review.dart';
import '../services/seller_review_service.dart';
import 'package:intl/intl.dart';

class SellerReviewsScreen extends StatefulWidget {
  final String sellerId;

  const SellerReviewsScreen({super.key, required this.sellerId});

  @override
  State<SellerReviewsScreen> createState() => _SellerReviewsScreenState();
}

class _SellerReviewsScreenState extends State<SellerReviewsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Reviews',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: SellerReviewService.getSellerReviewsStream(
          sellerId: widget.sellerId,
          approvedOnly: true,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading reviews',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          var reviews = (snapshot.data?.docs ?? [])
              .map((doc) {
                final data = doc.data();
                data['id'] = doc.id; // Ensure ID is set
                return SellerReview.fromFirestore(data);
              })
              .toList();

          // Filter by approved status
          reviews = reviews.where((r) => r.isApproved).toList();
          
          // Sort by createdAt
          reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          // Limit to requested amount
          reviews = reviews.take(50).toList();

          if (reviews.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB703).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.star_border,
                      size: 40,
                      color: const Color(0xFFFFB703),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No reviews yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Customer reviews will appear here once buyers rate your products.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final avgRating = reviews
                  .map((r) => r.rating)
                  .reduce((a, b) => a + b) /
              reviews.length;

          return Column(
            children: [
              // Overall Rating Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Overall Seller Rating',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          avgRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: List.generate(5, (i) {
                                return Icon(
                                  i < avgRating.round()
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 24,
                                  color: Colors.amber,
                                );
                              }),
                            ),
                            Text(
                              '${reviews.length} review${reviews.length != 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Reviews List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    final review = reviews[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ...List.generate(5, (i) {
                                return Icon(
                                  i < review.rating.round()
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 20,
                                  color: Colors.amber,
                                );
                              }),
                              const Spacer(),
                              Text(
                                DateFormat('dd/MM/yyyy').format(review.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          if (review.reviewText != null && review.reviewText!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              review.reviewText!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                          // Show category ratings if available
                          if (review.serviceRating != null ||
                              review.deliveryRating != null ||
                              review.packagingRating != null ||
                              review.behaviorRating != null) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
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
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryRating(String label, double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          ...List.generate(5, (i) {
            return Icon(
              i < rating.round()
                  ? Icons.star
                  : Icons.star_border,
              size: 12,
              color: Colors.amber,
            );
          }),
        ],
      ),
    );
  }
}
