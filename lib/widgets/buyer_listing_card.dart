import 'package:flutter/material.dart';
import '../models/listing.dart';
import '../models/sell_type.dart';
import '../models/food_category.dart';
import '../models/cooked_food_source.dart';
import '../models/sell_type.dart';
import '../models/listing.dart';
import 'package:hive/hive.dart'; // ADD THIS IMPORT


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
//            SizedBox(
//   width: double.infinity,
//   child: ElevatedButton(
//     onPressed: listing.quantity > 0
//         ? null
//         : () {
//             // 1️⃣ Reduce quantity
//             listing.quantity -= 1;

//             // 2️⃣ SAVE to Hive (THIS TRIGGERS REAL-TIME UPDATE)
//            listing.save();

//             // 3️⃣ Optional feedback
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text("Order placed")),
//             );
//           },
//     child: Text(
//       listing.quantity <= 0 ? "Sold Out" : "Buy",
//     ),
//   ),
// ),
SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: listing.quantity > 0
        ? () async {
            // 📦 1. Open Hive box
            final box = Hive.box<Listing>('listingBox');

            // 🔁 2. Create UPDATED listing
            final updatedListing = Listing(
              name: listing.name,
              sellerName: listing.sellerName,
              price: listing.price,
              originalPrice: listing.originalPrice,
              quantity: listing.quantity - 1,
              initialQuantity: listing.initialQuantity,
              type: listing.type,
              sellerId: listing.sellerId,
              fssaiLicense: listing.fssaiLicense,
              preparedAt: listing.preparedAt,
              expiryDate: listing.expiryDate,
              category: listing.category,
              cookedFoodSource: listing.cookedFoodSource,
            );

            // 💾 3. Save back to Hive (KEY IS IMPORTANT)
            await box.put(listing.key, updatedListing);

            // 🔔 4. Feedback
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Order placed")),
            );
          }
        : null,
    child: Text(
      listing.quantity > 0 ? "Buy" : "Sold Out",
    ),
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
