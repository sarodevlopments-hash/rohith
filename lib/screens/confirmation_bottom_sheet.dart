import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../models/listing.dart';
import '../models/food_category.dart';

class ConfirmationBottomSheet extends StatelessWidget {
  final Listing listing;
  final int quantity;
  final VoidCallback onConfirm;

  const ConfirmationBottomSheet({
    super.key,
    required this.listing,
    required this.quantity,
    required this.onConfirm,
  });

  Color _getFoodTypeColor() {
    switch (listing.category) {
      case FoodCategory.veg:
        return Colors.green;
      case FoodCategory.egg:
        return Colors.orange;
      case FoodCategory.nonVeg:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPrice = listing.price * quantity;
    final originalTotal = listing.originalPrice != null
        ? listing.originalPrice! * quantity
        : totalPrice;
    final savings = originalTotal - totalPrice;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            const Text(
              'Confirm Order',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Product Image & Details
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey.shade200,
                    child: listing.imagePath != null
                        ? (kIsWeb
                            ? FutureBuilder<Uint8List>(
                                future: _loadImageBytes(listing.imagePath!),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return Image.memory(
                                      snapshot.data!,
                                      fit: BoxFit.cover,
                                    );
                                  }
                                  return const Center(child: CircularProgressIndicator());
                                },
                              )
                            : File(listing.imagePath!).existsSync()
                                ? Image.file(
                                    File(listing.imagePath!),
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(Icons.fastfood))
                        : const Icon(Icons.fastfood, size: 40),
                  ),
                ),
                const SizedBox(width: 16),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'by ${listing.sellerName}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getFoodTypeColor(),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          listing.category.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Divider(),

            // Price Breakdown
            const Text(
              'Price Breakdown',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            _buildPriceRow('Quantity', '$quantity x ₹${listing.price.toStringAsFixed(0)}'),
            if (listing.originalPrice != null)
              _buildPriceRow(
                'Original Price',
                '₹${originalTotal.toStringAsFixed(0)}',
                isStrikethrough: true,
              ),
            _buildPriceRow('Discounted Price', '₹${totalPrice.toStringAsFixed(0)}'),
            if (savings > 0)
              _buildPriceRow(
                'Total Savings',
                '₹${savings.toStringAsFixed(0)}',
                isHighlight: true,
                color: Colors.green,
              ),

            const SizedBox(height: 20),
            const Divider(),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '₹${totalPrice.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  onConfirm();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Confirm Order',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value,
      {bool isStrikethrough = false, bool isHighlight = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isHighlight ? (color ?? Colors.green) : Colors.grey.shade700,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              decoration: isStrikethrough ? TextDecoration.lineThrough : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: isHighlight ? (color ?? Colors.green) : Colors.black87,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              decoration: isStrikethrough ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _loadImageBytes(String imagePath) async {
    if (kIsWeb) {
      final XFile file = XFile(imagePath);
      return await file.readAsBytes();
    } else {
      final File file = File(imagePath);
      return await file.readAsBytes();
    }
  }
}

