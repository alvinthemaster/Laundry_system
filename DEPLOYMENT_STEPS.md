# 🚀 Firebase Cloud Functions Deployment - Step by Step

## ✅ What I've Done For You:
- ✅ Created firebase.json (Firebase configuration)
- ✅ Created .firebaserc (Your project: franz-laundry-hub)
- ✅ Created functions/index.js (Cloud Function code)
- ✅ Created functions/package.json (Dependencies config)

## 📋 What YOU Need to Do Now:

### **STEP 1: Install Cloud Function Dependencies**

Open PowerShell in VS Code terminal and run:

```powershell
cd functions
npm install
```

**Wait for installation...** (takes 1-2 minutes)

You should see:
```
added XXX packages
```

✅ **This installs firebase-admin and firebase-functions packages**

---

### **STEP 2: Go Back to Project Root**

```powershell
cd ..
```

---

### **STEP 3: Deploy the Cloud Function**

```powershell
firebase deploy --only functions
```

**Wait for deployment...** (takes 2-5 minutes)

**Expected output:**
```
✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/franz-laundry-hub/overview
```

---

## ⚠️ If You Get an Error:

### Error: "Billing account not configured"
**Solution:**
1. Go to https://console.firebase.google.com/project/franz-laundry-hub/overview
2. Click on "Upgrade" or "Modify plan"
3. Select **Blaze (Pay as you go)** plan
4. Add a payment method (credit/debit card)
5. **Don't worry:** Free tier includes 2 million function calls/month
6. Run `firebase deploy --only functions` again

### Error: Network timeout
**Solution:**
1. Check your internet connection
2. Try again: `firebase deploy --only functions`
3. If still fails, try: `npm install -g firebase-tools@latest` to update CLI

### Error: "Permission denied"
**Solution:**
1. Run: `firebase login`
2. Make sure you're logged in with the account that owns the project
3. Try deploy again

---

## ✅ Verify Deployment:

After successful deployment:

1. **Check Firebase Console:**
   - Go to https://console.firebase.google.com/project/franz-laundry-hub/functions
   - You should see: **`onBookingStatusChange`** function listed
   - Status: "Healthy" or "Active" ✅

2. **Check Function Logs:**
   ```powershell
   firebase functions:log
   ```

---

## 🧪 Test the Notification:

### Test 1: Local Notification (App Open)
```powershell
flutter run
```
1. Log in to the app
2. Keep app open
3. Open Firebase Console → Firestore → bookings
4. Change any booking status to "Ready"
5. **You should see notification!** ✅

### Test 2: Background Notification (App Closed)
1. **Close the app completely** (force close)
2. Open Firebase Console → Firestore → bookings
3. Change a booking status to "Ready"
4. **You should get notification even with app closed!** ✅

---

## 📊 Summary of Commands:

```powershell
# 1. Install dependencies
cd functions
npm install

# 2. Go back to root
cd ..

# 3. Deploy function
firebase deploy --only functions

# 4. (Optional) View logs
firebase functions:log
```

---

## 🆘 Still Having Issues?

**Check the logs:**
```powershell
# View deployment errors
cat firebase-debug.log

# View function execution logs
firebase functions:log
```

**Common fixes:**
- Ensure billing is enabled (Blaze plan)
- Ensure you're logged in: `firebase login`
- Update Firebase CLI: `npm install -g firebase-tools@latest`
- Check internet connection

---

## 🎉 Success Indicator:

You'll know it's working when:
- ✅ Deployment shows "Deploy complete!"
- ✅ Function appears in Firebase Console → Functions
- ✅ You receive notifications when booking status changes to "Ready"
- ✅ Notifications work even when app is closed

---

**Ready? Start with STEP 1 above!** 🚀
