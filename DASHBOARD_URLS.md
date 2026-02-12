# Owner Dashboard URLs

## 🌐 Local Development URL

When running locally, access the dashboard at:

```
http://localhost:8080
```

**To start the server:**
```bash
flutter run -d chrome --target=lib/main_web.dart --web-port=8080
```

---

## 🚀 Production Deployment URLs

### Option 1: Firebase Hosting (Recommended)

After deploying to Firebase Hosting, your dashboard will be available at:

```
https://resqfood-66b5f.web.app/dashboard
```

Or your custom domain if configured.

**Deploy Steps:**
```bash
# Build for production
flutter build web --target=lib/main_web.dart --release

# Deploy to Firebase
firebase deploy --only hosting
```

### Option 2: Custom Domain

If you configure a custom domain in Firebase Hosting:
```
https://dashboard.yourdomain.com
```

### Option 3: Other Hosting Services

- **Netlify**: `https://your-app.netlify.app`
- **Vercel**: `https://your-app.vercel.app`
- **GitHub Pages**: `https://yourusername.github.io/repo-name`

---

## 📝 Quick Access Guide

### Local Development
1. Run: `flutter run -d chrome --target=lib/main_web.dart --web-port=8080`
2. Open: `http://localhost:8080`
3. Login with your owner account

### Production
1. Build: `flutter build web --target=lib/main_web.dart --release`
2. Deploy to your hosting service
3. Access via your deployed URL
4. Login with your owner account

---

## 🔐 Security Note

- The dashboard requires authentication
- Only users with `role: 'owner'` in Firestore can access
- Make sure to set your role before accessing

---

## 🆘 Troubleshooting

### Can't access localhost:8080
- Make sure the Flutter server is running
- Check if port 8080 is available
- Try a different port: `--web-port=8081`

### Production URL not working
- Verify deployment completed successfully
- Check Firebase Hosting console
- Ensure Firestore rules allow owner access

