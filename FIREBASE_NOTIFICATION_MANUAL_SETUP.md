# 🔔 Firebase Push Notification Setup - Complete Manual Guide

This is a **step-by-step guide** with all manual Firebase Console steps for setting up push notifications in the Laundry System.

## 📋 What This Guide Covers

- ✅ Part 1: Testing Local Notifications (App Open) - **No Firebase setup needed**
- ✅ Part 2: Setting Up Firestore Security Rules - **Firebase Console**
- ✅ Part 3: Setting Up Cloud Functions (App Closed) - **Firebase CLI + Console**
- ✅ Part 4: Testing and Verification

---

## 🎯 PART 1: Test Local Notifications (App Open)

**These already work! No Firebase setup needed.**

### Step 1.1: Run the App
```bash
flutter run
```

### Step 1.2: Log In
- Open the app and log in with any user account
- The app will automatically request notification permissions
- **Grant the permission when prompted**

### Step 1.3: Test the Notification

1. **Open Firebase Console**
   - Go to https://console.firebase.google.com
   - Select your project

2. **Navigate to Firestore Database**
   - Click "Firestore Database" in the left sidebar
   - Click on the "bookings" collection

3. **Find a Booking**
   - Click on any booking document
   - Look for the booking that belongs to your logged-in user

4. **Change Status to "Ready"**
   - Find the `status` field
   - Click on the current value (e.g., "Pending")
   - Change it to: `Ready`
   - Click "Update"

5. **Check Your Phone/Emulator**
   - You should immediately see a notification: **"🎉 Your Laundry is Ready!"**
   - This proves local notifications work! ✅

### Step 1.4: Verify FCM Token Storage

1. **In Firebase Console → Firestore**
   - Click on the "users" collection
   - Find your user document (by email or UID)
   - Look for the `fcmToken` field

2. **You should see:**
   - `fcmToken: "xxxxxxxx..."` (a long token string)
   - `fcmTokenUpdatedAt: timestamp`

3. **If you don't see the token:**
   - Check that you granted notification permissions
   - Check app logs for errors
   - Try logging out and back in

---

## 🔒 PART 2: Configure Firestore Security Rules

**This allows the app to save FCM tokens to user profiles.**

### Step 2.1: Open Firestore Rules

1. Go to **Firebase Console** → Your Project
2. Click **"Firestore Database"** in the left sidebar
3. Click the **"Rules"** tab at the top

### Step 2.2: Update the Rules

