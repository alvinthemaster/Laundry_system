import 'package:laundry_system/core/errors/failures.dart';
import 'package:laundry_system/features/auth/domain/repositories/auth_repository.dart';
import 'package:laundry_system/features/booking/domain/entities/booking_entity.dart';

abstract class BookingRepository {
  // Create new booking
  Future<Either<Failure, BookingEntity>> createBooking({
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
  
  // Get user bookings
  Future<Either<Failure, List<BookingEntity>>> getUserBookings(String userId);
  
  // Get booking by ID
  Future<Either<Failure, BookingEntity>> getBookingById(String bookingId);
  
  // Cancel booking
  Future<Either<Failure, void>> cancelBooking(String bookingId);
  
  // Reschedule pickup
  Future<Either<Failure, void>> reschedulePickup({
    required String bookingId,
    required DateTime newPickupDate,
    required String newPickupTime,
  });
}
