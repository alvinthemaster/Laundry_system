import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:laundry_system/core/constants/app_constants.dart';
import 'package:laundry_system/features/booking/data/models/booking_model.dart';

abstract class BookingDataSource {
  Future<BookingModel> createBooking({
    required String userId,
    required List<Map<String, dynamic>> categories,
    required List<Map<String, dynamic>> selectedAddOns,
    required String bookingType,
    String? deliveryAddress,
    DateTime? pickupDate,
    String? timeSlot,
    required String paymentMethod,
    String? specialInstructions,
    String? machineId,
    String? machineName,
    String? slotId,
    double? totalAmount,
    double? slotFee,
    double? deliveryFee,
    String? customerName,
  });

  Future<List<String>> getBookedSlots({
    required DateTime date,
    required String time,
  });

  Future<List<BookingModel>> getUserBookings(String userId);
  Future<BookingModel> getBookingById(String bookingId);
  Future<void> cancelBooking(String bookingId);
  Future<void> reschedulePickup({
    required String bookingId,
    required DateTime newPickupDate,
    required String newTimeSlot,
    String? newSlot,
  });
  Future<void> createPaymentRecord({
    required String bookingId,
    required String userId,
    required double amount,
    required String method,
  });
}

class BookingDataSourceImpl implements BookingDataSource {
  final FirebaseFirestore _firestore;
  final Uuid _uuid;
  
  BookingDataSourceImpl({
    FirebaseFirestore? firestore,
    Uuid? uuid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _uuid = uuid ?? const Uuid();
  
  @override
  Future<BookingModel> createBooking({
    required String userId,
    required List<Map<String, dynamic>> categories,
    required List<Map<String, dynamic>> selectedAddOns,
    required String bookingType,
    String? deliveryAddress,
    DateTime? pickupDate,
    String? timeSlot,
    required String paymentMethod,
    String? specialInstructions,
    String? machineId,
    String? machineName,
    String? slotId,
    double? totalAmount,
    double? slotFee,
    double? deliveryFee,
    String? customerName,
  }) async {
    try {
      final resolvedTotal = totalAmount ?? AppConstants.bookingFee;

      final paymentStatus = paymentMethod == AppConstants.paymentGCash
          ? AppConstants.paymentPaid
          : AppConstants.paymentUnpaid;

      final bookingId = _uuid.v4();
      final addOnsTotal = selectedAddOns.fold<double>(
        0.0,
        (sum, e) => sum + ((e['price'] as num?)?.toDouble() ?? 0.0),
      );

      final bookingModel = BookingModel(
        bookingId: bookingId,
        userId: userId,
        categories: categories,
        categoryTotal: 0.0,
        selectedAddOns: selectedAddOns,
        addOnsTotal: addOnsTotal,
        bookingFee: AppConstants.bookingFee,
        totalAmount: resolvedTotal,
        bookingType: bookingType,
        deliveryAddress: deliveryAddress,
        pickupDate: pickupDate,
        timeSlot: timeSlot,
        status: AppConstants.statusConfirmed,
        paymentStatus: paymentStatus,
        paymentMethod: paymentMethod,
        specialInstructions: specialInstructions,
        createdAt: DateTime.now(),
        machineId: machineId,
        machineName: machineName,
        slotId: slotId,
        slotFee: slotFee ?? 0.0,
        deliveryFee: deliveryFee ?? 0.0,
        customerName: customerName,
      );

      final bookingRef = _firestore
          .collection(AppConstants.bookingsCollection)
          .doc(bookingId);

      if (slotId != null && slotId.isNotEmpty) {
        // Atomic transaction: verify slot is still available, then lock it
        // and write the booking in a single operation to prevent double booking.
        await _firestore.runTransaction<void>((tx) async {
          final slotRef =
              _firestore.collection('machine_slots').doc(slotId);
          final slotSnap = await tx.get(slotRef);

          if (!slotSnap.exists ||
              !(slotSnap.data()?['isAvailable'] as bool? ?? false)) {
            throw Exception(
                'SLOT_UNAVAILABLE: This time slot has just been taken. Please select another.');
          }

          // Lock the slot atomically with the booking write.
          tx.update(slotRef, {
            'isAvailable': false,
            'status': 'booked',
            'bookingId': bookingId,
            'bookedAt': DateTime.now().toIso8601String(),
          });
          tx.set(bookingRef, bookingModel.toJson());
        });
      } else {
        // No slot involved — plain write.
        await bookingRef.set(bookingModel.toJson());
      }

      return bookingModel;
    } catch (e) {
      // Re-throw SLOT_UNAVAILABLE so callers can show a specific message.
      if (e.toString().contains('SLOT_UNAVAILABLE')) rethrow;
      throw Exception('Failed to create booking: $e');
    }
  }

  @override
  Future<List<String>> getBookedSlots({
    required DateTime date,
    required String time,
  }) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;
      // Query only by pickupTime to avoid composite-index requirement.
      // Status and date are filtered client-side.
      final snapshot = await _firestore
          .collection(AppConstants.bookingsCollection)
          .where('timeSlot', isEqualTo: time)
          .get();

      final booked = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final status = data['status'] as String?;
            if (status == AppConstants.statusCancelled) return false;
            final pd = data['pickupDate'] as String?;
            return pd != null && pd.startsWith(dateStr);
          })
          .map((doc) => doc.data()['slotId'] as String?)
          .whereType<String>()
          .toList();

