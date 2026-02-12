# Quick Start: Open Owner Dashboard Website

## 🚀 Simple Steps

### Step 1: Run the Dashboard Website

Open your terminal in the project folder and run:

```bash
flutter run -d chrome --target=lib/main_web.dart --web-port=8080
```

**What this does:**
- Builds the dashboard website
- Launches Chrome automatically
- Opens at `http://localhost:8080`

### Step 2: Wait for Build

- First time: Takes 1-2 minutes to compile
- Chrome will open automatically when ready
- You'll see the login screen

### Step 3: Log In

- Use your Firebase account (the one with `role: 'owner'` in Firestore)
- After login, you'll see the Owner Dashboard

## 📍 Access URL

Once running, access at:
```
http://localhost:8080
```

## ⚠️ Important: Set Owner Role First!

Before logging in, make sure you've set your role in Firestore:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Navigate to **Firestore Database**
3. Open `userProfiles` collection
4. Find your user document (use your Firebase Auth UID)
5. Add field:
   - **Field name**: `role`
   - **Field value**: `owner` (as a string)
6. Save

## 🔄 If Port 8080 is Busy

Use a different port:

```bash
flutter run -d chrome --target=lib/main_web.dart --web-port=8081
```

Then access: `http://localhost:8081`

## 🛑 Stop the Server

Press `Ctrl + C` in the terminal to stop the server.

## ✅ Success Indicators

- Chrome opens automatically
- You see a login screen
- After login, you see dashboard metrics
- No errors in browser console (F12)

## 🆘 Troubleshooting

### "Access Denied" after login
- Check Firestore: `userProfiles` → Your user → `role: "owner"`
- Make sure you're logged in with the correct account

### Chrome doesn't open
- Manually go to `http://localhost:8080`
- Check terminal for the exact URL

### Build errors
```bash
flutter clean
flutter pub get
flutter run -d chrome --target=lib/main_web.dart --web-port=8080
```

---

**That's it!** The dashboard website is now running separately from your mobile app. 🎉

