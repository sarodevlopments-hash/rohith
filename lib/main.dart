import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/listing.dart';

import 'models/order.dart';
import 'models/food_item.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'firebase_options.dart';
import 'models/sell_type.dart';
import 'models/food_category.dart';
import 'models/cooked_food_source.dart';


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

  // ✅ Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Initialize Hive
  await Hive.initFlutter();

  // ✅ Register adapters

  Hive.registerAdapter(SellTypeAdapter());
  //Hive.registerAdapter(FoodCategoryAdapter());
  Hive.registerAdapter(CookedFoodSourceAdapter());

  Hive.registerAdapter(FoodItemAdapter());
  Hive.registerAdapter(OrderAdapter());
  Hive.registerAdapter(ListingAdapter());

  // ✅ Open boxes (ONLY ONCE)
  await Hive.openBox<Listing>('listingBox');
  await Hive.openBox<FoodItem>('foodBox');
  await Hive.openBox<Order>('ordersBox');
  await Hive.openBox<int>('savedBox');
  await Hive.openBox('userBox');

  runApp(const FoodApp());
}

class FoodApp extends StatelessWidget {
  const FoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Food App',
      theme: ThemeData(primarySwatch: Colors.orange),

      // ✅ Auth-based navigation
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            return const HomeScreen();
          }

          return const LoginScreen();
        },
      ),
    );
  }
}
