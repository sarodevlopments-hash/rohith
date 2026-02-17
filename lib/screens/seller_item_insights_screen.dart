import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/listing.dart';
import '../models/order.dart';
import '../models/product_review.dart';
import '../services/product_review_service.dart';

class SellerItemInsightsScreen extends StatefulWidget {
  final String sellerId;

  const SellerItemInsightsScreen({super.key, required this.sellerId});

  @override
  State<SellerItemInsightsScreen> createState() => _SellerItemInsightsScreenState();
}

class _SellerItemInsightsScreenState extends State<SellerItemInsightsScreen> {
  // Cache for product reviews to avoid repeated fetches
  final Map<String, List<ProductReview>> _reviewsCache = {};
  final Map<String, double> _ratingCache = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Item Insights',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Listing>('listingBox').listenable(),
        builder: (context, Box<Listing> listingBox, _) {
          return ValueListenableBuilder(
            valueListenable: Hive.box<Order>('ordersBox').listenable(),
            builder: (context, Box<Order> ordersBox, _) {
              // Get all listings for this seller (including live kitchen items)
              final myListings = listingBox.values
                  .where((l) => l.sellerId == widget.sellerId)
                  .toList();

              if (myListings.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No items posted yet',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: myListings.length,
                itemBuilder: (context, index) {
                  final listing = myListings[index];
                  final productId = listing.key.toString();
                  
                  // Get orders for this listing
                  final itemOrders = ordersBox.values
                      .where((o) => o.listingId == productId)
                      .toList();
                  final totalSold = itemOrders.fold<int>(0, (sum, o) => sum + o.quantity);
                  final revenue = itemOrders.fold<double>(0, (sum, o) => sum + o.pricePaid);

                  // Use cached rating if available, otherwise use listing's averageRating
                  double avgRating = _ratingCache[productId] ?? 
                      (listing.averageRating > 0 ? listing.averageRating : 0.0);

                  // Load reviews asynchronously if not cached
                  if (!_reviewsCache.containsKey(productId)) {
                    _loadProductReviews(productId);
                  }

                  final itemReviews = _reviewsCache[productId] ?? [];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                listing.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Show Live Kitchen badge if applicable
                            if (listing.isLiveKitchen) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.restaurant,
                                      size: 14,
                                      color: Colors.orange.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Live Kitchen',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInsightCard(
                                'Times Sold',
                                totalSold.toString(),
                                Icons.shopping_cart,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInsightCard(
                                'Revenue',
                                '₹${revenue.toStringAsFixed(0)}',
                                Icons.currency_rupee,
                                Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FutureBuilder<double>(
                                future: _getProductRating(productId, listing),
                                builder: (context, snapshot) {
                                  final rating = snapshot.data ?? avgRating;
                                  return _buildInsightCard(
                                    'Rating',
                                    rating > 0 ? rating.toStringAsFixed(1) : 'N/A',
                                    Icons.star,
                                    Colors.amber,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        if (itemReviews.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 12),
                          const Text(
                            'Reviews',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...itemReviews.take(3).map((review) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
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
                                          size: 14,
                                          color: Colors.amber,
                                        );
                                      }),
                                      const Spacer(),
                                      Text(
                                        _formatDate(review.createdAt),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (review.reviewText != null && review.reviewText!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      review.reviewText!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _loadProductReviews(String productId) async {
    try {
      final reviews = await ProductReviewService.getProductReviews(
        productId: productId,
        limit: 10,
        approvedOnly: true,
      );
      
      if (mounted) {
        setState(() {
          _reviewsCache[productId] = reviews;
          if (reviews.isNotEmpty) {
            final avgRating = reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
            _ratingCache[productId] = avgRating;
          }
        });
      }
    } catch (e) {
      print('Error loading reviews for product $productId: $e');
    }
  }

  Future<double> _getProductRating(String productId, Listing listing) async {
    // Return cached rating if available
    if (_ratingCache.containsKey(productId)) {
      return _ratingCache[productId]!;
    }

    // Use listing's averageRating if available
    if (listing.averageRating > 0) {
      return listing.averageRating;
    }

    // Try to fetch from Firestore
    try {
      final reviews = await ProductReviewService.getProductReviews(
        productId: productId,
        limit: 50,
        approvedOnly: true,
      );

      if (reviews.isNotEmpty) {
        final avgRating = reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
        _ratingCache[productId] = avgRating;
        return avgRating;
      }
    } catch (e) {
      print('Error fetching rating for product $productId: $e');
    }

    return 0.0;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildInsightCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
