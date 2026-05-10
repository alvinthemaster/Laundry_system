const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// ─── helpers ──────────────────────────────────────────────────────────────────

/**
 * Fetch a user's FCM token from Firestore.
 * Returns null if the user doesn't exist or has no token.
 * @param {string} userId - The Firestore user document ID.
 * @return {Promise<string|null>} The FCM token or null.
 */
async function getFcmToken(userId) {
  const userDoc = await admin.firestore().collection("users").doc(userId).get();
  if (!userDoc.exists) {
    console.warn(`⚠️  User ${userId} not found in Firestore`);
    return null;
  }
  const token = userDoc.data().fcmToken;
  if (!token) {
    console.warn(`⚠️  User ${userId} has no FCM token`);
    return null;
  }
  return token;
}

/**
 * Build a standard FCM message object.
 * @param {string} token - The FCM registration token.
 * @param {string} title - Notification title.
 * @param {string} body - Notification body.
 * @param {Object} data - Optional data payload.
 * @return {Object} FCM message object.
 */
function buildMessage(token, title, body, data = {}) {
  return {
    token,
    notification: {title, body},
    data: {...data, click_action: "FLUTTER_NOTIFICATION_CLICK"},
    android: {
      notification: {
        channelId: "booking_status_channel",
        priority: "high",
        sound: "default",
      },
    },
    apns: {
      payload: {aps: {sound: "default", badge: 1}},
    },
  };
}

// ─── 1. Notify customer when laundry is Ready ─────────────────────────────────

exports.onBookingStatusChange = functions.firestore
    .document("bookings/{bookingId}")
    .onUpdate(async (change, context) => {
      try {
        const beforeData = change.before.data();
        const afterData = change.after.data();
        const bookingId = context.params.bookingId;

        console.log(`📋 Booking ${bookingId} status: ${beforeData.status} → ${afterData.status}`);

        if (beforeData.status !== "Ready" && afterData.status === "Ready") {
          const token = await getFcmToken(afterData.userId);
          if (!token) return null;

          const response = await admin.messaging().send(
              buildMessage(token,
                  "🎉 Your Laundry is Ready!",
                  "Your laundry order is ready for pickup. Thank you for using our service!",
                  {bookingId, type: "booking_ready"}),
          );
          console.log("✅ Ready notification sent:", response);
        }
        return null;
      } catch (error) {
        console.error("❌ Error in onBookingStatusChange:", error);
        return null;
      }
    });

// ─── 2. Notify driver when a delivery task is assigned to them ─────────────────

exports.onDriverAssigned = functions.firestore
    .document("bookings/{bookingId}")
    .onUpdate(async (change, context) => {
      try {
        const beforeData = change.before.data();
        const afterData = change.after.data();
        const bookingId = context.params.bookingId;

        const prevDriverId = beforeData.driverId || "";
        const newDriverId = afterData.driverId || "";

        // Trigger whenever driverId is set or changed (covers first assignment & re-assignment)
        if (!newDriverId || prevDriverId === newDriverId) return null;

        console.log(`🚗 Driver ${newDriverId} assigned to booking ${bookingId}`);

        const token = await getFcmToken(newDriverId);
        if (!token) return null;

        const customerName = afterData.customerName || "a customer";
        const address = afterData.deliveryAddress || "the delivery address";

        const response = await admin.messaging().send(
            buildMessage(token,
                "📦 New Delivery Task Assigned!",
                `You have a new delivery for ${customerName}. Address: ${address}`,
                {bookingId, type: "driver_assigned"}),
        );
        console.log("✅ Driver assignment notification sent:", response);
        return null;
      } catch (error) {
        console.error("❌ Error in onDriverAssigned:", error);
        return null;
      }
    });

// ─── 3. Push notification to customer when rider writes an arrived-notification ─

exports.onNewCustomerNotification = functions.firestore
    .document("users/{userId}/notifications/{notifId}")
    .onCreate(async (snap, context) => {
      try {
        const data = snap.data();
        const userId = context.params.userId;

        console.log(`🔔 New notification for user ${userId}: type=${data.type}`);

        const token = await getFcmToken(userId);
        if (!token) return null;

        const title = data.title || "Laundry Update";
        const body = data.body || "";
        const bookingId = data.bookingId || "";

        const response = await admin.messaging().send(
            buildMessage(token, title, body, {bookingId, type: data.type || "general"}),
        );
        console.log("✅ Customer notification push sent:", response);
        return null;
      } catch (error) {
        console.error("❌ Error in onNewCustomerNotification:", error);
        return null;
      }
    });

// ─── 4. Auto-generate e-receipt when COD delivery is marked Delivered ──────────

exports.onDeliveredCOD = functions.firestore
    .document("bookings/{bookingId}")
    .onUpdate(async (change, context) => {
      try {
        const beforeData = change.before.data();
        const afterData = change.after.data();
        const bookingId = context.params.bookingId;

        const statusChangedToDelivered =
        beforeData.status !== "Delivered" && afterData.status === "Delivered";
        const isCOD = (afterData.paymentMethod || "") === "Cash/COD";

        if (!statusChangedToDelivered || !isCOD) return null;

        console.log(`💰 COD delivery completed for booking ${bookingId} — generating receipt`);

        const receiptRef = admin.firestore().collection("receipts").doc(bookingId);

        // Avoid duplicate receipt creation
        const existing = await receiptRef.get();
        if (existing.exists) {
          console.log(`ℹ️  Receipt already exists for booking ${bookingId}`);
          return null;
        }

        const receipt = {
          receiptId: bookingId,
          userId: afterData.userId,
          bookingId: bookingId,
          categories: afterData.categories || [],
          addOns: afterData.selectedAddOns || [],
          totalAmount: afterData.totalAmount || 0,
          slotFee: afterData.slotFee || 0,
          deliveryFee: afterData.deliveryFee || 0,
          bookingFee: afterData.bookingFee || 0,
          addOnsTotal: afterData.addOnsTotal || 0,
          paymentStatus: "Unpaid",
          paymentMethod: "Cash/COD",
          bookingType: afterData.bookingType || afterData.orderType || "delivery",
          machineId: afterData.machineId || null,
          machineName: afterData.machineName || null,
          timeSlot: afterData.timeSlot || null,
          bookingDate: afterData.pickupDate || null,
          deliveryAddress: afterData.deliveryAddress || null,
          customerName: afterData.customerName || null,
          driverName: afterData.driverName || null,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        await receiptRef.set(receipt);
        console.log(`✅ Receipt created for booking ${bookingId}`);

        // Also notify customer that their receipt is ready via the notifications sub-collection
        // (which triggers onNewCustomerNotification to send an FCM push)
        await admin.firestore()
            .collection("users")
            .doc(afterData.userId)
            .collection("notifications")
            .add({
              type: "receipt_ready",
              bookingId: bookingId,
              receiptId: bookingId,
              title: "🧾 Your E-Receipt is Ready!",
              body: "Your COD delivery is complete. View your receipt in the app.",
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              read: false,
            });

        return null;
      } catch (error) {
        console.error("❌ Error in onDeliveredCOD:", error);
        return null;
      }
    });
