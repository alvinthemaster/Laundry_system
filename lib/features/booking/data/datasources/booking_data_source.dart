import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:laundry_system/core/constants/app_constants.dart';
import 'package:laundry_system/core/services/pricing_service.dart';
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
  });
  
  Future<List<BookingModel>> getUserBookings(String userId);
  Future<BookingModel> getBookingById(String bookingId);
  Future<void> cancelBooking(String bookingId);
  Future<void> reschedulePickup({
    required String bookingId,
    required DateTime newPickupDate,
    required String newPickupTime,
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
  }) async {
    try {
      // Calculate all pricing components using PricingService
      final categoryTotal = PricingService.calculateMultipleCategoriesTotal(categories);
      
      // Calculate total weight from all categories
      double totalWeight = 0.0;
      for (final category in categories) {
        totalWeight += (category['weight'] as num).toDouble();
      }
      
      // Add computed price to each category
      final categoriesWithPrice = categories.map((cat) {
        final name = cat['name'] as String;
        final weight = (cat['weight'] as num).toDouble();
        final computedPrice = PricingService.calculateCategoryPrice(
          category: name,
          weight: weight,
        );
        return {
          'name': name,
          'weight': weight,
          'computedPrice': computedPrice,
        };
      }).toList();
      
      final servicesTotal = PricingService.calculateServicesTotal(selectedServices);
      final addOnsTotal = PricingService.calculateAddOnsTotal(selectedAddOns);
      
      final totalAmount = PricingService.calculateGrandTotalMultiCategory(
        categories: categoriesWithPrice,
        selectedServices: selectedServices,
        selectedAddOns: selectedAddOns,
      );
      
      // Determine payment status based on payment method
      // GCash = Paid (instant), Cash/COD = Unpaid (pay on delivery/pickup)
      final paymentStatus = paymentMethod == AppConstants.paymentGCash
          ? AppConstants.paymentPaid
          : AppConstants.paymentUnpaid;
      
      // Create booking model
      final bookingId = _uuid.v4();
      final bookingModel = BookingModel(
        bookingId: bookingId,
        userId: userId,
        categories: categoriesWithPrice,
        categoryTotal: categoryTotal,
        selectedServices: selectedServices,
        selectedAddOns: selectedAddOns,
        weight: totalWeight,
        servicesTotal: servicesTotal,
        addOnsTotal: addOnsTotal,
        bookingFee: AppConstants.bookingFee,
        totalAmount: totalAmount,
        bookingType: bookingType,
        deliveryAddress: deliveryAddress,
        pickupDate: pickupDate,
        pickupTime: pickupTime,
        status: AppConstants.statusConfirmed, // Confirmed after payment
        paymentStatus: paymentStatus,
        paymentMethod: paymentMethod,
        specialInstructions: specialInstructions,
        createdAt: DateTime.now(),
        // Legacy compatibility
        category: categoriesWithPrice.isNotEmpty ? categoriesWithPrice.first['name'] as String? : null,
        serviceType: selectedServices.isNotEmpty ? selectedServices.first : null,
        servicePrice: servicesTotal,
        basePrice: categoryTotal,
      );
      
      // Save to Firestore
      await _firestore
          .collection(AppConstants.bookingsCollection)
          .doc(bookingModel.bookingId)
          .set(bookingModel.toJson());
      
      // Note: Payment info is already stored in booking document
      // No need for separate payment record to avoid permission issues
      
      return bookingModel;
    } catch (e) {
      throw Exception('Failed to create booking: $e');
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
  }) async {
    try {
      await _firestore
          .collection(AppConstants.bookingsCollection)
          .doc(bookingId)
          .update({
            'pickupDate': newPickupDate.toIso8601String(),
            'pickupTime': newPickupTime,
          });
    } catch (e) {
      throw Exception('Failed to reschedule pickup: $e');
    }
  }
}
