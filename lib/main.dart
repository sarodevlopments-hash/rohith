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
import 'models/clothing_category.dart';
import 'models/size_color_combination.dart';
import 'models/cooked_food_source.dart';
import 'models/seller_profile.dart';
import 'models/measurement_unit.dart';
import 'models/pack_size.dart';
import 'models/schedule_type.dart';
import 'models/scheduled_listing.dart';
import 'models/product_review.dart';
import 'models/seller_review.dart';
import 'models/rating.dart';
import 'models/app_user.dart';
import 'models/buyer_address.dart';
import 'auth/auth_gate.dart';
import 'theme/app_theme.dart';
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
    Hive.registerAdapter(ClothingCategoryAdapter());
    // Register SizeColorCombinationAdapter before ListingAdapter since Listing contains SizeColorCombination
    try {
      Hive.registerAdapter(SizeColorCombinationAdapter());
      print('SizeColorCombinationAdapter registered successfully');
    } catch (e) {
      print('Error registering SizeColorCombinationAdapter: $e');
      rethrow;
    }
    Hive.registerAdapter(CookedFoodSourceAdapter());
  Hive.registerAdapter(SellerProfileAdapter());
  Hive.registerAdapter(MeasurementUnitAdapter());
  Hive.registerAdapter(RatingAdapter());
  Hive.registerAdapter(AppUserAdapter());
  Hive.registerAdapter(BuyerAddressAdapter());

  Hive.registerAdapter(FoodItemAdapter());
  Hive.registerAdapter(OrderAdapter());
  Hive.registerAdapter(ListingAdapter());
  Hive.registerAdapter(PackSizeAdapter());
  Hive.registerAdapter(ScheduleTypeAdapter());
  Hive.registerAdapter(ScheduledListingAdapter());
  Hive.registerAdapter(ProductReviewAdapter());
  Hive.registerAdapter(SellerReviewAdapter());

    // ✅ Open boxes (ONLY ONCE) - All boxes must be opened here for persistence
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
    // ✅ Initialize recently viewed box for persistence
    await Hive.openBox<String>('recentlyViewedBox');
    // ✅ Track which accepted-order notifications have already been shown (buyer side)
    await Hive.openBox('acceptedOrderNotificationsBox');
    // ✅ Open box for seller verification status
    await Hive.openBox('sellerVerificationBox');
    // ✅ Open boxes for reviews
    await Hive.openBox<ProductReview>('productReviewsBox');
    await Hive.openBox<SellerReview>('sellerReviewsBox');

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
                      await Hive.deleteBoxFromDisk('cartBox');
                      await Hive.deleteBoxFromDisk('scheduledListingsBox');
                      await Hive.deleteBoxFromDisk('acceptedOrderNotificationsBox');
                      await Hive.deleteBoxFromDisk('recentlyViewedBox');
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
      theme: ThemeData(
        primaryColor: AppTheme.primaryColor,
        scaffoldBackgroundColor: AppTheme.backgroundColor,
        cardColor: AppTheme.cardColor,
        fontFamily: 'Roboto',
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: AppTheme.cardColor,
          foregroundColor: AppTheme.darkText,
          centerTitle: true,
          iconTheme: IconThemeData(color: AppTheme.darkText),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppTheme.backgroundColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppTheme.borderColor, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppTheme.borderColor, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppTheme.primaryColor, width: 2.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
      // ✅ Auth-based navigation with OTP
      home: const AuthGate(),

    );
  }
}
