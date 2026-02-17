import 'package:flutter/material.dart';

/// Widget for displaying and selecting star ratings
class StarRatingWidget extends StatelessWidget {
  final double rating;
  final double? size;
  final Color? color;
  final bool allowInteraction;
  final ValueChanged<double>? onRatingChanged;
  final bool showLabel;

  const StarRatingWidget({
    super.key,
    required this.rating,
    this.size = 24.0,
    this.color,
    this.allowInteraction = false,
    this.onRatingChanged,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Colors.amber;
    final effectiveSize = size ?? 24.0;

    Widget starWidget(int index) {
      final filledStars = rating.floor();
      final hasHalfStar = rating - filledStars >= 0.5;
      final isFilled = index < filledStars;
      final isHalf = index == filledStars && hasHalfStar;

      IconData iconData;
      Color starColor;

      if (isFilled) {
        iconData = Icons.star;
        starColor = effectiveColor;
      } else if (isHalf) {
        iconData = Icons.star_half;
        starColor = effectiveColor;
      } else {
        iconData = Icons.star_border;
        starColor = Colors.grey.shade300;
      }

      Widget star = Icon(
        iconData,
        size: effectiveSize,
        color: starColor,
      );

      if (allowInteraction && onRatingChanged != null) {
        return GestureDetector(
          onTap: () => onRatingChanged!(index + 1.0),
          child: star,
        );
      }

      return star;
    }

    final stars = Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) => starWidget(index)),
    );

    if (showLabel) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          stars,
          const SizedBox(width: 8),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: effectiveSize * 0.6,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      );
    }

    return stars;
  }
}

/// Interactive star rating selector
class StarRatingSelector extends StatefulWidget {
  final double initialRating;
  final ValueChanged<double>? onRatingChanged;
  final double? size;
  final Color? color;
  final bool showLabels;

  const StarRatingSelector({
    super.key,
    this.initialRating = 0.0,
    this.onRatingChanged,
    this.size = 32.0,
    this.color,
    this.showLabels = true,
  });

  @override
  State<StarRatingSelector> createState() => _StarRatingSelectorState();
}

class _StarRatingSelectorState extends State<StarRatingSelector> {
  late double _rating;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
  }

  String _getRatingLabel(double rating) {
    if (rating == 0) return 'Tap to rate';
    if (rating <= 1.5) return 'Poor';
    if (rating <= 2.5) return 'Fair';
    if (rating <= 3.5) return 'Average';
    if (rating <= 4.5) return 'Good';
    return 'Excellent';
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ?? Colors.amber;
    final effectiveSize = widget.size ?? 32.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starRating = index + 1.0;
            final isSelected = starRating <= _rating;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _rating = starRating;
                });
                widget.onRatingChanged?.call(starRating);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Icon(
                  isSelected ? Icons.star : Icons.star_border,
                  size: effectiveSize,
                  color: isSelected ? effectiveColor : Colors.grey.shade300,
                ),
              ),
            );
          }),
        ),
        if (widget.showLabels) ...[
          const SizedBox(height: 8),
          Text(
            _getRatingLabel(_rating),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }
}

