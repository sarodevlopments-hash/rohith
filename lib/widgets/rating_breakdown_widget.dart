import 'package:flutter/material.dart';

/// Widget to display rating breakdown with bars
class RatingBreakdownWidget extends StatelessWidget {
  final Map<int, int> breakdown; // {5: 70, 4: 20, 3: 5, 2: 2, 1: 3}
  final int totalReviews;
  final double? barHeight;
  final double? barWidth;

  const RatingBreakdownWidget({
    super.key,
    required this.breakdown,
    required this.totalReviews,
    this.barHeight = 8.0,
    this.barWidth = 150.0,
  });

  double _getPercentage(int rating) {
    if (totalReviews == 0) return 0.0;
    final count = breakdown[rating] ?? 0;
    return (count / totalReviews) * 100;
  }

  @override
  Widget build(BuildContext context) {
    if (totalReviews == 0) {
      return const Text(
        'No reviews yet',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(5, (index) {
        final rating = 5 - index; // 5, 4, 3, 2, 1
        final count = breakdown[rating] ?? 0;
        final percentage = _getPercentage(rating);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              // Star and rating number
              SizedBox(
                width: 40,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      size: 16,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$rating',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Progress bar
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    minHeight: barHeight,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getBarColor(rating),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Percentage and count
              SizedBox(
                width: 60,
                child: Text(
                  '${percentage.toStringAsFixed(0)}% ($count)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Color _getBarColor(int rating) {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.orange;
    return Colors.red;
  }
}

