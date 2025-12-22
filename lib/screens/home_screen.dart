import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'add_listing_screen.dart';
import 'order_history_screen.dart';
import 'profile_screen.dart';

import 'package:hive_flutter/hive_flutter.dart';
import '../models/listing.dart';
import '../widgets/buyer_listing_card.dart';


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Food App"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
     body: ValueListenableBuilder(
  valueListenable: Hive.box<Listing>('listingBox').listenable(),
  builder: (context, Box<Listing> box, _) {
    final listings = box.values.toList();

    if (listings.isEmpty) {
      return const Center(
        child: Text(
          "No food available right now 🍽️",
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: listings.length,
      itemBuilder: (context, index) {
        return BuyerListingCard(
          listing: listings[index],
        );
      },
    );
  },
),
floatingActionButton: FloatingActionButton.extended(
  icon: const Icon(Icons.add),
  label: const Text("Sell Food"),
  backgroundColor: Colors.orange,
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddListingScreen(),
      ),
    );
  },
),

    );
  }
}
