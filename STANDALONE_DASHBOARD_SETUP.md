# Standalone Owner Dashboard Website Setup

## Overview

The Owner Dashboard is now a **completely separate website** from your mobile app. It's a standalone monitoring tool that can be accessed independently via web browser.

## Architecture

- **Mobile App**: `lib/main.dart` → Regular marketplace app (buyers/sellers)
- **Dashboard Website**: `lib/main_web.dart` → Owner-only monitoring dashboard

## Running the Standalone Dashboard

### Option 1: Run Dashboard Directly (Recommended)

```bash
# Run the dashboard website
flutter run -d chrome --target=lib/main_web.dart --web-port=8080
```

This will:
- Launch Chrome automatically
- Show ONLY the Owner Dashboard
- No mobile app features
- Accessible at `http://localhost:8080`

### Option 2: Build Dashboard for Production

```bash
# Build the dashboard website
flutter build web --target=lib/main_web.dart --release

# The built files will be in build/web/
# Deploy these files to any web hosting service
```

### Option 3: Serve Built Dashboard Locally

```bash
# Build first
flutter build web --target=lib/main_web.dart

# Then serve (choose one):
# Python
cd build/web
python -m http.server 8080

# Node.js
npx http-server build/web -p 8080
```

## Deployment Options

### Deploy to Firebase Hosting

```bash
# Build dashboard
flutter build web --target=lib/main_web.dart --release

# Deploy to Firebase
firebase deploy --only hosting
```

### Deploy to Other Platforms

- **Netlify**: Drag and drop `build/web` folder
- **Vercel**: Connect repo, set build command: `flutter build web --target=lib/main_web.dart`
- **GitHub Pages**: Build with `--base-href "/repo-name/"` then deploy
- **Any Web Server**: Upload `build/web` contents to your server

## Access URLs

- **Local Development**: `http://localhost:8080`
- **Production**: Your deployed URL (e.g., `https://your-dashboard.com`)

## Key Features

✅ **Completely Separate** - No mobile app code loaded
✅ **Web-Optimized** - Desktop-first design
✅ **Owner-Only Access** - Authentication required
✅ **Real-Time Metrics** - Live data from Firestore
✅ **Lightweight** - Only loads dashboard dependencies

## Security

- Only users with `role: 'owner'` in Firestore can access
- Authentication handled via Firebase Auth
- Firestore rules enforce owner-only read access
- View-only dashboard (no data editing)

## Setup Steps

1. **Set Owner Role** in Firestore:
   - Go to Firebase Console → Firestore
   - Find your user in `userProfiles` collection
   - Add field: `role: "owner"`

2. **Run Dashboard**:
   ```bash
   flutter run -d chrome --target=lib/main_web.dart --web-port=8080
   ```

3. **Log In** with your owner account

4. **Access Dashboard** - You'll see the monitoring interface

## Troubleshooting

### Dashboard Shows "Access Denied"
- Verify `role: 'owner'` is set in Firestore
- Check you're logged in with correct account
- Ensure Firestore rules are published

### Build Fails
```bash
flutter clean
flutter pub get
flutter build web --target=lib/main_web.dart
```

### Port Already in Use
```bash
# Use different port
flutter run -d chrome --target=lib/main_web.dart --web-port=8081
```

## File Structure

```
food_app/
├── lib/
│   ├── main.dart              # Mobile app entry point
│   ├── main_web.dart          # Dashboard website entry point ⭐
│   └── screens/
│       └── owner_dashboard_screen.dart
└── web/
    ├── index.html             # Mobile app web entry
    └── index_dashboard.html   # Dashboard web entry (optional)
```

## Notes

- The dashboard is **completely independent** from the mobile app
- Mobile app users will never see the dashboard
- Dashboard can be deployed to a separate domain
- Both apps share the same Firebase backend
- Dashboard only loads what it needs (no Hive, no mobile features)

---

**The Owner Dashboard is now a standalone website!** 🎉

