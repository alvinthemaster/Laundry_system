import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:laundry_system/core/services/notification_service.dart';

/// Service to listen for booking status changes and send local notifications
class BookingStatusListener {
  static final BookingStatusListener _instance = BookingStatusListener._internal();
  factory BookingStatusListener() => _instance;
  BookingStatusListener._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _subscription;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  final Map<String, String> _lastKnownStatuses = {};

  /// Start listening for booking status changes and incoming notifications
  void startListening(String userId) {
    stopListening();

    developer.log(
      'Starting booking status listener for user: $userId',
      name: 'BookingStatusListener',
    );

    // ── listen to booking status changes ──────────────────────────────────
    _subscription = _firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen(
      (snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.modified ||
              change.type == DocumentChangeType.added) {
            _handleBookingChange(change.doc);
          }
        }
      },
      onError: (error) {
        developer.log(
          'Error listening to booking changes: $error',
          name: 'BookingStatusListener',
          error: error,
        );
      },
    );

    // ── listen to server-written notifications (rider arrived, receipt ready) ─
    _notificationSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen(
      (snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            _handleIncomingNotification(change.doc);
          }
        }
      },
      onError: (error) {
        developer.log(
          'Error listening to notifications: $error',
          name: 'BookingStatusListener',
          error: error,
        );
      },
    );
  }

  /// Handle booking document changes
  void _handleBookingChange(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;

      final bookingId = doc.id;
      final currentStatus = data['status'] as String?;

      if (currentStatus == null) return;

      // Check if status changed to "Ready"
      final previousStatus = _lastKnownStatuses[bookingId];
      
      if (previousStatus != null && 
          previousStatus != 'Ready' && 
          currentStatus == 'Ready') {
        _sendReadyNotification(bookingId, data);
      }

      _lastKnownStatuses[bookingId] = currentStatus;
    } catch (e) {
      developer.log(
        'Error handling booking change: $e',
        name: 'BookingStatusListener',
        error: e,
      );
    }
  }

  /// Show a local notification for new notification documents written by the server
  void _handleIncomingNotification(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;

      final type = data['type'] as String? ?? '';
      final title = data['title'] as String? ?? 'Laundry Update';
      final body = data['body'] as String? ?? '';
      final bookingId = data['bookingId'] as String? ?? '';

      developer.log(
        'Incoming notification type=$type bookingId=$bookingId',
        name: 'BookingStatusListener',
      );

      NotificationService().showLocalNotification(
        title: title,
        body: body,
        payload: 'booking:$bookingId',
      );

      // Mark as read so it doesn't fire again on next app open.
      doc.reference.update({'read': true}).catchError((e) {
        developer.log(
          'Failed to mark notification as read: $e',
          name: 'BookingStatusListener',
        );
      });
    } catch (e) {
      developer.log(
        'Error handling incoming notification: $e',
        name: 'BookingStatusListener',
        error: e,
      );
    }
  }

  /// Send notification when booking is ready
  void _sendReadyNotification(String bookingId, Map<String, dynamic> data) {
    developer.log(
      'Booking $bookingId is ready - sending notification',
      name: 'BookingStatusListener',
    );

    NotificationService().showLocalNotification(
      title: '🎉 Your Laundry is Ready!',
      body: 'Your laundry order is ready for pickup. Thank you for using our service!',
      payload: 'booking:$bookingId',
    );
  }

  /// Stop listening for booking changes
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _lastKnownStatuses.clear();
    
    developer.log(
      'Stopped booking status listener',
      name: 'BookingStatusListener',
    );
  }
}
