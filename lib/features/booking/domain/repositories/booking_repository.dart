import 'package:laundry_system/core/errors/failures.dart';
import 'package:laundry_system/features/auth/domain/repositories/auth_repository.dart';
import 'package:laundry_system/features/booking/domain/entities/booking_entity.dart';

abstract class BookingRepository {
  // Create new booking
  Future<Either<Failure, BookingEntity>> createBooking({
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
    String? serviceType,
  });

  // Get booked slots for a given date + time
  Future<Either<Failure, List<String>>> getBookedSlots({
    required DateTime date,
    required String time,
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
    String? newSlot,
    String? oldSlotId,
  });
}
