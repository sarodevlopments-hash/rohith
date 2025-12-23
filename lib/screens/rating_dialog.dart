import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/listing.dart';
import '../models/order.dart';
import '../models/rating.dart';

class RatingDialog extends StatefulWidget {
  final Listing listing;
  final Order order;
  final VoidCallback onRated;

  const RatingDialog({
    super.key,
    required this.listing,
    required this.order,
    required this.onRated,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  double foodRating = 0;
  double sellerRating = 0;
  final reviewController = TextEditingController();

  @override
  void dispose() {
    reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (foodRating == 0 || sellerRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please rate both food and seller')),
      );
      return;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to rate')),
          );
        }
        return;
      }

      final ratingsBox = Hive.box('ratingsBox');
      final rating = Rating(
        listingId: widget.listing.key.toString(),
        sellerId: widget.listing.sellerId,
        foodRating: foodRating,
        sellerRating: sellerRating,
        review: reviewController.text.trim().isEmpty ? null : reviewController.text.trim(),
        buyerId: currentUser.uid,
        ratedAt: DateTime.now(),
      );

      await ratingsBox.add(rating);
      widget.onRated();
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your rating!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting rating: $e')),
        );
      }
    }
  }

  Widget _buildStarRating(String label, double rating, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return GestureDetector(
              onTap: () => onChanged(index + 1.0),
              child: Icon(
                index < rating ? Icons.star : Icons.star_border,
                color: Colors.orange,
                size: 40,
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          rating > 0 ? '${rating.toStringAsFixed(1)} / 5.0' : 'Tap to rate',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate Your Purchase'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStarRating('Food Quality', foodRating, (value) {
              setState(() => foodRating = value);
            }),
            const SizedBox(height: 24),
            _buildStarRating('Seller Service', sellerRating, (value) {
              setState(() => sellerRating = value);
            }),
            const SizedBox(height: 24),
            TextField(
              controller: reviewController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Review (Optional)',
                hintText: 'Share your experience...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Skip'),
        ),
        ElevatedButton(
          onPressed: _submitRating,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

