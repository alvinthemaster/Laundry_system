import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:laundry_system/core/constants/app_constants.dart';
import 'package:laundry_system/features/booking/data/models/booking_model.dart';

abstract class BookingDataSource {
  Future<BookingModel> createBooking({
    required String userId,
    required List<Map<String, dynamic>> categories,
    required List<String> selectedServices,
    required List<Map<String, dynamic>> selectedAddOns,
    required String bookingType,
    String? deliveryAddress,
    DateTime? pickupDate,
    String? pickupTime,
    required String paymentMethod,
    String? specialInstructions,
    String? selectedSlot,
    double? totalAmount,
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
    required String newPickupTime,
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
    required List<String> selectedServices,
    required List<Map<String, dynamic>> selectedAddOns,
    required String bookingType,
    String? deliveryAddress,
    DateTime? pickupDate,
    String? pickupTime,
    required String paymentMethod,
    String? specialInstructions,
    String? selectedSlot,
    double? totalAmount,
    String? customerName,
  }) async {
    try {
      // Fixed slot-based pricing: always ₱50 per booking
      const fixedTotal = 50.0;
      final resolvedTotal = totalAmount ?? fixedTotal;

      // Determine payment status
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
        selectedServices: selectedServices,
        selectedAddOns: selectedAddOns,
        weight: 0.0,
        servicesTotal: 0.0,
        addOnsTotal: addOnsTotal,
        bookingFee: AppConstants.bookingFee,
        totalAmount: resolvedTotal,
        bookingType: bookingType,
        deliveryAddress: deliveryAddress,
        pickupDate: pickupDate,
        pickupTime: pickupTime,
        status: AppConstants.statusConfirmed,
        paymentStatus: paymentStatus,
        paymentMethod: paymentMethod,
        specialInstructions: specialInstructions,
        createdAt: DateTime.now(),
        selectedSlot: selectedSlot,
        customerName: customerName,
      );

      await _firestore
          .collection(AppConstants.bookingsCollection)
          .doc(bookingModel.bookingId)
          .set(bookingModel.toJson());

      return bookingModel;
    } catch (e) {
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
          .where('pickupTime', isEqualTo: time)
          .get();

      final booked = snapshot.docs
          .where((doc) {
            final data = doc.data();
            // Exclude cancelled bookings
            final status = data['status'] as String?;
            if (status == AppConstants.statusCancelled) return false;
            // Match the date
            final pd = data['pickupDate'] as String?;
            return pd != null && pd.startsWith(dateStr);
          })
          .map((doc) => doc.data()['selectedSlot'] as String?)
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
      await _firestore
          .collection(AppConstants.bookingsCollection)
          .doc(bookingId)
          .update({'status': AppConstants.statusCancelled});
    } catch (e) {
      throw Exception('Failed to cancel booking: $e');
    }
  }
  
  @override
  Future<void> reschedulePickup({
    required String bookingId,
    required DateTime newPickupDate,
    required String newPickupTime,
    String? newSlot,
  }) async {
    try {
      final updates = <String, dynamic>{
        'pickupDate': newPickupDate.toIso8601String(),
        'pickupTime': newPickupTime,
        if (newSlot != null) 'selectedSlot': newSlot,
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
