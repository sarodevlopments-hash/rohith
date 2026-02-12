# 🌐 How to Open Owner Dashboard Website

## Quick Start (3 Steps)

### Step 1: Start the Flutter Web Server

Open PowerShell or Command Prompt in your project folder and run:

```bash
flutter run -d chrome --target=lib/main_web.dart --web-port=8080
```

**Wait for:** 
- ✅ "Flutter run key commands" message
- ✅ Chrome browser should open automatically
- ✅ URL should be: `http://localhost:8080`

### Step 2: If Browser Doesn't Open Automatically

**Manually open:**
1. Open any web browser (Chrome, Edge, Firefox)
2. Go to: `http://localhost:8080`
3. The dashboard should load

### Step 3: Login

1. **If you see a login screen:**
   - Enter your email and password
   - Click "Login"
   - Make sure your user has `role: "owner"` in Firestore

2. **If you see "Access Denied":**
   - Your user doesn't have owner role
   - See "Fix Owner Role" section below

---

## Detailed Steps

### Option A: Using Flutter Run (Recommended)

1. **Open Terminal/PowerShell:**
   - Navigate to project folder: `cd C:\Users\rohith_kamshetty\food_app`

2. **Run the command:**
   ```bash
   flutter run -d chrome --target=lib/main_web.dart --web-port=8080
   ```

3. **Wait for compilation:**
   - First time: Takes 1-2 minutes
   - Subsequent: Takes 10-30 seconds

4. **Browser opens automatically:**
   - URL: `http://localhost:8080`
   - Dashboard loads

### Option B: Using Flutter Web Server (Alternative)

1. **Build the web app:**
   ```bash
   flutter build web --target=lib/main_web.dart
   ```

2. **Serve the files:**
   ```bash
   cd build/web
   python -m http.server 8080
   ```
   (Or use any local server)

3. **Open browser:**
   - Go to: `http://localhost:8080`

---

## Troubleshooting

### Port Already in Use

**Error:** `Failed to bind web development server...`

**Fix:**
```powershell
# Find process using port 8080
netstat -ano | findstr :8080

# Kill the process (replace PID with actual number)
taskkill /PID <PID> /F

# Try again
flutter run -d chrome --target=lib/main_web.dart --web-port=8080
```

### Browser Doesn't Open

1. **Check if server is running:**
   - Look for: `Serving at http://localhost:8080`
   - If not, restart the command

2. **Manually open:**
   - Open browser
   - Type: `http://localhost:8080`
   - Press Enter

### Permission Errors

**If you see permission errors:**
1. Check `TEST_AND_FIX.md` for steps
2. Make sure Firestore rules are published
3. Make sure your user has `role: "owner"`

### Dashboard Shows No Data

**If dashboard loads but shows zeros:**
1. Check browser console (F12) for errors
2. Look for `DEBUG:` messages
3. Verify Firestore has data:
   - Go to Firebase Console → Firestore → Data
   - Check `userProfiles`, `orders`, `listings` collections

---

## Quick Reference

| What | Command/URL |
|------|-------------|
| **Start Server** | `flutter run -d chrome --target=lib/main_web.dart --web-port=8080` |
| **Dashboard URL** | `http://localhost:8080` |
| **Firebase Console** | https://console.firebase.google.com/project/resqfood-66b5f |
| **Firestore Rules** | https://console.firebase.google.com/project/resqfood-66b5f/firestore/rules |
| **Firestore Data** | https://console.firebase.google.com/project/resqfood-66b5f/firestore/data |

---

## Fix Owner Role (If Needed)

If you see "Access Denied":

1. **Get your Firebase Auth UID:**
   - Check browser console after login
   - Or Firebase Console → Authentication → Users

2. **Set Owner Role:**
   - Go to: Firebase Console → Firestore → Data
   - Open `userProfiles` collection
   - Find your user document (by UID)
   - Add field: `role` = `"owner"` (string)

3. **Refresh dashboard:**
   - Press Ctrl+R or F5
   - Should work now!

---

## Stop the Server

**To stop the Flutter web server:**
- Press `q` in the terminal
- Or close the terminal window
- Or press Ctrl+C

---

## Need Help?

Check these files:
- `TEST_AND_FIX.md` - Fix permission errors
- `QUICK_FIX_PERMISSIONS.md` - Quick troubleshooting
- `FIX_FIRESTORE_PERMISSIONS.md` - Detailed guide

