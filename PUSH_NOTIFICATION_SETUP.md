# Push Notification Setup Guide - Step by Step

This guide walks you through setting up push notifications for the Laundry System with all manual Firebase steps clearly explained.

## 📋 What You'll Achieve

- ✅ Local notifications when app is **OPEN** (Already working!)
- ✅ Push notifications when app is **CLOSED** (Requires Firebase setup below)
- ✅ Notifications when booking status changes to "Ready"

## 🎯 Overview

The system is configured to send push notifications when a booking status changes to "Ready". The implementation has two parts:
- **Client-side** (already implemented): Works when app is open
- **Server-side** (requires Firebase setup): Works when app is closed

## Client-Side Implementation

### Components

1. **NotificationService** (`lib/core/services/notification_service.dart`)
   - Handles Firebase Cloud Messaging (FCM) initialization
   - Requests notification permissions
   - Manages FCM tokens
   - Displays local notifications

2. **BookingStatusListener** (`lib/core/services/booking_status_listener.dart`)
   - Listens for real-time booking status changes
   - Triggers notifications when status becomes "Ready"
   - Works when the app is open

3. **Auth Integration**
   - FCM tokens are saved when users log in
   - Tokens are removed when users log out
   - Booking status listener starts/stops with authentication

### How It Works

When a user logs in:
1. FCM token is generated and saved to the user's profile in Firestore
2. BookingStatusListener starts monitoring the user's bookings
3. When a booking status changes to "Ready", a local notification is displayed

## Server-Side Implementation (Cloud Functions)

For notifications when the app is closed or in the background, you need to set up Firebase Cloud Functions.

### Setup Cloud Functions

1. **Install Firebase CLI**
   ```bash
   npm install -g firebase-tools
   ```

2. **Initialize Functions**
   ```bash
   firebase init functions
   ```

3. **Install Dependencies**
   ```bash
   cd functions
   npm install firebase-admin
   npm install firebase-functions
   ```

4. **Create Booking Status Trigger**

Create `functions/index.js`:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Trigger when a booking document is updated
exports.onBookingStatusChange = functions.firestore
  .document('bookings/{bookingId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    
    // Check if status changed to "Ready"
    if (beforeData.status !== 'Ready' && afterData.status === 'Ready') {
      const userId = afterData.userId;
      
      try {
        // Get user's FCM token
        const userDoc = await admin.firestore()
          .collection('users')
          .doc(userId)
          .get();
        
        if (!userDoc.exists) {
          console.log('User not found:', userId);
          return null;
        }
        
        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;
        
        if (!fcmToken) {
          console.log('No FCM token for user:', userId);
          return null;
        }
        
        // Prepare notification
        const message = {
          token: fcmToken,
          notification: {
            title: '🎉 Your Laundry is Ready!',
            body: 'Your laundry order is ready for pickup. Thank you for using our service!',
          },
          data: {
            bookingId: context.params.bookingId,
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
        
        // Send notification
        const response = await admin.messaging().send(message);
        console.log('Notification sent successfully:', response);
        
        return response;
      } catch (error) {
        console.error('Error sending notification:', error);
        return null;
      }
    }
    
    return null;
  });
```

5. **Deploy Cloud Functions**
   ```bash
   firebase deploy --only functions
   ```

### Alternative: Admin Panel Integration

If you have an admin panel for managing bookings, you can also trigger notifications directly from the admin side when updating booking status:

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> sendBookingReadyNotification(String userId, String bookingId) async {
  // Get FCM server key from Firebase Console
  const String serverKey = 'YOUR_FCM_SERVER_KEY';
  
  // Get user's FCM token from Firestore
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .get();
  
  final fcmToken = userDoc.data()?['fcmToken'];
  
  if (fcmToken == null) return;
  
  // Send notification via FCM API
  final response = await http.post(
    Uri.parse('https://fcm.googleapis.com/fcm/send'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'key=$serverKey',
    },
    body: json.encode({
      'to': fcmToken,
      'notification': {
        'title': '🎉 Your Laundry is Ready!',
        'body': 'Your laundry order is ready for pickup. Thank you for using our service!',
      },
      'data': {
        'bookingId': bookingId,
        'type': 'booking_ready',
      },
      'priority': 'high',
    }),
  );
  
  if (response.statusCode == 200) {
    print('Notification sent successfully');
  } else {
    print('Failed to send notification: ${response.body}');
  }
}
```

## Testing

### Test Local Notifications (App Open)

1. Run the app
2. Log in as a user
3. Create a booking or use existing booking
4. From Firebase Console, manually update the booking status to "Ready"
5. You should see a notification immediately

### Test Background Notifications (App Closed)

1. Deploy Cloud Functions (see above)
2. Close the app completely
3. Update a booking status to "Ready" from Firebase Console
4. You should receive a notification even with the app closed

## Firestore Security Rules

Make sure your Firestore rules allow writing FCM tokens:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      allow update: if request.auth != null && 
                       request.auth.uid == userId && 
                       request.resource.data.diff(resource.data).affectedKeys()
                         .hasOnly(['fcmToken', 'fcmTokenUpdatedAt']);
    }
  }
}
```

## Troubleshooting

### Notifications Not Received

1. **Check Permissions**: Ensure notification permissions are granted
2. **Check FCM Token**: Verify the token is saved in the user document
3. **Check Cloud Functions**: View logs in Firebase Console
4. **Check Device**: Some devices have aggressive battery optimization that blocks notifications

### Token Not Saving

1. Check Firestore security rules
2. Verify user is logged in
3. Check console logs for errors

## Future Enhancements

1. **Multiple Notification Types**: Send different notifications for different status changes
2. **Customizable Notifications**: Allow users to choose which notifications they want to receive
3. **Rich Notifications**: Include action buttons (View Booking, Dismiss, etc.)
4. **Notification History**: Store notification history in Firestore
5. **Multi-device Support**: Handle multiple devices per user

## Dependencies

- `firebase_messaging: ^14.7.10` - Firebase Cloud Messaging
- `flutter_local_notifications: ^17.0.0` - Local notifications display

All dependencies are already added to `pubspec.yaml`.
