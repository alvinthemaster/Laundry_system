# ✅ Your Manual Setup Checklist - Push Notifications

**Good news:** All code is already implemented! ✅

**What you need to do:** Just 3 external steps (Firebase Console + CLI commands)

---

## 🎯 STEP 1: Update Firestore Security Rules (2 minutes)

### What to do:
1. Open https://console.firebase.google.com
2. Select your project: **"Laundry System"** or whatever your project is called
3. Click **"Firestore Database"** in left sidebar
4. Click **"Rules"** tab at the top
5. **Copy and paste** this entire rule (replace everything):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users collection - allow users to update their own FCM token
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Specifically allow FCM token updates
      allow update: if request.auth != null && 
                       request.auth.uid == userId && 
                       request.resource.data.diff(resource.data).affectedKeys()
                         .hasOnly(['fcmToken', 'fcmTokenUpdatedAt']);
    }
    
    // Bookings collection
    match /bookings/{bookingId} {
      allow read, write: if request.auth != null;
    }
    
    // Machine slots
    match /machine_slots/{slotId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // Receipts
    match /receipts/{receiptId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

6. Click **"Publish"** button
7. Wait for "Rules published successfully" ✅

**Done!** This allows the app to save notification tokens.

---

## 🚀 STEP 2: Set Up Cloud Functions (15 minutes)

### Prerequisites Check:

**Do you have Node.js installed?**
- Open PowerShell and run: `node --version`
- If you see a version number (like v18.x.x): ✅ Skip to Step 2B
- If you get an error: 👇 Do Step 2A first

---

### STEP 2A: Install Node.js (if needed)

1. Go to: https://nodejs.org/
2. Download **LTS version** (recommended)
3. Run the installer (click Next → Next → Install)
4. Restart PowerShell
5. Verify: `node --version` (should show version number)

---

### STEP 2B: Install Firebase CLI & Deploy Function

**Copy and paste these commands one by one in PowerShell:**

```powershell
# 1. Install Firebase CLI (one-time setup)
npm install -g firebase-tools

# 2. Login to Firebase (will open browser)
firebase login

# 3. Go to your project folder
cd C:\Users\yourb\OneDrive\Documents\GitHub\Laundry_system

# 4. Initialize Cloud Functions
firebase init functions
```

**When prompted during `firebase init functions`, answer:**
- "Are you ready to proceed?" → Press `Y` and Enter
- "Please select an option:" → Choose **"Use an existing project"**
- "Select a default Firebase project:" → Choose your Laundry System project
- "What language would you like to use?" → Choose **"JavaScript"**
- "Do you want to use ESLint?" → Press `Y`
- "Do you want to install dependencies with npm now?" → Press `Y`

**Wait for installation... (may take 2-3 minutes)**

---

### STEP 2C: Create the Cloud Function

**I've prepared the function code. Copy and paste this command:**

```powershell
# This will create the function file with the correct code
cd functions
```

**Then open `functions/index.js` in VS Code and replace everything with:**

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.onBookingStatusChange = functions.firestore
  .document('bookings/{bookingId}')
  .onUpdate(async (change, context) => {
    try {
      const beforeData = change.before.data();
      const afterData = change.after.data();
      const bookingId = context.params.bookingId;

      console.log(`Booking ${bookingId} updated: ${beforeData.status} → ${afterData.status}`);

      if (beforeData.status !== 'Ready' && afterData.status === 'Ready') {
        console.log('Status changed to Ready! Sending notification...');

        const userId = afterData.userId;
        const userDoc = await admin.firestore().collection('users').doc(userId).get();

        if (!userDoc.exists) {
          console.warn(`User ${userId} not found`);
          return null;
        }

        const fcmToken = userDoc.data().fcmToken;
        if (!fcmToken) {
          console.warn(`User ${userId} has no FCM token`);
          return null;
        }

        const message = {
          token: fcmToken,
          notification: {
            title: '🎉 Your Laundry is Ready!',
            body: 'Your laundry order is ready for pickup. Thank you!',
          },
          data: {
            bookingId: bookingId,
            type: 'booking_ready',
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          android: {
            notification: {
              channelId: 'booking_status_channel',
              priority: 'high',
              sound: 'default',
            },
          },
        };

        const response = await admin.messaging().send(message);
        console.log('✅ Notification sent:', response);
        return response;
      }
      return null;
    } catch (error) {
      console.error('❌ Error:', error);
      return null;
    }
  });
```

**Save the file** (Ctrl+S)

---

### STEP 2D: Deploy the Cloud Function

```powershell
# Go back to project root
cd ..

# Deploy the function (this uploads it to Firebase)
firebase deploy --only functions
```

**Wait for deployment... (2-5 minutes)**

**Expected output:**
```
✔  functions[onBookingStatusChange(us-central1)] Successful update operation.
✔  Deploy complete!
```

**⚠️ Important:** If you get a **billing error**, you need to:
1. Go to Firebase Console → Project Settings (gear icon) → Usage and billing
2. Click **"Modify plan"**
3. Select **"Blaze (Pay as you go)"** plan
4. Add a payment method
5. **Don't worry:** Free tier includes 2 million function calls/month (you won't be charged for normal usage)
6. Then run `firebase deploy --only functions` again

---

## ✅ STEP 3: Test Everything (2 minutes)

### Test 1: Local Notifications (App Open)

```powershell
# Run the app
flutter run
```

1. Log in to the app (grant notification permission when asked)
2. Keep the app open
3. Open Firebase Console → Firestore → bookings
4. Change any booking status to **"Ready"**
5. **You should see a notification on your device!** ✅

### Test 2: Background Notifications (App Closed)

1. **Close the app completely** (force close it)
2. Open Firebase Console → Firestore → bookings
3. Change a different booking status to **"Ready"**
4. **You should get a notification even with app closed!** ✅

### Verify in Firebase Console:

1. Firebase Console → **Functions** (left sidebar)
2. You should see: **`onBookingStatusChange`** listed
3. Click on it → **Logs** tab
4. You should see logs when you change booking status

---

## 🎉 THAT'S IT!

If all tests pass, you're done! 🎊

---

## 🆘 Troubleshooting

| Problem | Solution |
|---------|----------|
| No notification when app open | Check you granted permissions when logging in |
| No fcmToken in Firestore users | Step 1 (security rules) wasn't done correctly |
| No notification when app closed | Cloud Function not deployed (Step 2D) |
| "Billing required" error | Upgrade to Blaze plan in Firebase Console |
| Function deploy fails | Run `firebase login` again and retry |

### Check Logs:
```powershell
# View Cloud Function logs
firebase functions:log
```

---

## 📋 Quick Verification Checklist

- [ ] Firestore rules published (Step 1)
- [ ] Firebase CLI installed (`firebase --version` works)
- [ ] Logged in to Firebase (`firebase login` done)
- [ ] Cloud Function deployed (`firebase deploy --only functions` succeeded)
- [ ] Function visible in Firebase Console → Functions
- [ ] Notification works when app is open
- [ ] Notification works when app is closed
- [ ] fcmToken exists in Firestore users collection

---

## 🎯 Summary

**What I did (code side):** ✅
- Added firebase_messaging dependency
- Created NotificationService
- Created BookingStatusListener
- Updated AndroidManifest.xml
- Updated auth provider to save/remove FCM tokens

**What you need to do (manual):**
- ✅ Step 1: Update Firestore rules (2 min)
- ✅ Step 2: Deploy Cloud Function (15 min)
- ✅ Step 3: Test (2 min)

**Total time:** ~20 minutes
