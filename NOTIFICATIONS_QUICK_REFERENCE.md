# 📱 Push Notifications - Quick Reference

## ⚡ Quick Test (1 Minute)

```bash
# 1. Run app
flutter run

# 2. Log in to the app
# 3. Open Firebase Console → Firestore → bookings collection
# 4. Change any booking status to "Ready"
# 5. See notification on device ✅
```

## 🔧 Full Setup Checklist

### ✅ Already Done (Automatic)
- [x] Dependencies installed
- [x] NotificationService created
- [x] BookingStatusListener created
- [x] Android manifest configured
- [x] Local notifications working (app open)

### 📋 Manual Firebase Steps Required

#### Step 1: Configure Firestore Rules (2 minutes)
```
Firebase Console → Firestore → Rules → Add FCM token rule → Publish
```
See: [FIREBASE_NOTIFICATION_MANUAL_SETUP.md - Part 2](FIREBASE_NOTIFICATION_MANUAL_SETUP.md#-part-2-configure-firestore-security-rules)

#### Step 2: Set Up Cloud Functions (10 minutes)
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Initialize functions
firebase init functions

# Deploy
firebase deploy --only functions
```
See: [FIREBASE_NOTIFICATION_MANUAL_SETUP.md - Part 3](FIREBASE_NOTIFICATION_MANUAL_SETUP.md#-part-3-set-up-cloud-functions-for-background-notifications)

#### Step 3: Test Background Notifications (1 minute)
```
1. Close app completely
2. Firebase Console → Change booking status to "Ready"
3. Receive notification on closed app ✅
```

## 📄 Documentation

- **Complete Setup Guide**: [FIREBASE_NOTIFICATION_MANUAL_SETUP.md](FIREBASE_NOTIFICATION_MANUAL_SETUP.md)
- **Implementation Details**: [NOTIFICATION_IMPLEMENTATION_SUMMARY.md](NOTIFICATION_IMPLEMENTATION_SUMMARY.md)
- **Technical Reference**: [PUSH_NOTIFICATION_SETUP.md](PUSH_NOTIFICATION_SETUP.md)

## 🎯 What Works Now vs What Needs Setup

| Feature | Status | Setup Required |
|---------|--------|---------------|
| Local notifications (app open) | ✅ Working | None - automatic |
| FCM token management | ✅ Working | None - automatic |
| Notification permissions | ✅ Working | None - automatic |
| Background notifications (app closed) | ⚠️ Needs Setup | Firebase Cloud Functions |
| Push notifications from admin | ⚠️ Needs Setup | Firebase Cloud Functions |

## 🚀 Minimal Setup (Skip Cloud Functions)

If you only need notifications when the app is **OPEN**:
- ✅ **No additional setup required!**
- ✅ It already works!
- ✅ Users get notified as long as app is running

If you need notifications when app is **CLOSED**:
- 📋 Follow Cloud Functions setup in FIREBASE_NOTIFICATION_MANUAL_SETUP.md
- ⏱️ Takes ~15 minutes
- 💳 Requires Firebase Blaze plan (has free tier)

## 🔍 Verification

### Check Local Notifications Work:
```bash
flutter run
# Login → Firebase Console → Change booking status → See notification
```

### Check FCM Token Saved:
```
Firebase Console → Firestore → users → {userId} → Check for "fcmToken" field
```

### Check Cloud Function Deployed:
```
Firebase Console → Functions → See "onBookingStatusChange" listed
```

## 🆘 Common Issues

| Issue | Solution |
|-------|----------|
| No notification when app open | Check permissions granted |
| No fcmToken in Firestore | Update Firestore security rules |
| No notification when app closed | Deploy Cloud Functions |
| Cloud Function deployment fails | Enable Blaze plan in Firebase |

## 📞 Need Help?

See detailed troubleshooting in:
[FIREBASE_NOTIFICATION_MANUAL_SETUP.md - Troubleshooting](FIREBASE_NOTIFICATION_MANUAL_SETUP.md#-troubleshooting)
