# 🚨 QUICK FIX: Permission Denied Errors

## Immediate Steps (5 minutes)

### 1. Check Your User Role in Firestore

**Open Browser Console (F12) and check the debug messages:**
- Look for: `DEBUG: User role found: ...`
- If it says `null` or anything other than `"owner"`, you need to set it

**Set Owner Role:**
1. Go to: https://console.firebase.google.com/project/resqfood-66b5f/firestore/data
2. Click on `userProfiles` collection
3. Find your user document (use your Firebase Auth UID)
4. Click on the document
5. Click "Add field"
6. Field name: `role`
7. Field type: `string`
8. Value: `owner` (exactly this, lowercase)
9. Click "Update"

### 2. Publish Firestore Rules

**CRITICAL: Rules must be PUBLISHED, not just saved!**

1. Go to: https://console.firebase.google.com/project/resqfood-66b5f/firestore/rules
2. Copy ALL content from `firestore.rules` file in your project
3. Paste into Firebase Console rules editor
4. Click **"PUBLISH"** button (top right, NOT "Save")
5. Wait for "Rules published successfully" message
6. Wait 1-2 minutes for propagation

### 3. Verify Setup

1. **Refresh dashboard** (Ctrl+R)
2. **Open browser console** (F12)
3. **Look for:**
   - ✅ `DEBUG: Owner role confirmed` = Success!
   - ✅ `DEBUG: Found X users...` = Data loading!
   - ❌ `permission-denied` = Rules not published or role not set

## Still Not Working?

### Check Database Name
The code uses `databaseId: 'reqfood'`. Verify:
1. Firebase Console → Firestore Database
2. Check your database name
3. If different, update `lib/services/admin_metrics_service.dart` line 17

### Test with Temporary Open Rules (ONLY FOR TESTING)

If you want to verify rules are the issue, temporarily use:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

**⚠️ WARNING:** This allows any authenticated user to read/write everything. Only use to test, then switch back!

## Common Issues

| Error | Cause | Fix |
|-------|-------|-----|
| `permission-denied` | Rules not published | Click "Publish" in Firebase Console |
| `role: null` | Role field missing | Add `role: "owner"` to userProfiles document |
| `User profile does not exist` | Document missing | Create userProfiles/{uid} document |
| Still getting errors | Database name mismatch | Check databaseId in code matches Firebase |

## Need Help?

Check browser console for `DEBUG:` messages - they will tell you exactly what's wrong!

