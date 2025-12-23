import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'add_listing_screen.dart';

import 'package:hive_flutter/hive_flutter.dart';
import '../models/listing.dart';
import '../widgets/buyer_listing_card.dart';
import 'seller_dashboard_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showFoodSafetyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Food Safety Policy",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Important Guidelines:",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 12),
                _buildPolicyItem(
                  Icons.check_circle,
                  Colors.green,
                  "All posted items must be in edible and safe condition",
                ),
                const SizedBox(height: 8),
                _buildPolicyItem(
                  Icons.check_circle,
                  Colors.green,
                  "Items should not cause any harm when consumed",
                ),
                const SizedBox(height: 8),
                _buildPolicyItem(
                  Icons.check_circle,
                  Colors.green,
                  "Comply with FSSAI (Food Safety and Standards Authority of India) regulations",
                ),
                const SizedBox(height: 8),
                _buildPolicyItem(
                  Icons.check_circle,
                  Colors.green,
                  "Follow proper food handling and storage guidelines",
                ),
                const SizedBox(height: 8),
                _buildPolicyItem(
                  Icons.check_circle,
                  Colors.green,
                  "Ensure accurate labeling and information disclosure",
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Text(
                    "By proceeding, you acknowledge that you have read and agree to comply with all food safety policies and government regulations.",
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddListingScreen(),
                  ),
                );
              },
              child: const Text("I Agree & Continue"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPolicyItem(IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {

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

      body: Column(
  children: [
     

    Expanded(
      child: ValueListenableBuilder(
        valueListenable:
            Hive.box<Listing>('listingBox').listenable(),
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
    ),
  ],
),
bottomNavigationBar: Container(
  decoration: BoxDecoration(
    color: Colors.white,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 10,
        offset: const Offset(0, -2),
      ),
    ],
  ),
  child: SafeArea(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline, size: 22),
              label: const Text(
                "Sell Food",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              onPressed: () {
                _showFoodSafetyPolicyDialog(context);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.dashboard_outlined, size: 22),
              label: const Text(
                "Seller Dashboard",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SellerDashboardScreen(
                      sellerId: 'local_seller_1',
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  ),
),




    );
  }
}

// floatingActionButton: FloatingActionButton.extended(
//   icon: const Icon(Icons.add),
//   label: const Text("Sell Food"),
//   backgroundColor: Colors.orange,
//   onPressed: () {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => const AddListingScreen(),
//       ),
//     );
//   },
// ),
//      body: 
     

     

//      ValueListenableBuilder(
//   valueListenable: Hive.box<Listing>('listingBox').listenable(),
//   builder: (context, Box<Listing> box, _) {
//     final listings = box.values.toList();

//     if (listings.isEmpty) {
//       return const Center(
//         child: Text(
//           "No food available right now 🍽️",
//           style: TextStyle(fontSize: 16),
//         ),
//       );
//     }

//     return ListView.builder(
//       padding: const EdgeInsets.all(16),
//       itemCount: listings.length,
//       itemBuilder: (context, index) {
//         return BuyerListingCard(
//           listing: listings[index],
//         );
//       },
//     );
//   },
// ),


// floatingActionButton: FloatingActionButton.extended(
//   icon: const Icon(Icons.add),
//   label: const Text("Sell Food"),
//   backgroundColor: Colors.orange,
//   onPressed: () {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => const AddListingScreen(),
//       ),
//     );
//   },
// ),



//     );
//   }
// }
