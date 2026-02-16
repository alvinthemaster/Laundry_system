import 'package:laundry_system/core/errors/failures.dart';
import 'package:laundry_system/features/auth/domain/repositories/auth_repository.dart';
import 'package:laundry_system/features/booking/domain/entities/booking_entity.dart';

abstract class BookingRepository {
  // Create new booking
  Future<Either<Failure, BookingEntity>> createBooking({
    required String userId,
    required String serviceType,
    required double weight,
    required DateTime pickupDate,
    required String pickupTime,
    String? specialInstructions,
  });
  
  // Get user bookings
  Future<Either<Failure, List<BookingEntity>>> getUserBookings(String userId);
  
  // Get booking by ID
  Future<Either<Failure, BookingEntity>> getBookingById(String bookingId);
  
  // Cancel booking
  Future<Either<Failure, void>> cancelBooking(String bookingId);
  
  // Calculate total amount
  double calculateTotalAmount({
    required String serviceType,
    required double weight,
    required double bookingFee,
  });
}
