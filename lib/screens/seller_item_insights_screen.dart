import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/listing.dart';
import '../models/order.dart';
import '../models/rating.dart';

class SellerItemInsightsScreen extends StatelessWidget {
  final String sellerId;

  const SellerItemInsightsScreen({super.key, required this.sellerId});

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
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Listing>('listingBox').listenable(),
        builder: (context, Box<Listing> listingBox, _) {
          return ValueListenableBuilder(
            valueListenable: Hive.box<Order>('ordersBox').listenable(),
            builder: (context, Box<Order> ordersBox, _) {
              return ValueListenableBuilder(
                valueListenable: Hive.box('ratingsBox').listenable(),
                builder: (context, Box ratingsBox, _) {
                  final myListings = listingBox.values
                      .where((l) => l.sellerId == sellerId)
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
                      final itemOrders = ordersBox.values
                          .where((o) => o.listingId == listing.key.toString())
                          .toList();
                      final totalSold = itemOrders.fold<int>(0, (sum, o) => sum + o.quantity);
                      final revenue = itemOrders.fold<double>(0, (sum, o) => sum + o.pricePaid);

                      final itemRatings = ratingsBox.values
                          .where((r) => r is Rating && r.listingId == listing.key.toString())
                          .cast<Rating>()
                          .toList();
                      final avgRating = itemRatings.isEmpty
                          ? 0.0
                          : itemRatings.map((r) => r.foodRating).reduce((a, b) => a + b) /
                              itemRatings.length;

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
                            Text(
                              listing.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
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
                                  child: _buildInsightCard(
                                    'Rating',
                                    avgRating > 0 ? avgRating.toStringAsFixed(1) : 'N/A',
                                    Icons.star,
                                    Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                            if (itemRatings.isNotEmpty) ...[
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
                              ...itemRatings.take(3).map((rating) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      ...List.generate(5, (i) {
                                        return Icon(
                                          i < rating.foodRating
                                              ? Icons.star
                                              : Icons.star_border,
                                          size: 14,
                                          color: Colors.amber,
                                        );
                                      }),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          rating.review ?? 'No review',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
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
          );
        },
      ),
    );
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

