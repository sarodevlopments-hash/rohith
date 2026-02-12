# 🧪 Test & Fix Firestore Permissions

## Step 1: Test with Open Rules (5 minutes)

This will tell us if the problem is with the rules or something else.

1. **Go to Firebase Console:**
   - https://console.firebase.google.com/project/resqfood-66b5f/firestore/rules

2. **Copy the content from `firestore.rules.test` file**

3. **Paste into Firebase Console and PUBLISH**

4. **Refresh your dashboard** (Ctrl+R)

5. **Check results:**
   - ✅ **If it works now:** The problem is with the `isOwner()` function in the rules
   - ❌ **If still fails:** The problem is something else (database name, authentication, etc.)

## Step 2A: If Test Rules Worked

The issue is with the `isOwner()` function. Do this:

1. **Make sure your user profile exists and has `role: "owner"`:**
   - Go to: https://console.firebase.google.com/project/resqfood-66b5f/firestore/data
   - Open `userProfiles` collection
   - Find your user document (by Firebase Auth UID)
   - **Add field:** `role` = `"owner"` (string, lowercase)

2. **Update rules to use the fixed version:**
   - Copy content from `firestore.rules` (the updated one)
   - Paste into Firebase Console
   - **PUBLISH**

3. **Refresh dashboard** - should work now!

## Step 2B: If Test Rules Still Failed

The problem is NOT the rules. Check:

1. **Database Name:**
   - Code uses: `databaseId: 'reqfood'`
   - Check Firebase Console → Firestore → Database name
   - If different, update code OR create database named `reqfood`

2. **Authentication:**
   - Make sure you're logged in
   - Check browser console for auth errors

3. **Network/Firewall:**
   - Check if Firestore is accessible
   - Try from different network

## Step 3: Verify Your Setup

After fixing, verify:

1. **User Profile:**
   ```
   Firestore → userProfiles → {your-uid}
   Must have: role: "owner"
   ```

2. **Rules Published:**
   ```
   Firebase Console → Firestore → Rules
   Should show: "Rules published successfully"
   ```

3. **Dashboard Working:**
   ```
   Browser Console (F12)
   Should see: DEBUG: Owner role confirmed
   Should see: DEBUG: Found X users...
   ```

## Quick Checklist

- [ ] Test rules published and dashboard works
- [ ] User profile has `role: "owner"` field
- [ ] Proper rules published (from `firestore.rules`)
- [ ] Database name matches (`reqfood`)
- [ ] User is authenticated
- [ ] Dashboard shows data (not just zeros)

## Still Stuck?

Check browser console for:
- `DEBUG:` messages (will tell you exactly what's wrong)
- Any error messages
- Network tab → Firestore requests → Check response

