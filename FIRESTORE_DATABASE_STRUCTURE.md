# Firestore Database Structure

## ✅ Currently Stored in Firestore

Your app is already configured to store the following data in Firestore:

### 1. **Listings Collection** (`listings`)
**What it stores:** All product listings created by sellers

**Document Structure:**
```javascript
{
  key: "1234567890",                    // Listing ID
  name: "Fresh Tomatoes",               // Product name
  price: 50.0,                          // Current price
  originalPrice: 60.0,                  // Original price (for discount)
  quantity: 10,                         // Available quantity
  initialQuantity: 10,                  // Initial stock
  type: "groceries",                    // SellType enum
  category: "veg",                      // FoodCategory enum
  clothingCategory: null,               // For clothing items
  description: "Fresh organic tomatoes",
  imagePath: "/path/to/image.jpg",
  sellerId: "user123",                  // Firebase Auth UID
  sellerName: "John's Store",
  cookedFoodSource: "home",             // For cooked food
  fssaiLicense: "123456789",           // FSSAI license number
  preparedAt: Timestamp,                // When food was prepared
  expiryDate: Timestamp,               // Expiry date
  measurementUnit: "kilograms",         // For groceries/vegetables
  packSizes: [                          // Multiple pack sizes
    { quantity: 5.0, price: 100.0, label: "5kg Pack" },
    { quantity: 1.0, price: 25.0, label: "1kg Pack" }
  ],
  isBulkFood: false,                    // Bulk/catering item
  servesCount: null,                    // Number of people served
  portionDescription: null,             // "Full handi", etc.
  isLiveKitchen: false,                 // Live kitchen item
  isKitchenOpen: false,                 // Kitchen accepting orders
  preparationTimeMinutes: null,        // Prep time for live kitchen
  maxCapacity: null,                    // Max orders capacity
  currentOrders: 0,                     // Current pending orders
  availableSizes: ["S", "M", "L"],     // For clothing
  availableColors: ["Red", "Blue"],    // For clothing
  sizeColorCombinations: [              // Size-color combos
    { size: "M", availableColors: ["Red", "Blue"] }
  ],
  colorImages: {                        // Color-specific images
    "Red": "/path/to/red.jpg",
    "Blue": "/path/to/blue.jpg"
  },
  updatedAt: Timestamp                  // Last update time
}
```

**When it's created:**
- ✅ Automatically when seller creates a listing
- ✅ Synced to Firestore in background
- ✅ Restored on app restart

---

### 2. **Orders Collection** (`orders`)
**What it stores:** All orders placed by buyers

**Document Structure:**
```javascript
{
  orderId: "1770042901841",             // Unique order ID
  foodName: "Fresh Tomatoes",           // Product name
  sellerName: "John's Store",          // Seller name
  pricePaid: 50.0,                      // Final price paid
  savedAmount: 10.0,                    // Discount amount saved
  purchasedAt: Timestamp,               // Order timestamp
  listingId: "1234567890",             // Reference to listing
  quantity: 2,                          // Quantity ordered
  originalPrice: 60.0,                  // Original price
  discountedPrice: 50.0,                // Discounted price
  userId: "buyer123",                   // Buyer's Firebase Auth UID
  sellerId: "seller123",                // Seller's Firebase Auth UID
  orderStatus: "AwaitingSellerConfirmation", // Order status
  paymentCompletedAt: Timestamp,        // Payment time
  sellerRespondedAt: Timestamp,         // Seller response time
  paymentMethod: "Cash",                // Payment method
  selectedPackQuantity: 5.0,            // Selected pack size
  selectedPackPrice: 100.0,             // Pack price
  selectedPackLabel: "5kg Pack",        // Pack label
  selectedSize: "M",                     // For clothing
  selectedColor: "Red",                  // For clothing
  updatedAt: Timestamp                  // Last update time
}
```

**Order Statuses:**
- `PaymentPending` - Payment not completed
- `AwaitingSellerConfirmation` - Waiting for seller to accept
- `AcceptedBySeller` - Seller accepted the order
- `RejectedBySeller` - Seller rejected the order
- `Completed` - Order completed
- `Cancelled` - Order cancelled

**When it's created:**
- ✅ Automatically when buyer places an order
- ✅ Synced to Firestore immediately
- ✅ Real-time updates via `OrderSyncService`

---

## 🚀 Additional Data You Can Store

Here are other things you can add to Firestore:

### 3. **User Profiles Collection** (`userProfiles`)
**What it could store:** Extended user information

