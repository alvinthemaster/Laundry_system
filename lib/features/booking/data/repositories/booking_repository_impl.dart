import 'package:laundry_system/core/errors/failures.dart';
import 'package:laundry_system/features/auth/domain/repositories/auth_repository.dart';
import 'package:laundry_system/features/booking/data/datasources/booking_data_source.dart';
import 'package:laundry_system/features/booking/domain/entities/booking_entity.dart';
import 'package:laundry_system/features/booking/domain/repositories/booking_repository.dart';

class BookingRepositoryImpl implements BookingRepository {
  final BookingDataSource dataSource;
  
  const BookingRepositoryImpl(this.dataSource);
  
  @override
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
  }) async {
    try {
      final booking = await dataSource.createBooking(
        userId: userId,
        categories: categories,
        selectedAddOns: selectedAddOns,
        bookingType: bookingType,
        deliveryAddress: deliveryAddress,
        pickupDate: pickupDate,
        timeSlot: timeSlot,
        paymentMethod: paymentMethod,
        specialInstructions: specialInstructions,
        machineId: machineId,
        machineName: machineName,
        slotId: slotId,
        totalAmount: totalAmount,
        slotFee: slotFee,
        deliveryFee: deliveryFee,
        customerName: customerName,
        serviceType: serviceType,
      );
      return Either.right(booking);
    } catch (e) {
      return Either.left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getBookedSlots({
    required DateTime date,
    required String time,
  }) async {
    try {
      final slots = await dataSource.getBookedSlots(date: date, time: time);
      return Either.right(slots);
    } catch (e) {
      return Either.left(ServerFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, List<BookingEntity>>> getUserBookings(String userId) async {
    try {
      final bookings = await dataSource.getUserBookings(userId);
      return Either.right(bookings);
    } catch (e) {
      return Either.left(ServerFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, BookingEntity>> getBookingById(String bookingId) async {
    try {
      final booking = await dataSource.getBookingById(bookingId);
      return Either.right(booking);
    } catch (e) {
      return Either.left(ServerFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, void>> cancelBooking(String bookingId) async {
    try {
      await dataSource.cancelBooking(bookingId);
      return Either.right(null);
    } catch (e) {
      return Either.left(ServerFailure(e.toString()));
    }
  }  
  @override
  Future<Either<Failure, void>> reschedulePickup({
    required String bookingId,
    required DateTime newPickupDate,
    required String newPickupTime,
    String? newSlot,
    String? oldSlotId,
  }) async {
    try {
      await dataSource.reschedulePickup(
        bookingId: bookingId,
        newPickupDate: newPickupDate,
        newPickupTime: newPickupTime,
        newSlot: newSlot,
        oldSlotId: oldSlotId,
      );
      return Either.right(null);
    } catch (e) {
      return Either.left(ServerFailure(e.toString()));
    }
  }
}
