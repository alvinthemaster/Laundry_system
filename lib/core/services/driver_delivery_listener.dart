import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:laundry_system/core/services/notification_service.dart';

/// Listens to the driver's assigned delivery bookings in real-time.
///
/// Notification strategy (Spark plan — no Cloud Functions):
///   • Uses a `driverNotified: true` flag on each booking document.
///   • On the FIRST snapshot (app opens / cold start): any active booking
///     that does NOT have `driverNotified: true` triggers a local notification
///     and the flag is written. This covers assignments made while the app
///     was killed or in the background.
///   • On SUBSEQUENT snapshots: newly-added documents (admin just assigned
///     while app is open) are notified immediately, then the flag is written.
///   • Also listens to the driver's Firestore `notifications` subcollection
///     for admin-written notification documents.
class DriverDeliveryListener {
  static final DriverDeliveryListener _instance =
      DriverDeliveryListener._internal();
  factory DriverDeliveryListener() => _instance;
  DriverDeliveryListener._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _subscription;
  StreamSubscription<QuerySnapshot>? _notifSubscription;
  final Set<String> _knownBookingIds = {};
  bool _initialized = false;

  static const _terminalStatuses = {'Completed', 'Cancelled'};

  void startListening(String driverId) {
    stopListening();
    _knownBookingIds.clear();
    _initialized = false;

    developer.log(
      'Starting driver delivery listener for driver: $driverId',
      name: 'DriverDeliveryListener',
    );

    // ── 1. Real-time query: bookings assigned to this driver ──────────────
    _subscription = _firestore
        .collection('bookings')
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .listen(
      (snapshot) {
        if (!_initialized) {
          // First snapshot: seed known IDs and notify for any un-notified
          // active bookings (covers killed/background app scenarios).
          for (final doc in snapshot.docs) {
            _knownBookingIds.add(doc.id);
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) continue;
            final status = data['status'] as String? ?? '';
            final alreadyNotified = data['driverNotified'] == true;
            if (!alreadyNotified && !_terminalStatuses.contains(status)) {
              _notifyAndMark(doc);
            }
          }
          _initialized = true;
          return;
        }

        // Subsequent snapshots: a document entering the result set for the
        // first time (admin just set driverId on this booking).
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added &&
              !_knownBookingIds.contains(change.doc.id)) {
            _knownBookingIds.add(change.doc.id);
            _notifyAndMark(change.doc);
          }
        }
      },
      onError: (error) {
        developer.log(
          'Error listening to driver deliveries: $error',
          name: 'DriverDeliveryListener',
          error: error,
        );
      },
    );

    // ── 2. Notifications subcollection: catch admin-written notification docs ─
    _notifSubscription = _firestore
        .collection('users')
        .doc(driverId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen(
      (snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            _handleIncomingNotification(change.doc);
          }
        }
      },
      onError: (error) {
        developer.log(
          'Error listening to driver notifications: $error',
          name: 'DriverDeliveryListener',
          error: error,
        );
      },
    );
  }

  /// Show a notification for [doc] and mark it as notified in Firestore.
  void _notifyAndMark(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;

    final customerName = data['customerName'] as String? ?? 'a customer';
    final address = data['deliveryAddress'] as String? ?? '';

    developer.log(
      'New/unnotified delivery task: ${doc.id}',
      name: 'DriverDeliveryListener',
    );

    NotificationService().showDriverNotification(
      title: '📦 New Delivery Task Assigned!',
      body: address.isNotEmpty
          ? 'Delivery for $customerName — $address'
          : 'You have a new delivery for $customerName',
      payload: 'delivery:${doc.id}',
    );

    // Persist the flag so we don't re-notify after app restarts.
    doc.reference.update({'driverNotified': true}).catchError((e) {
      developer.log(
        'Failed to mark driverNotified: $e',
        name: 'DriverDeliveryListener',
      );
    });
  }

  void _handleIncomingNotification(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;

    final title = data['title'] as String? ?? '🚚 New Assignment';
    final body = data['body'] as String? ?? 'You have a new delivery task.';
    final bookingId = data['bookingId'] as String?;

    developer.log(
      'Driver notification received: $title',
      name: 'DriverDeliveryListener',
    );

    NotificationService().showDriverNotification(
      title: title,
      body: body,
      payload: bookingId != null ? 'delivery:$bookingId' : null,
    );

    // Mark as read so we don't show it again.
    doc.reference.update({'read': true});
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _notifSubscription?.cancel();
    _notifSubscription = null;
    _initialized = false;
  }
}


