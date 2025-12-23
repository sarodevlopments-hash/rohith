import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'models/listing.dart';

import 'models/order.dart';
import 'models/food_item.dart';
import 'screens/home_screen.dart';
import 'firebase_options.dart';
import 'models/sell_type.dart';
import 'models/food_category.dart';
import 'models/cooked_food_source.dart';
import 'models/seller_profile.dart';
import 'models/measurement_unit.dart';
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   // ✅ Initialize Firebase ONCE
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );

//   // ✅ Initialize Hive
//   await Hive.initFlutter();

//   Hive.registerAdapter(FoodItemAdapter());
//   Hive.registerAdapter(OrderAdapter());
//   Hive.registerAdapter(ListingAdapter());

// await Hive.openBox<Listing>('listingBox');


//   await Hive.openBox<FoodItem>('foodBox');
//   await Hive.openBox<Order>('ordersBox');
//   await Hive.openBox<int>('savedBox');
//   await Hive.openBox('userBox');
// await Hive.openBox<Listing>('listingBox');
//   runApp(const FoodApp());
// }
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // ✅ Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // ✅ Initialize Hive
    await Hive.initFlutter();

    // ✅ Register adapters
    Hive.registerAdapter(SellTypeAdapter());
    Hive.registerAdapter(FoodCategoryAdapter());
    Hive.registerAdapter(CookedFoodSourceAdapter());
    Hive.registerAdapter(SellerProfileAdapter());
    Hive.registerAdapter(MeasurementUnitAdapter());

    Hive.registerAdapter(FoodItemAdapter());
    Hive.registerAdapter(OrderAdapter());
    Hive.registerAdapter(ListingAdapter());

    // ✅ Open boxes (ONLY ONCE)
    await Hive.openBox<Listing>('listingBox');
    await Hive.openBox<FoodItem>('foodBox');
    await Hive.openBox<Order>('ordersBox');
    await Hive.openBox<int>('savedBox');
    await Hive.openBox('userBox');
    await Hive.openBox('sellerProfileBox');

    runApp(const FoodApp());
  } catch (e, stackTrace) {
    print('Error initializing app: $e');
    print('Stack trace: $stackTrace');
    // Run app anyway with error handling
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Error Initializing App',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Clear Data & Restart'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () async {
                    try {
                      // Close all boxes first
                      await Hive.close();
                      // Delete boxes from disk
                      await Hive.deleteBoxFromDisk('listingBox');
                      await Hive.deleteBoxFromDisk('foodBox');
                      await Hive.deleteBoxFromDisk('ordersBox');
                      await Hive.deleteBoxFromDisk('savedBox');
                      await Hive.deleteBoxFromDisk('userBox');
                      await Hive.deleteBoxFromDisk('sellerProfileBox');
                      // Restart the app
                      main();
                    } catch (deleteError) {
                      print('Error clearing data: $deleteError');
                      // Try to restart anyway
                      main();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

class FoodApp extends StatelessWidget {
  const FoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Food App',
      theme: ThemeData(primarySwatch: Colors.orange),
//***************do not remove this is for auth */
      // ✅ Auth-based navigation
      // home: StreamBuilder<User?>(
      //   stream: FirebaseAuth.instance.authStateChanges(),
      //   builder: (context, snapshot) {
      //     if (snapshot.connectionState == ConnectionState.waiting) {
      //       return const Scaffold(
      //         body: Center(child: CircularProgressIndicator()),
      //       );
      //     }

      //     if (snapshot.hasData) {
      //       return const HomeScreen();
      //     }

      //     return const LoginScreen();
      //   },
      // ),
      //home: const SellerDashboardScreen(sellerId: 'local_seller_1'),
       home: const HomeScreen(),

    );
  }
}