Find the `users` collection rule and update it to allow FCM token updates:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users collection - allow users to update their own FCM token
    match /users/{userId} {
      // Users can read/write their own data
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Specifically allow FCM token updates
      allow update: if request.auth != null && 
                       request.auth.uid == userId && 
                       request.resource.data.diff(resource.data).affectedKeys()
                         .hasOnly(['fcmToken', 'fcmTokenUpdatedAt']);
    }
    
    // Bookings collection - users can read their own bookings
    match /bookings/{bookingId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // Add other collection rules as needed
  }
}
```

### Step 2.3: Publish the Rules

1. Click the **"Publish"** button at the top
2. Confirm the changes
3. Wait for "Rules published successfully" message

### Step 2.4: Verify

1. Log out and log back in to the app
2. Check Firestore → users → your user document
3. Verify `fcmToken` is present

---

## 🚀 PART 3: Set Up Cloud Functions (For Background Notifications)

**This enables notifications when the app is completely closed.**

### Prerequisites

- **Node.js** installed (version 14 or higher)
- **npm** installed (comes with Node.js)
- **Firebase CLI** installed

### Step 3.1: Install Node.js (if not installed)

1. Download from: https://nodejs.org/
2. Install the LTS version
3. Verify installation:
   ```bash
   node --version
   npm --version
   ```

### Step 3.2: Install Firebase CLI

```bash
npm install -g firebase-tools
```

Verify:
```bash
firebase --version
```

### Step 3.3: Login to Firebase

```bash
firebase login
```

- This will open your browser
- Log in with the same Google account used for Firebase Console
- Grant permissions when asked

### Step 3.4: Navigate to Your Project

```bash
cd C:\Users\yourb\OneDrive\Documents\GitHub\Laundry_system
```

### Step 3.5: Initialize Cloud Functions

```bash
firebase init functions
```

**During initialization, answer:**

1. **"Are you ready to proceed?"** → `Y` (Yes)
2. **"Please select an option:"** → `Use an existing project`
3. **"Select a default Firebase project:"** → Select your Laundry System project
4. **"What language would you like to use?"** → `JavaScript`
5. **"Do you want to use ESLint?"** → `Y` (recommended)
6. **"Do you want to install dependencies with npm now?"** → `Y`

Wait for installation to complete...

### Step 3.6: Create the Cloud Function

1. Navigate to the functions folder:
   ```bash
   cd functions
   ```

2. Open `functions/index.js` in your code editor

3. **Replace the entire content** with this code:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

/**
 * Cloud Function: Send notification when booking status changes to "Ready"
 * Triggers on any booking document update in Firestore
 */
exports.onBookingStatusChange = functions.firestore
  .document('bookings/{bookingId}')
  .onUpdate(async (change, context) => {
    try {
      const beforeData = change.before.data();
      const afterData = change.after.data();
      const bookingId = context.params.bookingId;

      console.log(`Booking ${bookingId} updated`);
      console.log(`Status change: ${beforeData.status} → ${afterData.status}`);

      // Check if status changed TO "Ready" (not FROM "Ready")
      if (beforeData.status !== 'Ready' && afterData.status === 'Ready') {
        console.log(`Status changed to Ready! Sending notification...`);

        const userId = afterData.userId;

        // Get user's FCM token from Firestore
        const userDoc = await admin.firestore()
          .collection('users')
          .doc(userId)
          .get();

        if (!userDoc.exists) {
          console.warn(`User ${userId} not found in Firestore`);
          return null;
        }

        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;

        if (!fcmToken) {
          console.warn(`User ${userId} has no FCM token`);
          return null;
        }

        console.log(`Sending notification to user ${userId}`);

        // Prepare the notification message
        const message = {
          token: fcmToken,
          notification: {
            title: '🎉 Your Laundry is Ready!',
            body: 'Your laundry order is ready for pickup. Thank you for using our service!',
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
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
        };

        // Send the notification
        const response = await admin.messaging().send(message);
        console.log(`✅ Notification sent successfully:`, response);

        return response;
      } else {
        console.log(`Status change not to Ready, no notification sent`);
        return null;
      }
    } catch (error) {
      console.error('❌ Error in onBookingStatusChange:', error);
      return null;
    }
  });
```

4. Save the file

### Step 3.7: Deploy the Cloud Function

From the `functions` folder:

```bash
cd ..
firebase deploy --only functions
```

**Wait for deployment** (may take 2-5 minutes)

You should see:
```
✔  functions[onBookingStatusChange(us-central1)] Successful update operation.
✔  Deploy complete!
```

### Step 3.8: Verify Deployment in Firebase Console

1. Go to **Firebase Console** → Your Project
2. Click **"Functions"** in the left sidebar
3. You should see: **`onBookingStatusChange`** function listed
4. Status should be: **"Healthy"** or **"Active"**

---

## ✅ PART 4: Testing Background Notifications

**Test that notifications work even when the app is closed.**

### Step 4.1: Prepare Your Device/Emulator

1. **Run the app once:**
   ```bash
   flutter run
   ```

2. **Log in** with a user account

3. **Completely close the app:**
   - Don't just minimize it
   - Force close it from the app switcher
   - Or restart your device/emulator

### Step 4.2: Trigger the Notification

1. **Open Firebase Console** → Firestore Database → bookings collection

2. **Find or create a booking** for your test user

3. **Change the status:**
   - Click on the booking document
   - Find the `status` field
   - Change it to: `Ready`
   - Click **Update**

### Step 4.3: Check for Notification

**Within 1-2 seconds**, you should receive a notification on your device/emulator:
- **Title:** 🎉 Your Laundry is Ready!
- **Body:** Your laundry order is ready for pickup...

**Even though the app is closed!** ✅

### Step 4.4: Check Cloud Function Logs

If you didn't receive the notification:

1. **Go to Firebase Console** → Functions
2. Click on **`onBookingStatusChange`**
3. Click the **"Logs"** tab
4. Look for recent executions

