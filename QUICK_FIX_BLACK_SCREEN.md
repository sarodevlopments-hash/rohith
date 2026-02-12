# Quick Fix for Black Screen Issue

## Problem
The browser shows a black screen when accessing `http://localhost:8080/food_app`

## Solutions

### Solution 1: Access Root Path (Recommended)
Instead of `/food_app`, try accessing:
```
http://localhost:8080/
```

### Solution 2: Check Browser Console
1. Press **F12** to open Developer Tools
2. Go to **Console** tab
3. Look for any red error messages
4. Share the errors if you see any

### Solution 3: Clear Browser Cache
1. Press **Ctrl + Shift + Delete**
2. Clear cached images and files
3. Refresh the page (**Ctrl + R**)

### Solution 4: Run with Correct Base Path
```bash
# Stop current process (Ctrl+C in terminal)
# Then run:
flutter run -d chrome --web-port=8080
```

### Solution 5: Build and Serve Manually
```bash
# Build the app
flutter build web

# Navigate to build folder
cd build/web

# Serve with Python (if installed)
python -m http.server 8080

# Or use Node.js http-server
npx http-server -p 8080
```

Then access: `http://localhost:8080`

## Common Issues

### JavaScript Errors
- Check browser console (F12)
- Look for Firebase initialization errors
- Check network tab for failed resource loads

### Base Path Mismatch
- The URL shows `/food_app` but app expects root `/`
- Try accessing `http://localhost:8080/` instead

### Assets Not Loading
- Check Network tab in DevTools
- Verify all files are loading (flutter_bootstrap.js, main.dart.js, etc.)

## Next Steps
1. Try accessing `http://localhost:8080/` (root path)
2. Check browser console for errors
3. Share any error messages you see

