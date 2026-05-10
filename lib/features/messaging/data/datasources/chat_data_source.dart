import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:laundry_system/features/messaging/domain/entities/chat_message_entity.dart';
import 'package:laundry_system/features/messaging/domain/entities/chat_room_entity.dart';

class ChatDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isClosedStatus(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'completed';
  }

  /// Creates the chat room document if it doesn't already exist.
  Future<void> ensureChatRoom({
    required String bookingId,
    required String customerId,
    required String driverId,
    required String customerName,
    required String driverName,
  }) async {
    final ref = _firestore.collection('chats').doc(bookingId);
    final doc = await ref.get();
    if (!doc.exists) {
      bool initialLocked = false;
      try {
        final bookingSnap =
            await _firestore.collection('bookings').doc(bookingId).get();
        final status = (bookingSnap.data()?['status'] as String?) ?? '';
        initialLocked = _isClosedStatus(status);
      } catch (_) {
        // If booking read fails, default remains unlocked for active flows.
      }

      await ref.set({
        'bookingId': bookingId,
        'customerId': customerId,
        'driverId': driverId,
        'customerName': customerName,
        'driverName': driverName,
        'locked': initialLocked,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'lastMessageAt': null,
        'lastSenderId': null,
        'lastSenderRole': null,
        'customerLastReadAt': null,
        'driverLastReadAt': null,
      });
    }
  }

  /// Sends a message and updates the chat room's lastMessage fields atomically.
  Future<void> sendMessage({
    required String bookingId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String text,
  }) async {
    // Hard block when booking is closed or chat is locked.
    final chatSnap = await _firestore.collection('chats').doc(bookingId).get();
    final chatLocked = (chatSnap.data()?['locked'] as bool?) ?? false;

    final bookingSnap =
        await _firestore.collection('bookings').doc(bookingId).get();
    final bookingStatus = (bookingSnap.data()?['status'] as String?) ?? '';
    final bookingClosed = _isClosedStatus(bookingStatus);

    if (chatLocked || bookingClosed) {
      throw Exception('CHAT_LOCKED');
    }

    final batch = _firestore.batch();

    final msgRef = _firestore
        .collection('chats')
        .doc(bookingId)
        .collection('messages')
        .doc();

    batch.set(msgRef, {
      'messageId': msgRef.id,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'text': text,
      'sentAt': FieldValue.serverTimestamp(),
    });

    final chatRef = _firestore.collection('chats').doc(bookingId);
    batch.update(chatRef, {
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': senderId,
      'lastSenderRole': senderRole,
    });

    await batch.commit();
  }

  /// Real-time stream of messages ordered oldest → newest.
  Stream<List<ChatMessageEntity>> watchMessages(String bookingId) {
    return _firestore
        .collection('chats')
        .doc(bookingId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              final sentAt = data['sentAt'] as Timestamp?;
              return ChatMessageEntity(
                messageId: doc.id,
                senderId: data['senderId'] as String? ?? '',
                senderName: data['senderName'] as String? ?? '',
                senderRole: data['senderRole'] as String? ?? 'customer',
                text: data['text'] as String? ?? '',
                sentAt: sentAt?.toDate() ?? DateTime.now(),
              );
            }).toList());
  }

  /// Real-time stream of the chat room metadata (includes locked status).
  Stream<ChatRoomEntity?> watchChatRoom(String bookingId) {
    return _firestore
        .collection('chats')
        .doc(bookingId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          final data = doc.data()!;
          final createdAt = data['createdAt'] as Timestamp?;
          final lastMessageAt = data['lastMessageAt'] as Timestamp?;
          final customerLastReadAt = data['customerLastReadAt'] as Timestamp?;
          final driverLastReadAt = data['driverLastReadAt'] as Timestamp?;
          return ChatRoomEntity(
            bookingId: doc.id,
            customerId: data['customerId'] as String? ?? '',
            driverId: data['driverId'] as String? ?? '',
            customerName: data['customerName'] as String? ?? '',
            driverName: data['driverName'] as String? ?? '',
            locked: data['locked'] as bool? ?? false,
            createdAt: createdAt?.toDate() ?? DateTime.now(),
            lastMessage: data['lastMessage'] as String?,
            lastMessageAt: lastMessageAt?.toDate(),
            lastSenderId: data['lastSenderId'] as String?,
            lastSenderRole: data['lastSenderRole'] as String?,
            customerLastReadAt: customerLastReadAt?.toDate(),
            driverLastReadAt: driverLastReadAt?.toDate(),
          );
        });
  }

  Future<void> markAsRead({
    required String bookingId,
    required String userRole,
  }) async {
    final field = userRole == 'driver' ? 'driverLastReadAt' : 'customerLastReadAt';
    await _firestore.collection('chats').doc(bookingId).set({
      field: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Locks the chat room. Called when booking is marked Completed or Cancelled.
  /// Silently ignores if the chat room doesn't exist.
  Future<void> lockChat(String bookingId) async {
    try {
      await _firestore
          .collection('chats')
          .doc(bookingId)
          .update({'locked': true});
    } catch (_) {
      // Chat room may not exist — that's fine
    }
  }
}
