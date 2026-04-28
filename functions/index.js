const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Cloud Function: Send push notification when booking status changes to "Ready"
 * Automatically triggers when any booking document is updated in Firestore
 */
exports.onBookingStatusChange = functions.firestore
  .document('bookings/{bookingId}')
  .onUpdate(async (change, context) => {
    try {
      const beforeData = change.before.data();
      const afterData = change.after.data();
      const bookingId = context.params.bookingId;

      console.log(`📋 Booking ${bookingId} updated`);
      console.log(`📊 Status change: ${beforeData.status} → ${afterData.status}`);

      // Check if status changed TO "Ready" (not FROM "Ready")
      if (beforeData.status !== 'Ready' && afterData.status === 'Ready') {
        console.log('✅ Status changed to Ready! Sending notification...');

        const userId = afterData.userId;

        // Get user's FCM token from Firestore
        const userDoc = await admin.firestore()
          .collection('users')
          .doc(userId)
          .get();

        if (!userDoc.exists) {
          console.warn(`⚠️  User ${userId} not found in Firestore`);
          return null;
        }

        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;

        if (!fcmToken) {
          console.warn(`⚠️  User ${userId} has no FCM token (user needs to log in to app first)`);
          return null;
        }

        console.log(`📤 Sending notification to user ${userId}`);

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

        // Send the notification via Firebase Cloud Messaging
        const response = await admin.messaging().send(message);
        console.log('✅ Notification sent successfully:', response);

        return response;
      } else {
        console.log('ℹ️  Status change not to Ready, no notification sent');
        return null;
      }
    } catch (error) {
      console.error('❌ Error in onBookingStatusChange:', error);
      return null;
    }
  });