**What to look for:**
- ✅ **"Status changed to Ready! Sending notification..."**
- ✅ **"Notification sent successfully"**
- ❌ **"User has no FCM token"** → User needs to log in to app first
- ❌ **"User not found"** → Check userId in booking matches user document

---

## 🔍 Troubleshooting

### Issue 1: No Notification When App is Open

**Solution:**
- Check notification permissions are granted
- Check Firestore rules (Part 2)
- Log out and back in
- Check app logs for errors

### Issue 2: No Notification When App is Closed

**Solution:**
1. Verify Cloud Function is deployed (Part 3.8)
2. Check Cloud Function logs in Firebase Console
3. Verify user has FCM token in Firestore
4. Check device notification settings
5. Try restarting the device

### Issue 3: "FCM token not found" in Logs

**Solution:**
1. Open the app
2. Log in (this saves the FCM token)
3. Check users collection in Firestore for `fcmToken` field
4. Try again

### Issue 4: Cloud Function Deployment Fails

**Solution:**
1. Ensure you're logged in: `firebase login`
2. Check you selected the correct project
3. Ensure billing is enabled (Blaze plan required for Cloud Functions)
4. Check Node.js version (14+ required)

### Issue 5: Billing Required Error

**Solution:**
- Cloud Functions require Firebase **Blaze (Pay as you go)** plan
- Go to Firebase Console → Upgrade to Blaze plan
- Free tier includes generous quotas (sufficient for testing)
- You won't be charged unless you exceed free limits

---

## 📊 Verify Everything is Working

### ✅ Checklist

- [ ] **App requests notification permissions** when user logs in
- [ ] **FCM token is saved** to Firestore users/{userId}/fcmToken
- [ ] **Local notifications work** when app is open
- [ ] **Cloud Function is deployed** and shows "Healthy" in Firebase Console
- [ ] **Background notifications work** when app is closed
- [ ] **Firestore security rules** allow fcmToken updates
- [ ] **Cloud Function logs** show successful notification sends

---

## 🎓 How It All Works Together

### When App is OPEN:
1. User logs in → FCM token saved to Firestore
2. BookingStatusListener starts monitoring bookings
3. Admin changes booking status to "Ready" in Firestore
4. Listener detects change **in real-time**
5. **NotificationService** shows local notification
6. User sees notification ✅

### When App is CLOSED:
1. User logs in once (FCM token saved to Firestore)
2. User closes the app completely
3. Admin changes booking status to "Ready" in Firestore
4. **Cloud Function** triggers automatically
5. Function reads FCM token from user document
6. Function sends push notification via Firebase Cloud Messaging
7. Device receives notification even with app closed ✅

---

## 📱 Notification Permissions by Android Version

### Android 13+ (API 33+)
- Runtime permission required
- App will ask for permission when user logs in
- User must grant "Allow notifications"

### Android 12 and below
- Notifications enabled by default
- User can disable in system settings

---

## 🚨 Important Notes

1. **Blaze Plan Required**: Cloud Functions require Firebase Blaze (pay-as-you-go) plan
   - Free tier is generous (2 million invocations/month free)
   - You likely won't be charged for normal usage
   
2. **First Login Required**: Users must log in at least once for FCM token to be saved

3. **Battery Optimization**: Some Android devices (Xiaomi, Huawei, etc.) have aggressive battery optimization that may block notifications. Users may need to disable battery optimization for your app.

4. **Testing**: Always test on a real device. Emulator notifications may be unreliable.

---

## 🎯 Next Steps / Enhancements

Once basic notifications are working, you can:

1. **Add more notification types** (Confirmed, Washing, Completed)
2. **Add notification settings** page (let users choose which notifications to receive)
3. **Add notification actions** (View Booking, Dismiss buttons)
4. **Add notification history** (store in Firestore)
5. **Add admin notification panel** (send custom notifications to users)
6. **Add notification sounds** (custom sound per notification type)

---

## 📞 Support

If you encounter issues:
1. Check Cloud Function logs in Firebase Console
2. Check app logs: `flutter run` shows real-time logs
3. Verify Firestore security rules
4. Check FCM token exists in Firestore
5. Try redeploying: `firebase deploy --only functions`

---

## 🎉 Success!

Once all steps are complete:
- ✅ Notifications work when app is open
- ✅ Notifications work when app is closed
- ✅ Users get notified when laundry is ready
- ✅ System is production-ready!
