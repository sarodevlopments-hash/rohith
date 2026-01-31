import 'package:flutter/material.dart';
import 'dart:ui';

/// Widget that conditionally shows seller name
/// - For groceries/vegetables: Shows blurred name before order confirmation, clear after
/// - For other types: Always shows clear name
class SellerNameWidget extends StatelessWidget {
  final String sellerName;
  final bool shouldHideSellerIdentity;
  final bool isOrderAccepted;
  final TextStyle? style;
  final String prefix;

  const SellerNameWidget({
    super.key,
    required this.sellerName,
    required this.shouldHideSellerIdentity,
    required this.isOrderAccepted,
    this.style,
    this.prefix = 'by ',
  });

  @override
  Widget build(BuildContext context) {
    // For groceries/vegetables: show blurred before confirmation, clear after
    if (shouldHideSellerIdentity) {
      if (isOrderAccepted) {
        // Order confirmed - show clear seller name
        return Text(
          '$prefix$sellerName',
          style: style ?? TextStyle(fontSize: 13, color: Colors.grey.shade600),
        );
      } else {
        // Order not confirmed - show blurred seller name
        return _buildBlurredText('$prefix$sellerName');
      }
    }

    // For other types: always show clear seller name
    return Text(
      '$prefix$sellerName',
      style: style ?? TextStyle(fontSize: 13, color: Colors.grey.shade600),
    );
  }

  Widget _buildBlurredText(String text) {
    // Create a blurred text effect - make seller name unreadable
    return ClipRect(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          child: Text(
            text,
            style: style ?? TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
      ),
    );
  }
}

