# Owner Dashboard Setup Guide

## Overview

The Owner Dashboard is a comprehensive admin-only web dashboard for monitoring your multi-category marketplace app. It provides real-time metrics, insights, and analytics across all aspects of your business.

## Features

✅ **KPI Overview** - 8 key performance indicators with trend indicators
✅ **Growth & Activity Charts** - Visual analytics for users, orders, and revenue
✅ **Seller Insights** - Comprehensive seller performance metrics and tables
✅ **Buyer Insights** - Buyer behavior patterns and analytics
✅ **Product Performance** - Top products, categories, and peak ordering times
✅ **Platform Health** - Real-time alerts and health monitoring

## Setup Instructions

### 1. Set Owner Role for Your Account

To access the Owner Dashboard, you need to set your user role to `'owner'` in Firestore:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Navigate to **Firestore Database**
3. Find your user document in the `userProfiles` collection (use your Firebase Auth UID)
4. Add or update the `role` field to `"owner"`:

```json
{
  "uid": "your-user-id",
  "fullName": "Your Name",
  "email": "your@email.com",
  "role": "owner",  // ← Add this field
  "isRegistered": true,
  ...
}
```

**Alternative Method (Using Code):**

You can also set the role programmatically:

```dart
final userService = UserService();
final appUser = await userService.getUser('your-user-id');
if (appUser != null) {
  final ownerUser = appUser.copyWith(role: 'owner');
  await userService.saveUser(ownerUser);
}
```

### 2. Update Firestore Rules

The Firestore rules have been updated to allow owner access. Make sure to publish them:

1. Go to [Firestore Rules](https://console.firebase.google.com/project/resqfood-66b5f/firestore/rules)
2. Verify the rules include owner access checks
3. Click **"Publish"** (not just "Save")
4. Wait 1-2 minutes for propagation

### 3. Access the Dashboard

#### Option A: Web Browser (Recommended)

1. Build and run your Flutter app for web:
   ```bash
   flutter build web
   flutter run -d chrome
   ```

2. Log in with your owner account
3. You will be automatically redirected to the Owner Dashboard

#### Option B: Direct Route

If you want to access the dashboard directly, you can navigate to:
- URL: `/owner-dashboard` (if you set up named routes)
- Or modify `AuthGate` to always show dashboard for testing

### 4. Dashboard Sections

#### 📊 KPI Overview
- Total Registered Users
- Total Sellers
- Total Buyers
- Active Users (Today)
- Total Orders (with % change)
- Total Revenue (with % change)
- Orders Today
- Cancelled Orders

#### 📈 Growth & Activity Charts
- **New Users per Day** - Line chart showing user growth
- **Orders per Day** - Line chart showing order trends
- **Revenue per Day** - Bar chart showing daily revenue

#### 🧑‍💼 Seller Insights
- Active sellers (last 7 days)
- Inactive sellers
- New sellers pending approval
- Regular sellers count
- Top sellers table with:
  - Seller name
  - Type (Farmer/Regular/Casual)
  - Total items listed
  - Total orders
  - Revenue generated
  - Status (Active/Inactive)

#### 🛍 Buyer Insights
- Repeat buyers count
- Average orders per buyer
- New buyers today
- Buyers with no orders
- Pie chart: New vs Returning buyers

#### 🍅 Product & Category Performance
- Top categories (Food, Veg, Grocery, Clothing)
- Top 10 selling products table
- Peak ordering time (Morning/Afternoon/Evening)
- Product performance metrics

#### ⚠️ Platform Health & Alerts
- Failed payments today
- High cancellation rate sellers
- Reported products
- Out-of-stock alerts

### 5. Date Range Filtering

The dashboard supports multiple date ranges:
- **Today** - Current day metrics
- **Last 7 Days** - Week-over-week comparison
- **Last 30 Days** - Month-over-month comparison
- **Custom Range** - Select any date range

### 6. Responsive Design

The dashboard is optimized for:
- **Desktop** (1024px+) - Full layout with side-by-side charts
- **Tablet** (768px-1024px) - Responsive grid layout
- **Mobile** (< 768px) - Stacked layout

## Security

- ✅ Only users with `role: 'owner'` can access the dashboard
- ✅ Firestore rules enforce owner-only read access to all collections
- ✅ Authentication required for all dashboard operations
- ✅ View-only access (no data editing capabilities)

## Performance

- Uses aggregated Firestore queries for fast loading
- Optimized for 100k+ users
- Real-time updates via Firestore listeners
- Efficient date range filtering

## Troubleshooting

### Dashboard Shows "Access Denied"
- Verify your user document has `role: 'owner'` in Firestore
- Check that you're logged in with the correct account
- Ensure Firestore rules are published

### Metrics Not Loading
- Check Firestore connection
- Verify Firestore rules allow owner access
- Check browser console for errors
- Ensure you have data in Firestore collections

### Charts Not Displaying
- Verify `fl_chart` package is in `pubspec.yaml`
- Run `flutter pub get`
- Check that date range has data

## Next Steps

1. Set up Cloud Functions to update aggregated metrics (optional, for better performance)
2. Add custom date range presets
3. Export reports to PDF/CSV
4. Add email alerts for critical metrics
5. Implement dark mode (future-ready)

## Support

For issues or questions:
1. Check Firestore console for data
2. Verify Firestore rules are published
3. Check browser console for errors
4. Ensure all dependencies are installed

---

**Note:** The Owner Dashboard is designed for web access. For mobile apps, consider creating a separate admin app or using responsive web views.

