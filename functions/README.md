# Cloud Functions for Laundry System

This folder contains Firebase Cloud Functions for handling background notifications.

## 📁 What's in this folder:

- **index.js** - Cloud Function that sends notifications when booking status changes to "Ready"
- **package.json** - Dependencies configuration
- **.eslintrc.js** - Code linting configuration
- **.gitignore** - Ignores node_modules

## 🚀 Deployment

The function code is already written! You just need to deploy it:

```bash
# Make sure you're in the project root
cd C:\Users\yourb\OneDrive\Documents\GitHub\Laundry_system

# Login to Firebase (one-time)
firebase login

# Deploy the function
firebase deploy --only functions
```

## 📋 What the Function Does

When a booking document in Firestore is updated:
1. Checks if status changed TO "Ready"
2. Gets the user's FCM token from Firestore
3. Sends a push notification: "🎉 Your Laundry is Ready!"
4. Works even when the app is completely closed

## 🔍 View Logs

```bash
# View recent logs
firebase functions:log

# View live logs
firebase functions:log --only onBookingStatusChange
```

## 📊 Monitor in Firebase Console

Firebase Console → Functions → onBookingStatusChange → Logs tab

## ⚠️ Requirements

- Firebase Blaze (Pay as you go) plan
- Node.js 18 or higher
- Firebase CLI installed

## 🎯 Function Trigger

**Trigger:** Firestore document update  
**Collection:** `bookings/{bookingId}`  
**Condition:** status changed from any value to "Ready"  
**Action:** Send FCM push notification to user

## 📝 Notes

- Free tier includes 2 million function invocations/month
- Typical usage will stay within free limits
- Function runs in us-central1 region by default
