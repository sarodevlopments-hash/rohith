# How to Run the Owner Dashboard on Web

## Quick Start Guide

### Step 1: Enable Web Support (if not already enabled)

Check if web is enabled:
```bash
flutter devices
```

If you don't see Chrome/web listed, enable it:
```bash
flutter config --enable-web
```

### Step 2: Install Dependencies

Make sure all packages are installed:
```bash
flutter pub get
```

### Step 3: Set Up Owner Role

**IMPORTANT:** Before accessing the dashboard, you need to set your user role to `'owner'` in Firestore:

1. **Option A: Using Firebase Console (Easiest)**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Navigate to **Firestore Database**
   - Find your user document in `userProfiles` collection (use your Firebase Auth UID)
   - Click on the document
   - Click **"Add field"**
   - Field name: `role`
   - Field value: `owner` (as a string)
   - Click **"Update"**

2. **Option B: Using Code (Temporary Script)**
   Create a file `set_owner_role.dart` in the project root:
   ```dart
   import 'package:firebase_core/firebase_core.dart';
   import 'package:cloud_firestore/cloud_firestore.dart';
   import 'package:firebase_auth/firebase_auth.dart';
   import 'lib/firebase_options.dart';
   
   Future<void> main() async {
     await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
     
     final user = FirebaseAuth.instance.currentUser;
     if (user == null) {
       print('Please log in first!');
       return;
     }
     
     await FirebaseFirestore.instanceFor(
       app: Firebase.app(),
       databaseId: 'reqfood',
     ).collection('userProfiles').doc(user.uid).set({
       'role': 'owner'
     }, SetOptions(merge: true));
     
     print('Owner role set for user: ${user.uid}');
   }
   ```
   Then run: `dart set_owner_role.dart`

### Step 4: Run the App on Web

#### Option A: Run in Development Mode (Recommended for Testing)

```bash
flutter run -d chrome
```

This will:
- Build the app for web
- Launch Chrome automatically
- Enable hot reload for quick development
- Show the app at `http://localhost:xxxxx`

#### Option B: Run with Specific Port

```bash
flutter run -d chrome --web-port=8080
```

#### Option C: Build and Serve Locally

```bash
# Build for web
flutter build web

# Serve the built files (requires a local server)
# Option 1: Using Python
cd build/web
python -m http.server 8080

# Option 2: Using Node.js http-server
npx http-server build/web -p 8080

# Option 3: Using VS Code Live Server extension
# Right-click on build/web/index.html -> "Open with Live Server"
```

Then open: `http://localhost:8080`

### Step 5: Access the Dashboard

1. **Log in** with your owner account (the one you set `role: 'owner'` for)
2. You will be **automatically redirected** to the Owner Dashboard
3. If you see "Access Denied", verify:
   - Your user document has `role: 'owner'` in Firestore
   - You're logged in with the correct account
   - Firestore rules are published

## Troubleshooting

### Issue: "Chrome not found" or "No devices found"

**Solution:**
```bash
# Check Flutter web support
flutter doctor -v

# Enable web support
flutter config --enable-web

# Verify Chrome is installed
# Windows: Usually at C:\Program Files\Google\Chrome\Application\chrome.exe
# Mac: Usually at /Applications/Google Chrome.app
# Linux: Install via package manager
```

### Issue: "Access Denied" on Dashboard

**Solution:**
1. Check Firestore Console → `userProfiles` → Your user document
2. Verify `role` field exists and equals `"owner"` (as a string, not boolean)
3. Make sure you're logged in with the correct Firebase account
4. Check browser console for errors (F12 → Console tab)

### Issue: "Firestore permission denied"

**Solution:**
1. Go to [Firestore Rules](https://console.firebase.google.com/project/resqfood-66b5f/firestore/rules)
2. Click **"Publish"** (not just "Save")
3. Wait 1-2 minutes for propagation
4. Refresh the web page

### Issue: "Metrics not loading"

**Solution:**
1. Check browser console (F12) for errors
2. Verify Firestore has data in `listings`, `orders`, and `userProfiles` collections
3. Check network tab for failed Firestore requests
4. Ensure you have internet connection

### Issue: "Charts not displaying"

**Solution:**
```bash
# Make sure fl_chart is installed
flutter pub get

# Check pubspec.yaml has:
# dependencies:
#   fl_chart: ^0.68.0
```

### Issue: Build fails

**Solution:**
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run -d chrome
```

## Production Deployment

### Deploy to Firebase Hosting

```bash
# Build for production
flutter build web --release

# Install Firebase CLI (if not installed)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize hosting (if not already done)
firebase init hosting

# Deploy
firebase deploy --only hosting
```

### Deploy to Other Platforms

- **Netlify**: Drag and drop `build/web` folder
- **Vercel**: Connect GitHub repo and set build command to `flutter build web`
- **GitHub Pages**: Use `flutter build web --base-href "/your-repo-name/"`

## Quick Commands Reference

```bash
# Run on Chrome (development)
flutter run -d chrome

# Run on Chrome with specific port
flutter run -d chrome --web-port=8080

# Build for production
flutter build web --release

# Build with custom base href (for GitHub Pages)
flutter build web --base-href "/food_app/"

# Check available devices
flutter devices

# Check Flutter web support
flutter doctor -v

# Clean build cache
flutter clean
```

## Access URLs

- **Local Development**: `http://localhost:xxxxx` (port shown in terminal)
- **Firebase Hosting**: `https://resqfood-66b5f.web.app` (after deployment)
- **Custom Domain**: Your configured domain (if set up)

## Next Steps

1. ✅ Set owner role in Firestore
2. ✅ Run `flutter run -d chrome`
3. ✅ Log in with owner account
4. ✅ Access the dashboard
5. ✅ Explore metrics and insights!

---

**Note:** The Owner Dashboard is optimized for desktop/web viewing. For best experience, use Chrome, Edge, or Firefox on a desktop/laptop with screen width > 1024px.

