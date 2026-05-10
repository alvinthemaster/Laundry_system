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
    String? customerPhone,
    String? serviceType,
  });

  // Get booked slots for a given date + time
  Future<Either<Failure, List<String>>> getBookedSlots({
    required DateTime date,
    required String time,
  });
  
  // Get user bookings
  Future<Either<Failure, List<BookingEntity>>> getUserBookings(String userId);

  // Get bookings assigned to a driver by driverId
  Future<Either<Failure, List<BookingEntity>>> getDriverBookings(String driverId);

  // Update delivery status (Pickup / Out for Delivery / Delivered)
  Future<Either<Failure, void>> updateDeliveryStatus({
    required String bookingId,
    required String status,
  });

  // Generate delivery receipt with proof photo (COD deliveries only)
  Future<Either<Failure, void>> generateDeliveryReceipt({
    required String bookingId,
    required List<int> imageBytes,
    required String imageFileName,
  });

  // Notify customer that rider has arrived
  Future<Either<Failure, void>> notifyCustomerArrived({
    required String bookingId,
    required String customerId,
  });

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
