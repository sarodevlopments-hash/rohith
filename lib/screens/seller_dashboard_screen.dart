import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/listing.dart';
// (We will create these pages later)
/// import 'seller_listings_screen.dart';
/// import 'seller_orders_screen.dart';

// 


class SellerDashboardScreen extends StatelessWidget {
  final String sellerId;

  const SellerDashboardScreen({super.key, required this.sellerId});

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text("Seller Dashboard")),
    body: ValueListenableBuilder(
      valueListenable: Hive.box<Listing>('listingBox').listenable(),
      builder: (context, Box<Listing> box, _) {
        // final myListings = box.values
        //     .where((l) => l.sellerId == sellerId)
        //     .toList();

        // int totalSold = 0;
        // double totalEarnings = 0;

        // for (final l in myListings) {
        //   final sold = l.initialQuantity - l.quantity;
        //   totalSold += sold;
        //   totalEarnings += sold * l.price;

         final myListings = box.values.toList();

          int totalSold = 0;
          double totalEarnings = 0;

          for (final l in myListings) {
            final sold = l.initialQuantity - l.quantity;
            totalSold += sold;
            totalEarnings += sold * l.price;
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// SUMMARY
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Total Listings: ${myListings.length}"),
                      Text("Items Sold: $totalSold"),
                      Text(
                        "Total Earnings: ₹${totalEarnings.toStringAsFixed(2)}",
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                "Your Listings",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: myListings.isEmpty
                    ? const Center(child: Text("No listings yet"))
                    : ListView.builder(
                        itemCount: myListings.length,
                        itemBuilder: (context, index) {
                          final l = myListings[index];
                          final sold =
                              l.initialQuantity - l.quantity;

                          return Card(
                            child: ListTile(
                              title: Text(l.name),
                              subtitle: Text(
                                "Price: ₹${l.price}\n"
                                "Sold: $sold / ${l.initialQuantity}\n"
                                "Remaining: ${l.quantity}",
                              ),
                              trailing: l.quantity == 0
                                  ? const Chip(
                                      label: Text("SOLD OUT"),
                                      backgroundColor: Colors.redAccent,
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    ),
  );
}


}
