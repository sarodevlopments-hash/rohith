import 'package:flutter/material.dart';
import '../models/listing.dart';
import '../models/sell_type.dart';
import '../models/food_category.dart';
import '../models/cooked_food_source.dart';
import '../models/sell_type.dart';
import '../models/listing.dart';


class BuyerListingCard extends StatelessWidget {
  final Listing listing;

  const BuyerListingCard({super.key, required this.listing});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 🔹 TITLE + PRICE
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  listing.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "₹${listing.price}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // 🔹 SELLER
            Text(
              "Seller: ${listing.sellerName}",
              style: const TextStyle(fontSize: 13),
            ),

            const SizedBox(height: 8),

            // 🔹 TAGS
            Wrap(
              spacing: 8,
              children: [
                _tag(listing.category.label, Colors.orange),

                if (listing.type == SellType.cookedFood &&
                    listing.cookedFoodSource != null)
                  _tag(
                    listing.cookedFoodSource!.label,
                    Colors.blue,
                  ),

                if (listing.type == SellType.cookedFood &&
                    listing.fssaiLicense != null)
                  _tag("FSSAI", Colors.green),
              ],
            ),

            const SizedBox(height: 10),

            // 🔹 EXPIRY
            if (listing.expiryDate != null)
              Text(
                "Expires at: ${listing.expiryDate}",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade700,
                ),
              ),

            const SizedBox(height: 10),

            // 🔹 BUY BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text("Buy"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Chip(
      label: Text(
        text,
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: color.withOpacity(0.15),
      side: BorderSide(color: color),
    );
  }
}
