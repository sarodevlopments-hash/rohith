import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'models/listing.dart';

import 'models/order.dart';
import 'models/food_item.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/scheduled_listing_service.dart';
import 'services/accepted_order_notification_service.dart';
import 'models/sell_type.dart';
import 'models/food_category.dart';
import 'models/cooked_food_source.dart';
import 'models/seller_profile.dart';
import 'models/measurement_unit.dart';
import 'models/pack_size.dart';
import 'models/schedule_type.dart';
import 'models/scheduled_listing.dart';
import 'models/rating.dart';
import 'models/app_user.dart';
import 'auth/auth_gate.dart';
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
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
  Hive.registerAdapter(RatingAdapter());
  Hive.registerAdapter(AppUserAdapter());

  Hive.registerAdapter(FoodItemAdapter());
  Hive.registerAdapter(OrderAdapter());
  Hive.registerAdapter(ListingAdapter());
  Hive.registerAdapter(PackSizeAdapter());
  Hive.registerAdapter(ScheduleTypeAdapter());
  Hive.registerAdapter(ScheduledListingAdapter());

    // ✅ Open boxes (ONLY ONCE)
    await Hive.openBox<Listing>('listingBox');
    await Hive.openBox<FoodItem>('foodBox');
  await Hive.openBox<Order>('ordersBox');
  await Hive.openBox<int>('savedBox');
  await Hive.openBox('userBox');
  await Hive.openBox('sellerProfileBox');
  await Hive.openBox('ratingsBox');
    await Hive.openBox<AppUser>('usersBox');
    await Hive.openBox('cartBox');
    await Hive.openBox<ScheduledListing>('scheduledListingsBox');

    // ✅ Init local notifications (foreground/heads-up)
    await NotificationService.init();
    NotificationService.registerNavigatorKey(navigatorKey);
    AcceptedOrderNotificationService.setNavigatorKey(navigatorKey);

    // ✅ Start scheduled listing service
    ScheduledListingService.start();

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
                      await Hive.deleteBoxFromDisk('ratingsBox');
                      await Hive.deleteBoxFromDisk('usersBox');
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
      navigatorKey: navigatorKey,
      theme: ThemeData(primarySwatch: Colors.orange),
      // ✅ Auth-based navigation with OTP
      home: const AuthGate(),

    );
  }
}