      return booked;
    } catch (e) {
      throw Exception('Failed to fetch booked slots: $e');
    }
  }
  
  @override
  Future<void> createPaymentRecord({
    required String bookingId,
    required String userId,
    required double amount,
    required String method,
  }) async {
    try {
      final paymentId = _uuid.v4();
      await _firestore.collection('payments').doc(paymentId).set({
        'paymentId': paymentId,
        'bookingId': bookingId,
        'userId': userId,
        'amount': amount,
        'method': method,
        'status': 'Success',
        'paidAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to create payment record: $e');
    }
  }
  
  @override
  Future<List<BookingModel>> getUserBookings(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(AppConstants.bookingsCollection)
          .where('userId', isEqualTo: userId)
          .get();
      
      // Get bookings and sort client-side (no Firestore index needed)
      final bookings = querySnapshot.docs
          .map((doc) => BookingModel.fromJson(doc.data()))
          .toList();
      
      // Sort by createdAt descending (newest first)
      bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return bookings;
    } catch (e) {
      print('Error loading user bookings: $e');
      // Return empty list instead of throwing to prevent app crashes
      return [];
    }
  }
  
  @override
  Future<BookingModel> getBookingById(String bookingId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.bookingsCollection)
          .doc(bookingId)
          .get();
      
      if (!doc.exists) {
        throw Exception('Booking not found');
      }
      
      return BookingModel.fromJson(doc.data()!);
    } catch (e) {
      throw Exception('Failed to get booking: $e');
    }
  }
  
  @override
  Future<void> cancelBooking(String bookingId) async {
    try {
      // Read the booking first to get slotId (outside the transaction).
      final bookingSnap = await _firestore
          .collection(AppConstants.bookingsCollection)
          .doc(bookingId)
          .get();
      final slotId = bookingSnap.data()?['slotId'] as String?;

      await _firestore.runTransaction<void>((tx) async {
        final bookingRef = _firestore
            .collection(AppConstants.bookingsCollection)
            .doc(bookingId);

        tx.update(bookingRef, {'status': AppConstants.statusCancelled});

        // Release the time slot so it becomes bookable again.
        if (slotId != null && slotId.isNotEmpty) {
          final slotRef =
              _firestore.collection('machine_slots').doc(slotId);
          tx.update(slotRef, {
            'isAvailable': true,
            'status': 'available',
            'bookingId': FieldValue.delete(),
            'bookedAt': FieldValue.delete(),
          });
        }
      });
    } catch (e) {
      throw Exception('Failed to cancel booking: $e');
    }
  }
  
  @override
  Future<void> reschedulePickup({
    required String bookingId,
    required DateTime newPickupDate,
    required String newTimeSlot,
    String? newSlot,
  }) async {
    try {
      final updates = <String, dynamic>{
        'pickupDate': newPickupDate.toIso8601String(),
        'timeSlot': newTimeSlot,
        if (newSlot != null) 'slotId': newSlot,
      };
      await _firestore
          .collection(AppConstants.bookingsCollection)
          .doc(bookingId)
          .update(updates);
    } catch (e) {
      throw Exception('Failed to reschedule pickup: $e');
    }
  }
}
