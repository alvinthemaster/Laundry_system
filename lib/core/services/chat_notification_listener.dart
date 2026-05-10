import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:laundry_system/core/services/notification_service.dart';

/// Listens for new messages in all of the current user's chat rooms.
///
/// Works in the foreground and background (minimised). On Spark plan there is
/// no server-side FCM push, so killed-app notifications are not possible, but
/// this listener persists as long as the Flutter isolate is alive.
///
/// Strategy:
///   • On first snapshot: seed the latest `lastMessageAt` per chat without
///     showing any notification (avoids firing stale notifications on login).
///   • On subsequent changes: if `lastSenderId` != current user AND
///     `lastMessageAt` changed → show a local notification.
class ChatNotificationListener {
  static final ChatNotificationListener _instance =
      ChatNotificationListener._internal();
  factory ChatNotificationListener() => _instance;
  ChatNotificationListener._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _subscription;

  /// Maps bookingId → last known lastMessageAt string (used to detect new messages)
  final Map<String, String> _lastSeenMessageAt = {};
  bool _seeded = false;

  /// Call this once after login.
  /// [role] must be either `'driver'` or `'customer'`.
  void startListening({required String userId, required String role}) {
    stopListening();
    _lastSeenMessageAt.clear();
    _seeded = false;

    developer.log(
      'Starting chat notification listener — userId=$userId role=$role',
      name: 'ChatNotificationListener',
    );

    final participantField = role == 'driver' ? 'driverId' : 'customerId';

    _subscription = _firestore
        .collection('chats')
        .where(participantField, isEqualTo: userId)
        .snapshots()
        .listen(
      (snapshot) {
        if (!_seeded) {
          // Seed phase: record current lastMessageAt for all rooms.
          // No notifications — everything here is already "seen".
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final lastAt = data['lastMessageAt'];
            _lastSeenMessageAt[doc.id] = lastAt?.toString() ?? '';
          }
          _seeded = true;
          return;
        }

        // Notification phase: only fire when a chat room's lastMessageAt
        // has advanced AND the last message was sent by the OTHER party.
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added ||
              change.type == DocumentChangeType.modified) {
            final data = change.doc.data() as Map<String, dynamic>?;
            if (data == null) continue;

            final lastSenderId = data['lastSenderId'] as String?;
            final lastMessage = data['lastMessage'] as String?;
            final lastAt = data['lastMessageAt'];
            final lastAtStr = lastAt?.toString() ?? '';

            // Ignore if this message was sent by the current user.
            if (lastSenderId == null || lastSenderId == userId) continue;
            // Ignore if lastMessageAt hasn't changed (not a new message).
            if (lastAtStr == _lastSeenMessageAt[change.doc.id]) continue;
            // Ignore empty messages.
            if (lastMessage == null || lastMessage.isEmpty) continue;

            _lastSeenMessageAt[change.doc.id] = lastAtStr;

            final senderName = (lastSenderId == data['customerId'])
                ? (data['customerName'] as String? ?? 'Customer')
                : (data['driverName'] as String? ?? 'Driver');

            developer.log(
              'New chat message from $senderName in chat ${change.doc.id}',
              name: 'ChatNotificationListener',
            );

            NotificationService().showLocalNotification(
              title: '💬 $senderName',
              body: lastMessage,
              payload: 'chat:${change.doc.id}',
            );
          }
        }
      },
      onError: (error) {
        developer.log(
          'Error in chat notification listener: $error',
          name: 'ChatNotificationListener',
          error: error,
        );
      },
    );
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _seeded = false;
    developer.log(
      'Chat notification listener stopped',
      name: 'ChatNotificationListener',
    );
  }
}