```javascript
{
  userId: "user123",                    // Firebase Auth UID
  email: "user@example.com",
  phoneNumber: "+1234567890",
  displayName: "John Doe",
  profileImageUrl: "https://...",
  address: {
    street: "123 Main St",
    city: "Mumbai",
    state: "Maharashtra",
    pincode: "400001",
    coordinates: { lat: 19.0760, lng: 72.8777 }
  },
  preferences: {
    favoriteCategories: ["groceries", "vegetables"],
    notificationSettings: { email: true, push: true }
  },
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### 4. **Seller Profiles Collection** (`sellerProfiles`)
**What it could store:** Seller-specific information

```javascript
{
  sellerId: "seller123",                // Firebase Auth UID
  businessName: "John's Fresh Store",
  businessType: "individual",           // individual, restaurant, etc.
  fssaiLicense: "123456789",
  address: {
    street: "123 Main St",
    city: "Mumbai",
    state: "Maharashtra",
    pincode: "400001",
    coordinates: { lat: 19.0760, lng: 72.8777 }
  },
  pickupLocation: "123 Main St, Mumbai",
  phoneNumber: "+1234567890",
  businessHours: {
    monday: { open: "09:00", close: "18:00" },
    tuesday: { open: "09:00", close: "18:00" },
    // ... other days
  },
  rating: 4.5,                          // Average rating
  totalRatings: 120,                    // Number of ratings
  isVerified: false,                    // Verified seller badge
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### 5. **Ratings Collection** (`ratings`)
**What it could store:** Product and seller ratings

```javascript
{
  ratingId: "rating123",
  userId: "buyer123",                   // Who gave the rating
  sellerId: "seller123",                // Seller being rated
  listingId: "1234567890",             // Product being rated
  orderId: "1770042901841",            // Related order
  rating: 5,                            // 1-5 stars
  comment: "Great quality, fast delivery!",
  images: ["url1", "url2"],             // Review images
  helpfulCount: 5,                      // Helpful votes
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### 6. **Cart Items Collection** (`carts`)
**What it could store:** User shopping carts (for multi-device sync)

```javascript
{
  userId: "buyer123",                   // Firebase Auth UID
  items: [
    {
      listingId: "1234567890",
      quantity: 2,
      selectedPackSize: "5kg Pack",
      selectedSize: "M",
      selectedColor: "Red",
      addedAt: Timestamp
    }
  ],
  updatedAt: Timestamp
}
```

### 7. **Scheduled Listings Collection** (`scheduledListings`)
**What it could store:** Listings scheduled for future posting

```javascript
{
  scheduledId: "sched123",
  sellerId: "seller123",
  listingData: { /* full listing object */ },
  scheduleType: "daily",                 // daily, weekly, oneTime
  scheduleStartDate: Timestamp,
  scheduleEndDate: Timestamp,
  scheduleTime: "09:00",                // Post time
  scheduleCloseTime: "18:00",           // Close time
  dayOfWeek: 1,                         // For weekly (1=Monday)
  isActive: true,
  lastPostedAt: Timestamp,
  createdAt: Timestamp
}
```

### 8. **Notifications Collection** (`notifications`)
**What it could store:** Push notification history

```javascript
{
  notificationId: "notif123",
  userId: "user123",
  type: "order_accepted",               // order_accepted, new_order, etc.
  title: "Order Accepted",
  body: "Your order has been accepted by the seller",
  data: {
    orderId: "1770042901841",
    listingId: "1234567890"
  },
  read: false,
  createdAt: Timestamp
}
```

### 9. **Recently Viewed Collection** (`recentlyViewed`)
**What it could store:** User browsing history (for cross-device sync)

```javascript
{
  userId: "buyer123",
  listingId: "1234567890",
  viewedAt: Timestamp
}
```

---

## 📊 Database Structure Summary

```
Firestore Database
├── listings/              ✅ Currently syncing
│   └── {listingId}/      (All product listings)
│
├── orders/                ✅ Currently syncing
│   └── {orderId}/         (All orders)
│
├── userProfiles/          🔄 Can be added
│   └── {userId}/          (User information)
│
├── sellerProfiles/        🔄 Can be added
│   └── {sellerId}/        (Seller business info)
│
├── ratings/               🔄 Can be added
│   └── {ratingId}/        (Product/seller ratings)
│
├── carts/                 🔄 Can be added
│   └── {userId}/          (Shopping carts)
│
├── scheduledListings/      🔄 Can be added
│   └── {scheduledId}/    (Scheduled posts)
│
├── notifications/         🔄 Can be added
│   └── {notificationId}/ (Notification history)
│
└── recentlyViewed/        🔄 Can be added
    └── {userId_listingId}/ (Browsing history)
```

---

## 🔧 How to Add New Collections

To add any of these collections:

1. **Create a Service** (similar to `ListingFirestoreService`)
2. **Add Security Rules** in `firestore.rules`
3. **Sync from Hive** (if data exists locally)
4. **Update UI** to read from Firestore

**Example:** To add `userProfiles` collection:

```dart
// lib/services/user_profile_firestore_service.dart
class UserProfileFirestoreService {
  static final _db = FirebaseFirestore.instance;
  
  static Future<void> saveProfile(UserProfile profile) async {
    await _db.collection('userProfiles')
        .doc(profile.userId)
        .set(profile.toMap());
  }
  
  static Future<UserProfile?> getProfile(String userId) async {
    final doc = await _db.collection('userProfiles')
        .doc(userId)
        .get();
    return doc.exists ? UserProfile.fromMap(doc.data()!) : null;
  }
}
```

Then add to security rules:
```javascript
match /userProfiles/{userId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow write: if request.auth != null && request.auth.uid == userId;
}
```

---

## ✅ Current Status

- ✅ **Listings**: Fully synced to Firestore
- ✅ **Orders**: Fully synced to Firestore with real-time updates
- 🔄 **Other collections**: Can be added as needed

Your database is ready to store listings and orders. Additional collections can be added when you need cross-device sync or cloud backup for other data!

