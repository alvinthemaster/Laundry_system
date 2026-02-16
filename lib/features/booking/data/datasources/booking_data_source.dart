import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:laundry_system/core/constants/app_constants.dart';
import 'package:laundry_system/features/booking/data/models/booking_model.dart';

abstract class BookingDataSource {
  Future<BookingModel> createBooking({
    required String userId,
    required String serviceType,
    required double weight,
    required DateTime pickupDate,
    required String pickupTime,
    String? specialInstructions,
  });
  
  Future<List<BookingModel>> getUserBookings(String userId);
  Future<BookingModel> getBookingById(String bookingId);
  Future<void> cancelBooking(String bookingId);
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
    required String serviceType,
    required double weight,
    required DateTime pickupDate,
    required String pickupTime,
    String? specialInstructions,
  }) async {
    try {
      // Get service price
      final servicePrice = AppConstants.serviceTypes[serviceType] ?? 0.0;
      
      // Calculate total amount
      final totalAmount = (weight * servicePrice) + AppConstants.bookingFee;
      
      // Create booking model
      final bookingModel = BookingModel(
        bookingId: _uuid.v4(),
        userId: userId,
        serviceType: serviceType,
        weight: weight,
        bookingFee: AppConstants.bookingFee,
        servicePrice: servicePrice,
        totalAmount: totalAmount,
        pickupDate: pickupDate,
        pickupTime: pickupTime,
        status: AppConstants.statusPending,
        paymentStatus: AppConstants.paymentUnpaid,
        specialInstructions: specialInstructions,
        createdAt: DateTime.now(),
      );
      
      // Save to Firestore
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
}
