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
      final booking = await dataSource.createBooking(
        userId: userId,
        categories: categories,
        selectedServices: selectedServices,
        selectedAddOns: selectedAddOns,
        bookingType: bookingType,
        deliveryAddress: deliveryAddress,
        pickupDate: pickupDate,
        pickupTime: pickupTime,
        paymentMethod: paymentMethod,
        specialInstructions: specialInstructions,
      );
      return Either.right(booking);
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
  }) async {
    try {
      await dataSource.reschedulePickup(
        bookingId: bookingId,
        newPickupDate: newPickupDate,
        newPickupTime: newPickupTime,
      );
      return Either.right(null);
    } catch (e) {
      return Either.left(ServerFailure(e.toString()));
    }
  }
}
